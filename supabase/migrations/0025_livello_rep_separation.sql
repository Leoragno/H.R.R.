-- =====================================================================
-- HRR — Separazione LIVELLO/REP per fonte (punto 0 del brief "sistema di
-- ritorno quotidiano").
--
-- Oggi ogni evento di progressione scrive sia xp_delta che rep_delta nello
-- stesso xp_events, rendendoli ridondanti: guidare da soli alza anche la
-- REP, che dovrebbe invece misurare solo riconoscimento ricevuto da altri.
-- `xp` (da cui `level` è derivato, vedi apply_xp_event in 0002) resta il
-- nome interno della colonna/valuta LIVELLO — non rinominata per non
-- toccare trigger/RLS/classifiche che già la referenziano, ma da qui in
-- avanti il suo significato è vincolato: cresce solo da attività
-- individuale (km puliti, punteggio di guida, territorio conquistato,
-- spot pubblicati). REP cresce solo da riconoscimento altrui (spot
-- validati dalla community, fuochi ricevuti, territorio strappato a un
-- utente reale, voti dei passeggeri) — nessuno di questi due canali è
-- ancora costruito lato server eccetto rating_received (0004) e i furti
-- di territorio (punto 1 del brief, non ancora implementato): fino ad
-- allora REP cresce comunque, solo più lentamente, non da qui.
-- =====================================================================

drop function if exists public.complete_trip(
  uuid, numeric, int, numeric, numeric, text,
  numeric, int, int, numeric, int, numeric, int, int, int, numeric, numeric
);

create or replace function public.complete_trip(
  p_trip_id uuid,
  p_distance_km numeric,
  p_duration_seconds int,
  p_avg_speed_kmh numeric,
  p_max_speed_kmh numeric,
  p_route_wkt text default null,
  p_jerk_rms_ms3 numeric default null,
  p_braking_soft_count int default 0,
  p_braking_hard_count int default 0,
  p_braking_jerk_avg_ms3 numeric default null,
  p_turns_count int default 0,
  p_turn_gyro_stddev_avg numeric default null,
  p_total_stops int default 0,
  p_stopped_seconds int default 0,
  p_accel_then_brake_count int default 0,
  p_gps_fix_hz numeric default null,
  p_gyro_hz numeric default null
) returns public.trips
language plpgsql security definer as $$
declare
  v_trip public.trips;
  v_xp int;
  v_rep int;
  v_suspicious boolean;

  -- -------------------------------------------------------------------
  -- Costanti del punteggio di guida (invariate da 0024_drive_score.sql).
  -- -------------------------------------------------------------------
  k_jerk_excellent constant numeric := 0.5;
  k_jerk_poor constant numeric := 2.5;
  k_braking_hard_weight constant numeric := 3.0;
  k_braking_penalty_per_km constant numeric := 12.0;
  k_braking_jerk_penalty_scale constant numeric := 10.0;
  k_curve_stddev_excellent constant numeric := 0.3;
  k_curve_stddev_poor constant numeric := 1.5;
  k_idle_ratio_excellent constant numeric := 0.10;
  k_idle_ratio_poor constant numeric := 0.40;
  k_accel_then_brake_penalty_per_km constant numeric := 15.0;
  k_stop_difficulty_factor constant numeric := 0.15;
  k_min_gps_hz constant numeric := 0.3;
  k_min_gyro_hz constant numeric := 20.0;
  k_min_distance_km constant numeric := 0.05;

  w_fluidita constant numeric := 0.35;
  w_anticipo constant numeric := 0.30;
  w_curve constant numeric := 0.20;
  w_efficienza constant numeric := 0.15;

  v_fluidita_active boolean;
  v_anticipo_active boolean;
  v_curve_active boolean;
  v_w_fluidita numeric;
  v_w_anticipo numeric;
  v_w_curve numeric;
  v_w_sum numeric;

  v_stop_per_km numeric;
  v_difficulty numeric;
  v_idle_ratio numeric;

  v_fluidita_score numeric;
  v_anticipo_score numeric;
  v_curve_score numeric;
  v_efficienza_score numeric;
  v_driving_score smallint;

  -- -------------------------------------------------------------------
  -- Costanti antifarming LIVELLO (brief, sezione "Separare livello e
  -- REP") — valori dati esplicitamente dal brief, non punti di partenza
  -- da tarare come quelle del punteggio di guida sopra.
  -- -------------------------------------------------------------------
  k_min_livello_km constant numeric := 2.0; -- viaggi più corti non assegnano livello
  -- Nessuna soglia esplicita nel brief per "velocità incompatibile con
  -- l'auto": scelta conservativa per non penalizzare code/traffico reali
  -- (media anche di pochi km/h in un ingorgo), cattura solo trip
  -- chiaramente a piedi/fermi.
  k_min_car_speed_kmh constant numeric := 5.0;
  k_daily_valid_km_cap constant numeric := 60.0;
  -- Griglia di confronto percorso (~200m): stesso ordine di grandezza
  -- dell'accuratezza GPS accettata dal client (_kMinGpsAccuracyM, 25m) più
  -- margine, per non trattare come "stesso percorso" due tragitti solo
  -- vagamente vicini.
  k_route_grid_deg constant numeric := 0.002;

  v_route_geom geometry;
  v_start_key text;
  v_end_key text;
  v_same_route_count int := 0;
  v_route_multiplier numeric := 1.0;
  v_today_valid_km numeric := 0;
  v_daily_fraction numeric := 1.0;
begin
  select * into v_trip from public.trips where id = p_trip_id for update;

  if v_trip is null then
    raise exception 'Trip % non trovato', p_trip_id;
  end if;
  if v_trip.driver_id <> auth.uid() then
    raise exception 'Non autorizzato a completare questo viaggio';
  end if;
  if v_trip.status <> 'active' then
    raise exception 'Viaggio già finalizzato';
  end if;

  -- Anti-cheat: una velocità media sostenuta oltre questa soglia non è
  -- guida su strada reale (spoofing GPS o altro mezzo) -> nessun premio,
  -- ma il viaggio resta salvato nello storico dell'utente.
  v_suspicious := p_avg_speed_kmh > 160 or p_distance_km > 1500;

  -- -------------------------------------------------------------------
  -- Punteggio di guida — invariato da 0024_drive_score.sql. Calcolato
  -- PRIMA del livello perché lo alimenta (vedi sotto): guidare meglio
  -- pesa di più sulla progressione, non solo guidare di più.
  -- -------------------------------------------------------------------
  if v_suspicious or p_distance_km < k_min_distance_km then
    v_driving_score := null;
  else
    v_fluidita_active := p_jerk_rms_ms3 is not null
      and (p_gps_fix_hz is null or p_gps_fix_hz >= k_min_gps_hz);
    v_anticipo_active := p_gps_fix_hz is null or p_gps_fix_hz >= k_min_gps_hz;
    v_curve_active := p_turns_count > 0 and p_turn_gyro_stddev_avg is not null
      and (p_gyro_hz is null or p_gyro_hz >= k_min_gyro_hz);

    v_w_fluidita := case when v_fluidita_active then w_fluidita else 0 end;
    v_w_anticipo := case when v_anticipo_active then w_anticipo else 0 end;
    v_w_curve := case when v_curve_active then w_curve else 0 end;
    v_w_sum := v_w_fluidita + v_w_anticipo + v_w_curve + w_efficienza;

    v_stop_per_km := p_total_stops / p_distance_km;
    v_difficulty := 1 + k_stop_difficulty_factor * v_stop_per_km;

    if v_fluidita_active then
      v_fluidita_score := 100 - 100 * least(1, greatest(0,
        (p_jerk_rms_ms3 - k_jerk_excellent) / (k_jerk_poor - k_jerk_excellent)));
      v_fluidita_score := greatest(0, 100 - (100 - v_fluidita_score) / v_difficulty);
    end if;

    if v_anticipo_active then
      v_anticipo_score := greatest(0, 100 - (
        least(100, ((p_braking_soft_count + p_braking_hard_count * k_braking_hard_weight)
          / p_distance_km) * k_braking_penalty_per_km)
        + coalesce(greatest(0, p_braking_jerk_avg_ms3 - k_jerk_excellent)
          * k_braking_jerk_penalty_scale, 0)
      ) / v_difficulty);
    end if;

    if v_curve_active then
      v_curve_score := 100 - 100 * least(1, greatest(0,
        (p_turn_gyro_stddev_avg - k_curve_stddev_excellent)
          / (k_curve_stddev_poor - k_curve_stddev_excellent)));
      v_curve_score := greatest(0, 100 - (100 - v_curve_score) / v_difficulty);
    end if;

    v_idle_ratio := case when p_duration_seconds > 0
      then least(1, greatest(0, p_stopped_seconds::numeric / p_duration_seconds))
      else 0 end;
    v_efficienza_score := 100 - 100 * least(1, greatest(0,
      (v_idle_ratio - k_idle_ratio_excellent)
        / (k_idle_ratio_poor - k_idle_ratio_excellent)));
    v_efficienza_score := greatest(0, v_efficienza_score - least(60,
      (p_accel_then_brake_count / p_distance_km) * k_accel_then_brake_penalty_per_km)
        / v_difficulty);

    if v_w_sum <= 0 then
      v_driving_score := round(v_efficienza_score)::smallint;
    else
      v_driving_score := round((
        coalesce(v_fluidita_score, 0) * v_w_fluidita +
        coalesce(v_anticipo_score, 0) * v_w_anticipo +
        coalesce(v_curve_score, 0) * v_w_curve +
        v_efficienza_score * w_efficienza
      ) / v_w_sum)::smallint;
    end if;
  end if;

  -- -------------------------------------------------------------------
  -- LIVELLO (xp) — unica fonte di crescita da questa RPC. I viaggi non
  -- assegnano mai REP (vedi commento di testa): la REP resta 0 qui,
  -- cresce altrove da eventi di riconoscimento altrui.
  -- -------------------------------------------------------------------
  v_rep := 0;

  if v_suspicious or p_distance_km <= 0
     or p_distance_km < k_min_livello_km
     or p_avg_speed_kmh < k_min_car_speed_kmh then
    v_xp := 0;
  else
    -- Km puliti + punteggio di guida: un punteggio perfetto raddoppia la
    -- resa base, uno pessimo la dimezza — mai un vantaggio di gioco (non
    -- sblocca territorio più facile), solo quanto livello frutta lo
    -- stesso chilometro. Punteggio assente (viaggio troppo corto per un
    -- valore onesto, sopra k_min_distance_km ma sotto un dato affidabile)
    -- -> resa base neutra.
    v_xp := round(p_distance_km * 12 *
      (0.5 + 0.5 * coalesce(v_driving_score, 50) / 100.0));

    -- Rendimento decrescente sullo stesso percorso nella stessa giornata:
    -- confronto su una griglia di ~200m di inizio/fine tragitto contro i
    -- viaggi già completati oggi da questo utente.
    if p_route_wkt is not null then
      v_route_geom := ST_GeomFromText(p_route_wkt, 4326);
      v_start_key := ST_AsText(ST_SnapToGrid(ST_StartPoint(v_route_geom), k_route_grid_deg));
      v_end_key := ST_AsText(ST_SnapToGrid(ST_EndPoint(v_route_geom), k_route_grid_deg));

      select count(*) into v_same_route_count
      from public.trips t
      where t.driver_id = v_trip.driver_id
        and t.status = 'completed'
        and t.started_at >= date_trunc('day', now())
        and t.route is not null
        and ST_AsText(ST_SnapToGrid(ST_StartPoint(t.route::geometry), k_route_grid_deg)) = v_start_key
        and ST_AsText(ST_SnapToGrid(ST_EndPoint(t.route::geometry), k_route_grid_deg)) = v_end_key;

      v_route_multiplier := case
        when v_same_route_count <= 0 then 1.0
        when v_same_route_count = 1 then 0.5
        else 0.25
      end;
      v_xp := round(v_xp * v_route_multiplier);
    end if;

    -- Tetto di 60 km validi al giorno: riduce proporzionalmente la quota
    -- di QUESTO viaggio che eccede il residuo giornaliero, invece di
    -- azzerarlo di colpo al superamento — un viaggio di 65km con 0 km già
    -- fatti oggi frutta comunque i primi 60.
    select coalesce(sum(t.distance_km), 0) into v_today_valid_km
    from public.trips t
    where t.driver_id = v_trip.driver_id
      and t.status = 'completed'
      and t.started_at >= date_trunc('day', now())
      and t.distance_km >= k_min_livello_km
      and t.avg_speed_kmh >= k_min_car_speed_kmh
      and t.avg_speed_kmh <= 160
      and t.distance_km <= 1500;

    if v_today_valid_km >= k_daily_valid_km_cap then
      v_daily_fraction := 0;
    elsif v_today_valid_km + p_distance_km > k_daily_valid_km_cap then
      v_daily_fraction := (k_daily_valid_km_cap - v_today_valid_km) / p_distance_km;
    else
      v_daily_fraction := 1.0;
    end if;
    v_xp := greatest(0, round(v_xp * v_daily_fraction));
  end if;

  update public.trips set
    ended_at = now(),
    distance_km = p_distance_km,
    duration_seconds = p_duration_seconds,
    avg_speed_kmh = p_avg_speed_kmh,
    max_speed_kmh = p_max_speed_kmh,
    xp_earned = v_xp,
    rep_earned = v_rep,
    driving_score = v_driving_score,
    status = 'completed',
    route = case when p_route_wkt is not null
      then ST_GeogFromText('SRID=4326;' || p_route_wkt)
      else route end
  where id = p_trip_id
  returning * into v_trip;

  if v_xp > 0 or v_rep > 0 then
    insert into public.xp_events (profile_id, source, source_id, xp_delta, rep_delta)
    values (v_trip.driver_id, 'trip', v_trip.id, v_xp, v_rep);
  end if;

  update public.profiles set
    total_km = total_km + p_distance_km,
    total_trips = total_trips + 1
  where id = v_trip.driver_id;

  return v_trip;
end;
$$;

grant execute on function public.complete_trip(
  uuid, numeric, int, numeric, numeric, text,
  numeric, int, int, numeric, int, numeric, int, int, int, numeric, numeric
) to authenticated;

-- ---------------------------------------------------------------------
-- Missioni/achievement che oggi assegnano REP per pura attività
-- individuale (km, viaggi, pubblicare uno spot prima che la community lo
-- veda) — violano "nessun modo di alzare la REP guidando da soli". La
-- REP rimossa è spostata su xp_reward/reward_xp: il valore percepito
-- della missione resta lo stesso, cambia solo a quale valuta appartiene.
-- `season_level_push` non riceve compenso: premiare xp per aver già
-- raggiunto un livello (a sua volta derivato da xp) è circolare.
-- `daily_rate_five`/`weekly_rate_*`: votare gli spot altrui è
-- un'iniziativa propria, non riconoscimento ricevuto — stesso trattamento.
-- ---------------------------------------------------------------------
update public.mission_templates set xp_reward = xp_reward + rep_reward, rep_reward = 0
  where code in (
    'daily_km_15', 'daily_smooth_drive', 'weekly_km_100', 'weekly_trips_5',
    'secret_night_owl', 'secret_mountain_explorer',
    'daily_publish_spot', 'weekly_spots_5', 'daily_rate_five'
  );
update public.mission_templates set rep_reward = 0
  where code = 'season_level_push';

update public.achievements set reward_xp = reward_xp + reward_rep, reward_rep = 0
  where code in ('first_trip', 'km_100', 'km_1000', 'km_10000', 'trips_100');

-- `missions` è una fotografia di mission_templates presa a generazione
-- (daily/weekly/seasonal, vedi generate_*_missions sopra): aggiornare solo
-- il template non corregge le istanze già generate per il periodo
-- corrente e non ancora riscattate (mission_claims è per-utente, separata
-- da questa riga condivisa — sicuro correggerla in place).
update public.missions m set xp_reward = xp_reward + rep_reward, rep_reward = 0
  from public.mission_templates t
  where m.template_id = t.id
    and t.code in (
      'daily_km_15', 'daily_smooth_drive', 'weekly_km_100', 'weekly_trips_5',
      'secret_night_owl', 'secret_mountain_explorer',
      'daily_publish_spot', 'weekly_spots_5', 'daily_rate_five'
    );
update public.missions m set rep_reward = 0
  from public.mission_templates t
  where m.template_id = t.id and t.code = 'season_level_push';

-- ---------------------------------------------------------------------
-- Sblocco sociale: creare una crew richiede REP, non solo un account
-- (brief, "REP → permessi sociali: creare una crew..."). Soglia non data
-- esplicitamente dal brief — 100 è un punto di partenza raggiungibile in
-- pochi giorni di riconoscimento reale (qualche spot validato/fuoco
-- ricevuto), non un valore tarato su dati d'uso: aggiustala quando avrai
-- una prima distribuzione reale di REP fra gli utenti. Gli altri sblocchi
-- REP elencati nel brief (peso doppio nelle validazioni, classifica
-- cittadina, badge sui pentagoni) non sono qui: il primo dipende dalla
-- pipeline di validazione (punto 2, non ancora costruita), il secondo è
-- una feature nuova senza dati di città in questo schema, il terzo tocca
-- la UI della mappa territorio (punto 1) — restano da fare quando quei
-- pezzi esistono.
-- ---------------------------------------------------------------------
drop policy if exists "crews_insert_auth" on public.crews;
create policy "crews_insert_rep_gate" on public.crews for insert with check (
  auth.uid() = owner_id
  and exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.rep >= 100
  )
);
