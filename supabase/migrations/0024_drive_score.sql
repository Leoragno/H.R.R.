-- =====================================================================
-- HRR — Punteggio di guida (0-100), calcolato server-side a fine viaggio.
--
-- `trips.driving_score` esisteva già (0001_init.sql) ma non è mai stato
-- scritto da nessun punto del codice: era pensato per una scala 0-10
-- ("A+ style score" nel commento originale). Lo riusiamo invece di
-- crearne un secondo campo, ma la colonna viene allargata alla scala
-- 0-100 richiesta esplicitamente ora. `profiles.driving_score` (stesso
-- nome, scala 0-10, mostrato in profile_screen.dart) resta un campo
-- distinto e non viene toccato qui: è un aggregato per-profilo, questo è
-- un valore per-viaggio.
--
-- Niente stima dell'orientamento del telefono: senza sapere come è
-- montato/tenuto il telefono, i suoi assi grezzi sono inutilizzabili.
-- Fluidità e Anticipo usano perciò la stessa accelerazione già derivata
-- lato client dalla velocità GPS (longitudinale per definizione, nessuna
-- ambiguità di montaggio — stesso segnale già usato per maxAcceleration/
-- maxDeceleration/brakingEvents). Curve usa la variabilità della
-- magnitudine del giroscopio durante le finestre di svolta già rilevate
-- (isotropica, non richiede sapere quale asse è "laterale"). Il picco G
-- dell'accelerometro (isotropico, `peakGForce`) resta una statistica
-- informativa nel report ma esce dal punteggio: senza assi decomposti non
-- distingue una frenata da una buca meglio di quanto già faccia il filtro
-- di sostenimento minimo lato client.
--
-- Le soglie sotto sono punto di partenza (telematica assicurativa generica,
-- non dati reali di questa app) — costanti dichiarate in testa alla
-- funzione, mai sparse nel corpo, così la taratura successiva (vedi brief:
-- raccogliere distribuzioni reali prima di mostrare il punteggio agli
-- utenti) tocca un solo punto.
-- =====================================================================

drop function if exists public.complete_trip(uuid, numeric, int, numeric, numeric, text);

-- Scala allargata da numeric(3,1) (0-10) a smallint (0-100): la colonna
-- non ha mai avuto un valore scritto, quindi non serve convertire dati
-- esistenti.
alter table public.trips alter column driving_score type smallint using null;
alter table public.trips add constraint trips_driving_score_range
  check (driving_score is null or driving_score between 0 and 100);

