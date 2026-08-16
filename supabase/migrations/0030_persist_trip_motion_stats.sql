-- =====================================================================
-- HRR — Persiste sui viaggi le statistiche di guida oggi solo effimere
-- (TripMotionStats, calcolate live in trip_live_provider.dart e mostrate
-- una sola volta in TripSummaryScreen appena dopo aver finito la guida).
-- TripDetailScreen (schermata "Dettaglio viaggio", riaperta più tardi
-- dallo storico) mostrava solo distanza/durata/velocità media/massima:
-- non aveva altro da leggere, perché nient'altro veniva scritto sul
-- database. Qui aggiungiamo le colonne e le facciamo scrivere da
-- complete_trip, così "Dettaglio viaggio" può mostrare lo stesso set di
-- statistiche del report di fine corsa.
--
-- Corpo della funzione copiato 1:1 da 0025_livello_rep_separation.sql
-- (punteggio di guida, XP, moltiplicatore stesso percorso, tetto
-- giornaliero, xp_events, update profiles): NESSUNA di quelle logiche è
-- toccata qui, solo aggiunta dei nuovi parametri/colonne in coda.
--
-- Deliberatamente fuori scope: i grafici "Speed/Elevation Over Time"
-- restano solo nel report immediato — richiederebbero salvare l'intera
-- serie di campioni telemetrici per viaggio (oggi esplicitamente
-- "effimera", vedi TelemetrySample in trip_live_provider.dart), una
-- crescita di storage per-viaggio ben più grande di qualche colonna
-- scalare e una decisione a parte.
-- =====================================================================

alter table public.trips
  add column if not exists elevation_gain_m numeric,
  add column if not exists max_altitude_m numeric,
  add column if not exists max_acceleration_ms2 numeric,
  add column if not exists max_deceleration_ms2 numeric,
  add column if not exists zero_to_hundred_seconds numeric,
  add column if not exists peak_g_force numeric,
  add column if not exists turns_left int,
  add column if not exists turns_right int,
  add column if not exists lane_changes int,
  add column if not exists max_cornering_speed_kmh numeric,
  add column if not exists braking_events int,
  add column if not exists total_stops int,
  add column if not exists stopped_seconds int;

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
  p_gyro_hz numeric default null,
  -- Nuovi: solo per la persistenza in "Dettaglio viaggio", nessuno di
  -- questi entra nel calcolo del punteggio di guida/XP sotto (invariato).
  p_elevation_gain_m numeric default null,
  p_max_altitude_m numeric default null,
  p_max_acceleration_ms2 numeric default null,
  p_max_deceleration_ms2 numeric default null,
  p_zero_to_hundred_seconds numeric default null,
  p_peak_g_force numeric default null,
  p_turns_left int default 0,
  p_turns_right int default 0,
  p_lane_changes int default 0,
  p_max_cornering_speed_kmh numeric default null
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
      else route end,
    elevation_gain_m = p_elevation_gain_m,
    max_altitude_m = p_max_altitude_m,
    max_acceleration_ms2 = p_max_acceleration_ms2,
    max_deceleration_ms2 = p_max_deceleration_ms2,
    zero_to_hundred_seconds = p_zero_to_hundred_seconds,
    peak_g_force = p_peak_g_force,
    turns_left = p_turns_left,
    turns_right = p_turns_right,
    lane_changes = p_lane_changes,
    max_cornering_speed_kmh = p_max_cornering_speed_kmh,
    braking_events = p_braking_soft_count + p_braking_hard_count,
    total_stops = p_total_stops,
    stopped_seconds = p_stopped_seconds
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
  uuid, numeric, int, numeric, numeric, text, numeric, int, int, numeric, int,
  numeric, int, int, int, numeric, numeric, numeric, numeric, numeric, numeric,
  numeric, numeric, int, int, int, numeric
) to authenticated;
