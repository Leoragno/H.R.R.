-- =====================================================================
-- HRR — Piloti lato server: sinergia, maestria e perk (handoff HEAT,
-- "Update · tutorial, XP, piloti, mascotte").
--
--  * pilot_of(...) è la copia 1:1 di archetypeAffinities +
--    matchDriverArchetype (lib/features/trip/domain/driver_archetype.dart):
--    stesse soglie, stesso ordine di spareggio. Se cambi uno, cambia
--    l'altro.
--  * trips.pilot salva il pilota di ogni guida (backfill sui viaggi già
--    completati) — così pilota principale e maestria si leggono dal DB.
--  * complete_trip, dopo il bonus mascotte e prima dell'HEAT:
--      SINERGIA PILOTA +15% se il pilota della guida è il principale
--      (il più frequente nelle ultime 10, a parità il più recente);
--      PERK del pilota principale se ha maestria ≥ 2 (≥ 3 guide abbinate)
--      e la condizione è vera in questa guida.
--    Perk: Toretto +20% (0-100 < 8 s), Han +20% (G > 0,8), Martin +40
--    (FLOW ≥ 85), Il Driver +25% (notte), Colburn +30 XP (REP non arriva
--    dalle guide: convertita come i premi del pass), Saetta +15% (> 15 km),
--    Baby +5 per cambio corsia (max 50), Max +20% (> 60 km: qui Max è il
--    pilota delle guide lunghe, non della velocità), Fantozzi minimo 60 XP,
--    Bean casuale 10–80, O'Conner +10%.
-- =====================================================================

alter table public.trips add column if not exists pilot text;

create or replace function public._ramp(x numeric, lo numeric, hi numeric)
returns numeric language sql immutable as $$
  select case when x <= lo then 0 when x >= hi then 1 else (x - lo) / (hi - lo) end
$$;

create or replace function public.pilot_of(
  p_km numeric, p_dur int, p_avg numeric, p_score int, p_accel numeric,
  p_z100 numeric, p_peak_g numeric, p_corner numeric, p_turns int,
  p_lanes int, p_brakes int, p_stops int, p_stopped int, p_elev numeric)
returns text language plpgsql immutable set search_path = public as $$
declare
  v_avg numeric;
  v_accel numeric := coalesce(p_accel, 0);
  v_clean boolean;
  v_best text := 'brianOConner';
  v_best_s numeric := 0.35;
  v_s numeric;
  v_name text;
  v_brakes_km numeric;
  v_stops_km numeric;
begin
  if p_peak_g is null or p_brakes is null
     or p_km < 2.0 or p_dur < 300 then
    return null;
  end if;
  v_avg := coalesce(p_avg, p_km / (p_dur / 3600.0));
  v_brakes_km := p_brakes / p_km;
  v_stops_km := coalesce(p_stops, 0) / p_km;
  v_clean := p_peak_g < 1.0
    and case when p_score is null then p_peak_g < 0.8 else p_score >= 55 end;

  -- Ordine di dichiarazione dell'enum Dart: a parità vince il primo.
  foreach v_name in array array['theDriver','hokeColburn','dominicToretto',
      'hanLue','frankMartin','saettaMcQueen','baby','maxRockatansky',
      'ugoFantozzi','mrBean'] loop
    v_s := case v_name
      when 'theDriver' then case when p_score is not null then
        _ramp(p_score, 75, 95) * _ramp(v_avg, 40, 70) * (1 - _ramp(v_brakes_km, 1, 3)) end
      when 'hokeColburn' then case when p_score is not null then
        _ramp(p_score, 70, 90) * (1 - _ramp(v_avg, 30, 45)) * (1 - _ramp(p_peak_g, 0.25, 0.45)) end
      when 'dominicToretto' then case when v_clean then
        greatest(_ramp(v_accel, 3.0, 6.0),
                 case when p_z100 is not null then _ramp(14 - p_z100, 0, 7) else 0 end) end
      when 'hanLue' then case when v_clean and coalesce(p_turns, 0) >= 4 then
        0.5 * _ramp(p_peak_g, 0.35, 0.7) + 0.5 * _ramp(coalesce(p_corner, 0), 30, 60) end
      when 'frankMartin' then case when v_clean and p_score is not null then
        _ramp(p_score, 70, 90) * _ramp(v_accel, 2.5, 4.5) end
      when 'saettaMcQueen' then
        _ramp(v_avg, 60, 95) * (1 - _ramp(v_stops_km, 0.1, 0.5))
      when 'baby' then
        (0.5 * _ramp(coalesce(p_turns, 0) / p_km, 2, 5)
         + 0.5 * _ramp(coalesce(p_lanes, 0) / p_km, 0.5, 2)) * (1 - _ramp(v_avg, 55, 75))
      when 'maxRockatansky' then
        greatest(_ramp(p_km, 60, 150), _ramp(coalesce(p_elev, 0) / p_km, 15, 40))
      when 'ugoFantozzi' then
        0.6 * _ramp(coalesce(p_stopped, 0)::numeric / p_dur, 0.15, 0.4)
        + 0.4 * _ramp(v_stops_km, 0.8, 2.5)
      when 'mrBean' then case when p_score is not null then
        0.6 * (1 - _ramp(p_score, 35, 55)) + 0.4 * _ramp(v_brakes_km, 2, 5)
        else _ramp(v_brakes_km, 2.5, 6) end
    end;
    if v_s is not null and v_s > v_best_s then
      v_best := v_name;
      v_best_s := v_s;
    end if;
  end loop;
  return v_best;