create or replace function public.complete_trip(
  p_trip_id uuid,
  p_distance_km numeric,
  p_duration_seconds int,
  p_avg_speed_kmh numeric,
  p_max_speed_kmh numeric,
  p_route_wkt text default null,
  -- Aggregati di guida calcolati lato client in O(1) durante il viaggio
  -- (mai campioni grezzi: sarebbero migliaia di righe) — vedi
  -- TripMotionStats in trip_live_provider.dart. Il punteggio finale è
  -- sempre calcolato qui, mai fidandosi di un valore mandato dal client.
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
  -- Costanti di configurazione del punteggio di guida — punto di
  -- partenza da tarare (brief, sezione "Taratura prima del lancio").
  -- -------------------------------------------------------------------
  k_jerk_excellent constant numeric := 0.5;  -- m/s^3 — fluidità eccellente
  k_jerk_poor constant numeric := 2.5;       -- m/s^3 — fluidità pessima
  k_braking_hard_weight constant numeric := 3.0; -- frenata >5 m/s^2 pesa 3x
  k_braking_penalty_per_km constant numeric := 12.0; -- punti persi per evento/km pesato
  k_braking_jerk_penalty_scale constant numeric := 10.0; -- punti persi per m/s^3 di jerk medio in frenata oltre k_jerk_excellent
  k_curve_stddev_excellent constant numeric := 0.3; -- rad/s — sterzata costante
  k_curve_stddev_poor constant numeric := 1.5;       -- rad/s — sterzata oscillante
  k_idle_ratio_excellent constant numeric := 0.10;   -- quota tempo fermo accettabile
  k_idle_ratio_poor constant numeric := 0.40;
  k_accel_then_brake_penalty_per_km constant numeric := 15.0; -- punti persi per evento/km
  k_stop_difficulty_factor constant numeric := 0.15; -- divisore contesto, come da spec
  k_min_gps_hz constant numeric := 0.3;  -- sotto: fluidità e anticipo disattivate (dipendono dal GPS)
  k_min_gyro_hz constant numeric := 20.0; -- sotto: curve disattivata (dipende dal giroscopio)
  k_min_distance_km constant numeric := 0.05; -- sotto: nessun punteggio, divisione per km non affidabile (guardia numerica, non regola di annullamento del viaggio)

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

  if v_suspicious or p_distance_km <= 0 then
    v_xp := 0;
    v_rep := 0;
  else
    v_xp := greatest(5, round(p_distance_km * 12)::int);
    v_rep := round(p_distance_km * 3)::int;
  end if;

  -- -------------------------------------------------------------------
  -- Punteggio di guida — nessuna regola di annullamento viaggio: un
  -- viaggio troppo corto per un numero onesto semplicemente non riceve
  -- un punteggio (resta null), ma xp/rep/distanza/percorso si salvano
  -- comunque normalmente come sempre.
  -- -------------------------------------------------------------------
  if v_suspicious or p_distance_km < k_min_distance_km then
    v_driving_score := null;
  else
    v_fluidita_active := p_jerk_rms_ms3 is not null
      and (p_gps_fix_hz is null or p_gps_fix_hz >= k_min_gps_hz);
    -- Anticipo dipende dallo stesso segnale GPS di Fluidità (accelerazione
    -- derivata dalla velocità), quindi condivide il gate di qualità dato.
    v_anticipo_active := p_gps_fix_hz is null or p_gps_fix_hz >= k_min_gps_hz;
    v_curve_active := p_turns_count > 0 and p_turn_gyro_stddev_avg is not null
      and (p_gyro_hz is null or p_gyro_hz >= k_min_gyro_hz);

    v_w_fluidita := case when v_fluidita_active then w_fluidita else 0 end;
    v_w_anticipo := case when v_anticipo_active then w_anticipo else 0 end;
    v_w_curve := case when v_curve_active then w_curve else 0 end;
    -- Efficienza non dipende da accelerometro/giroscopio (tempo fermo +
    -- pattern accelerazione/frenata sono entrambi derivati da GPS/orologio),
    -- resta sempre attiva.
    v_w_sum := v_w_fluidita + v_w_anticipo + v_w_curve + w_efficienza;

    v_stop_per_km := p_total_stops / p_distance_km;
    v_difficulty := 1 + k_stop_difficulty_factor * v_stop_per_km;

    -- Fluidità: interpolazione lineare fra le soglie eccellente/pessima
    -- date dal brief, poi normalizzata per difficoltà di contesto.
    if v_fluidita_active then
      v_fluidita_score := 100 - 100 * least(1, greatest(0,
        (p_jerk_rms_ms3 - k_jerk_excellent) / (k_jerk_poor - k_jerk_excellent)));
      v_fluidita_score := greatest(0, 100 - (100 - v_fluidita_score) / v_difficulty);
    end if;

    -- Anticipo: eventi di frenata pesati (dura = 3x) per km, più una
    -- penalità sulla "durezza" media della frenata (jerk durante l'evento,
    -- non solo la sua magnitudine) — premia la frenata lunga e progressiva.
    if v_anticipo_active then
      v_anticipo_score := greatest(0, 100 - (
        least(100, ((p_braking_soft_count + p_braking_hard_count * k_braking_hard_weight)
          / p_distance_km) * k_braking_penalty_per_km)
        + coalesce(greatest(0, p_braking_jerk_avg_ms3 - k_jerk_excellent)
          * k_braking_jerk_penalty_scale, 0)
      ) / v_difficulty);
    end if;

    -- Curve: deviazione standard media della magnitudine giroscopica
    -- durante le finestre di svolta — sterzata costante = pulita,
    -- oscillante = sporca (stessa idea della spec, sensore diverso).
    if v_curve_active then
      v_curve_score := 100 - 100 * least(1, greatest(0,
        (p_turn_gyro_stddev_avg - k_curve_stddev_excellent)
          / (k_curve_stddev_poor - k_curve_stddev_excellent)));
      v_curve_score := greatest(0, 100 - (100 - v_curve_score) / v_difficulty);
    end if;

    -- Efficienza: quota di tempo fermo sul totale + pattern
    -- accelerazione-poi-frenata ravvicinate (energia sprecata) per km.
    -- Niente confronto con la velocità di crociera tipica della strada:
    -- richiederebbe una classificazione del tipo di strada che non
    -- abbiamo (vedi discussione col team prodotto).
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
      -- Non dovrebbe mai accadere: Efficienza è sempre attiva. Guardia
      -- puramente numerica.
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