end;
$$;

create or replace function public.pilot_of_trip(t public.trips)
returns text language sql immutable set search_path = public as $$
  select public.pilot_of(t.distance_km, t.duration_seconds, t.avg_speed_kmh,
    t.driving_score, t.max_acceleration_ms2, t.zero_to_hundred_seconds,
    t.peak_g_force, t.max_cornering_speed_kmh,
    coalesce(t.turns_left, 0) + coalesce(t.turns_right, 0), t.lane_changes,
    t.braking_events, t.total_stops, t.stopped_seconds, t.elevation_gain_m)
$$;

update public.trips t set pilot = public.pilot_of_trip(t)
 where t.status = 'completed' and t.pilot is null;

create or replace function public.pilot_label(p text)
returns text language sql immutable as $$
  select case p
    when 'brianOConner' then 'O''CONNER' when 'theDriver' then 'IL DRIVER'
    when 'hokeColburn' then 'COLBURN' when 'dominicToretto' then 'TORETTO'
    when 'hanLue' then 'HAN' when 'frankMartin' then 'MARTIN'
    when 'saettaMcQueen' then 'SAETTA' when 'baby' then 'BABY'
    when 'maxRockatansky' then 'MAX' when 'ugoFantozzi' then 'FANTOZZI'
    when 'mrBean' then 'MR. BEAN' else upper(coalesce(p, '')) end
$$;

revoke all on function public.pilot_of(numeric,int,numeric,int,numeric,numeric,numeric,numeric,int,int,int,int,int,numeric) from public, anon, authenticated;
revoke all on function public.pilot_of_trip(public.trips) from public, anon, authenticated;
revoke all on function public._ramp(numeric,numeric,numeric) from public, anon, authenticated;


CREATE OR REPLACE FUNCTION public.complete_trip(p_trip_id uuid, p_distance_km numeric, p_duration_seconds integer, p_avg_speed_kmh numeric, p_max_speed_kmh numeric, p_route_wkt text DEFAULT NULL::text, p_jerk_rms_ms3 numeric DEFAULT NULL::numeric, p_braking_soft_count integer DEFAULT 0, p_braking_hard_count integer DEFAULT 0, p_braking_jerk_avg_ms3 numeric DEFAULT NULL::numeric, p_turns_count integer DEFAULT 0, p_turn_gyro_stddev_avg numeric DEFAULT NULL::numeric, p_total_stops integer DEFAULT 0, p_stopped_seconds integer DEFAULT 0, p_accel_then_brake_count integer DEFAULT 0, p_gps_fix_hz numeric DEFAULT NULL::numeric, p_gyro_hz numeric DEFAULT NULL::numeric, p_elevation_gain_m numeric DEFAULT NULL::numeric, p_max_altitude_m numeric DEFAULT NULL::numeric, p_max_acceleration_ms2 numeric DEFAULT NULL::numeric, p_max_deceleration_ms2 numeric DEFAULT NULL::numeric, p_zero_to_hundred_seconds numeric DEFAULT NULL::numeric, p_peak_g_force numeric DEFAULT NULL::numeric, p_turns_left integer DEFAULT 0, p_turns_right integer DEFAULT 0, p_lane_changes integer DEFAULT 0, p_max_cornering_speed_kmh numeric DEFAULT NULL::numeric)
 RETURNS trips
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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

  -- 0041: bonus HEAT, mascotte e legame.
  v_mascot text;
  v_bm numeric;
  v_lines jsonb := '[]'::jsonb;
  v_base int;
  v_flow int;
  v_mascot_bonus numeric := 0;
  v_first boolean;
  v_streak int;
  v_streak_xp int;
  v_prev_day date;
  v_missed int;
  v_bond_malus int := 0;
  v_heat int;
  v_heat_xp int;
  v_step int;

  -- 0043: piloti.
  v_pilot text;
  v_main text;
  v_hist text[];
  v_matched int;
  v_pre int;
  v_syn int;
  v_perk int;
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

  -- 0043: pilota della guida (stessa regola del client).
  v_pilot := public.pilot_of(p_distance_km, p_duration_seconds, p_avg_speed_kmh,
    v_driving_score, p_max_acceleration_ms2, p_zero_to_hundred_seconds,
    p_peak_g_force, p_max_cornering_speed_kmh,
    coalesce(p_turns_left, 0) + coalesce(p_turns_right, 0), p_lane_changes,
    coalesce(p_braking_soft_count, 0) + coalesce(p_braking_hard_count, 0),
    p_total_stops, p_stopped_seconds, p_elevation_gain_m);

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

    -- -----------------------------------------------------------------
    -- 0041 — bonus. Solo per guide valide (siamo nel ramo che assegna
    -- livello). Ordine: resa base → guida pulita → prima guida e serie →
    -- mascotte → HEAT di notte, per ultimo su tutto il resto.
    -- -----------------------------------------------------------------
    select mascot_id into v_mascot from public.profiles where id = v_trip.driver_id;
    v_bm := public.bond_mult(v_trip.driver_id);
    v_base := v_xp;
    v_flow := coalesce(v_driving_score, 0);
    v_lines := jsonb_build_array(jsonb_build_object(
      'k', 'base', 'label', 'DISTANZA E FLOW', 'xp', v_base));

    if v_xp > 0 and v_flow >= 85 then
      v_lines := v_lines || jsonb_build_object('k', 'clean', 'label', 'GUIDA PULITA', 'xp', 40);
      v_xp := v_xp + 40;
      -- NITRO: +25% sulla parte FLOW della resa base e sulla guida pulita.
      if v_mascot = 'nitro' then
        v_mascot_bonus := v_mascot_bonus
          + 0.25 * (v_base * v_flow / (100.0 + v_flow) + 40) * v_bm;
      end if;
    end if;

    -- SPARK: −10% XP distanza (il malus non cresce col legame).
    if v_mascot = 'spark' then
      v_mascot_bonus := v_mascot_bonus - v_base * 0.10;
    end if;

    v_first := not exists (
      select 1 from public.trips t
       where t.driver_id = v_trip.driver_id and t.status = 'completed'
         and t.id <> v_trip.id and t.xp_earned > 0
         and public.rome_day(t.started_at) = public.rome_day(now()));
    if v_first then
      v_lines := v_lines || jsonb_build_object('k', 'first', 'label', 'PRIMA GUIDA DEL GIORNO', 'xp', 50);
      v_xp := v_xp + 50;

      v_streak := public.streak_days_before_today(v_trip.driver_id, v_trip.id);
      if v_streak >= 1 then
        v_streak_xp := least(70, (v_streak + 1) * 10);
        v_lines := v_lines || jsonb_build_object('k', 'streak',
          'label', 'SERIE ' || (v_streak + 1) || ' GIORNI', 'xp', v_streak_xp);
        v_xp := v_xp + v_streak_xp;
        -- DUST: bonus serie ×2.
        if v_mascot = 'dust' then
          v_mascot_bonus := v_mascot_bonus + v_streak_xp * v_bm;
        end if;
      elsif v_mascot = 'dust' then
        -- DUST: ogni giorno saltato costa 40 punti legame (max 5 giorni).
        select max(public.rome_day(t.started_at)) into v_prev_day
          from public.trips t
         where t.driver_id = v_trip.driver_id and t.status = 'completed' and t.id <> v_trip.id;
        if v_prev_day is not null then
          v_missed := (public.rome_day(now()) - v_prev_day) - 1;
          if v_missed > 0 then
            v_bond_malus := 40 * least(v_missed, 5);
          end if;
        end if;
      end if;
    end if;

    -- VOLT: di notte +10% XP.
    if v_mascot = 'volt' and public.is_night(v_trip.started_at) then
      v_mascot_bonus := v_mascot_bonus + v_xp * 0.10 * v_bm;
    end if;

    if round(v_mascot_bonus) <> 0 then
      v_lines := v_lines || jsonb_build_object('k', 'mascot',
        'label', 'BONUS ' || upper(coalesce(v_mascot, '')), 'xp', round(v_mascot_bonus)::int);
      v_xp := greatest(0, v_xp + round(v_mascot_bonus)::int);
    end if;

    -- 0043: sinergia e perk del pilota principale.
    if v_pilot is not null and v_xp > 0 then
      select array_agg(h.pilot order by h.started_at desc) into v_hist
        from (select t.pilot, t.started_at from public.trips t
               where t.driver_id = v_trip.driver_id and t.status = 'completed'
                 and t.id <> v_trip.id and t.pilot is not null
               order by t.started_at desc limit 9) h;
      v_hist := array[v_pilot] || coalesce(v_hist, '{}'::text[]);
      -- Il più frequente nelle ultime 10; a parità il più recente.
      select s.p into v_main from (
        select u.p, count(*) as c, min(u.i) as first_i
          from unnest(v_hist) with ordinality as u(p, i) group by u.p) s
       order by s.c desc, s.first_i asc limit 1;

      v_pre := v_xp;
      if v_main = v_pilot then
        v_syn := round(v_pre * 0.15);
        if v_syn > 0 then
          v_lines := v_lines || jsonb_build_object('k', 'synergy',
            'label', 'SINERGIA PILOTA', 'xp', v_syn);
          v_xp := v_xp + v_syn;
        end if;
      end if;

      -- Maestria ≥ 2 stelle = almeno 3 guide abbinate al principale.
      select count(*) into v_matched from public.trips t
       where t.driver_id = v_trip.driver_id and t.status = 'completed'
         and t.id <> v_trip.id and t.pilot = v_main;
      v_matched := v_matched + case when v_main = v_pilot then 1 else 0 end;
      if v_matched >= 3 then
        v_perk := case v_main
          when 'dominicToretto' then case when p_zero_to_hundred_seconds < 8 then round(v_pre * 0.20) end
          when 'hanLue' then case when p_peak_g_force > 0.8 then round(v_pre * 0.20) end
          when 'frankMartin' then case when v_flow >= 85 then 40 end
          when 'theDriver' then case when public.is_night(v_trip.started_at) then round(v_pre * 0.25) end
          when 'hokeColburn' then 30
          when 'saettaMcQueen' then case when p_distance_km > 15 then round(v_pre * 0.15) end
          when 'baby' then least(50, 5 * coalesce(p_lane_changes, 0))
          when 'maxRockatansky' then case when p_distance_km > 60 then round(v_pre * 0.20) end
          when 'ugoFantozzi' then greatest(0, 60 - v_xp)
          when 'mrBean' then 10 + floor(random() * 71)::int
          when 'brianOConner' then round(v_pre * 0.10)
        end;
        if coalesce(v_perk, 0) > 0 then
          v_lines := v_lines || jsonb_build_object('k', 'perk',
            'label', 'PERK ' || public.pilot_label(v_main), 'xp', v_perk);
          v_xp := v_xp + v_perk;
        end if;
      end if;
    end if;

    -- HEAT di notte: ×(1 + (HEAT−1)·0.25), HEAT già aggiornato da questa guida.
    if public.is_night(v_trip.started_at) then
      v_step := case when v_mascot = 'volt' then 2 else 1 end;
      v_heat := least(5, public.heat_before(v_trip.driver_id, v_trip.id) + v_step);
      v_heat_xp := round(v_xp * (v_heat - 1) * 0.25);
      if v_heat_xp > 0 then
        v_lines := v_lines || jsonb_build_object('k', 'heat',
          'label', 'NOTTE · HEAT ' || v_heat, 'xp', v_heat_xp);
        v_xp := v_xp + v_heat_xp;
      end if;
    end if;

    -- Legame: +10% degli XP della guida alla mascotte attuale.
    if v_mascot is not null and (v_xp > 0 or v_bond_malus > 0) then
      insert into public.mascot_bond as b (profile_id, mascot_id, points)
        values (v_trip.driver_id, v_mascot, greatest(0, round(v_xp * 0.10)::int - v_bond_malus))
        on conflict (profile_id, mascot_id) do update
          set points = greatest(0, b.points + round(v_xp * 0.10)::int - v_bond_malus),
              updated_at = now();
    end if;
  end if;

  update public.trips set
    ended_at = now(),
    distance_km = p_distance_km,
    duration_seconds = p_duration_seconds,
    avg_speed_kmh = p_avg_speed_kmh,
    max_speed_kmh = p_max_speed_kmh,
    xp_earned = v_xp,
    xp_breakdown = case when v_xp > 0 then v_lines else null end,
    rep_earned = v_rep,
    driving_score = v_driving_score,
    pilot = v_pilot,
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
$function$;

