-- =====================================================================
-- HRR — HEAT: economia XP (decisioni utente 2026-11-10).
--
--  1. Legame mascotte (LV 1-10) + bonus/malus mascotte VERI:
--       NITRO  FLOW alto: +25% dei bonus FLOW/guida pulita · REP −10%
--       R3X    +10 XP per esagono preso · i suoi territori decadono
--              un giorno prima (13 invece di 14)
--       VOLT   di notte +10% XP (e HEAT ±2, già nel client)
--       SPARK  +30 XP per spot pubblicato (max 5 al giorno) · −10%
--              XP distanza. Il "+10 REP" del design non c'è: la REP
--              resta solo riconoscimento altrui (0025).
--       DUST   bonus serie ×2 · un giorno saltato costa −40 legame
--     Ogni livello di legame sopra il primo: +5% sul bonus mascotte.
--  2. Guida: oltre alla resa base (km + FLOW, con gli antifarming di
--     0025) arrivano guida pulita (+40 a FLOW ≥ 85), prima guida del
--     giorno (+50) con serie (+10 per giorno, max 70) e HEAT di notte
--     ×(1 + (HEAT−1)·0.25), applicato per ultimo. Le righe finiscono in
--     trips.xp_breakdown per la schermata Risultato.
--  3. Pass di guida a stagioni trimestrali: 1000 XP stagione per tier
--     (gli XP del pass stesso non contano). Premi a ciclo: +150 XP (al
--     posto dei +100 REP del design), +250 XP, colore neon (sblocca il
--     prossimo accento: lime, arancio, ghiaccio), emote; ogni 5 tier la
--     skin neon; al 30 il titolo "RE DELLA STAGIONE". Sblocchi in
--     profile_unlocks, restano tra le stagioni.
--  4. Forzieri missioni: tutte le giornaliere riscattate +200 XP, tutte
--     le settimanali +600 XP (una volta per periodo).
--  5. Cambio missione giornaliero: una volta al giorno una giornaliera
--     non completata si sostituisce con una presa dal pool.
--
-- Orari "di notte" / "oggi" in Europe/Rome.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Utilità
-- ---------------------------------------------------------------------
create or replace function public.is_night(p_at timestamptz)
returns boolean language sql stable as $$
  select extract(hour from p_at at time zone 'Europe/Rome') >= 22
      or extract(hour from p_at at time zone 'Europe/Rome') < 6
$$;

create or replace function public.rome_day(p_at timestamptz)
returns date language sql stable as $$
  select (p_at at time zone 'Europe/Rome')::date
$$;

-- ---------------------------------------------------------------------
-- 1. Legame mascotte
-- ---------------------------------------------------------------------
create table if not exists public.mascot_bond (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  mascot_id text not null,
  points int not null default 0 check (points >= 0),
  updated_at timestamptz not null default now(),
  primary key (profile_id, mascot_id)
);
alter table public.mascot_bond enable row level security;
drop policy if exists "mascot_bond_select" on public.mascot_bond;
create policy "mascot_bond_select" on public.mascot_bond
  for select to authenticated using (true);

create or replace function public.bond_level(p_points int)
returns int language sql immutable as $$
  select count(*)::int
    from unnest(array[0,60,160,320,540,820,1180,1620,2160,2800]) t
   where t <= greatest(coalesce(p_points, 0), 0)
$$;

-- Moltiplicatore del bonus mascotte: +5% per livello di legame sopra il 1.
create or replace function public.bond_mult(p_profile uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select 1 + 0.05 * (public.bond_level(coalesce((
    select b.points from mascot_bond b join profiles p on p.id = b.profile_id
     where b.profile_id = p_profile and b.mascot_id = p.mascot_id), 0)) - 1)
$$;

-- HEAT prima di una guida: parte da 1, guida notturna +1, diurna −1
-- (VOLT ±2), fra 1 e 5, sulle ultime 20 guide completate. Stessa regola
-- di heatFromTripStarts (lib/features/progression/domain/progression.dart).
create or replace function public.heat_before(p_profile uuid, p_exclude uuid)
returns int language plpgsql stable security definer set search_path = public as $$
declare
  v_heat int := 1;
  v_step int;
  v_at timestamptz;
begin
  select case when mascot_id = 'volt' then 2 else 1 end into v_step
    from profiles where id = p_profile;
  for v_at in
    select s.started_at from (
      select started_at from trips
       where driver_id = p_profile and status = 'completed' and id <> p_exclude
       order by started_at desc limit 20) s
     order by s.started_at asc
  loop
    v_heat := least(5, greatest(1,
      v_heat + case when public.is_night(v_at) then v_step else -v_step end));
  end loop;
  return v_heat;
end;
$$;

-- Giorni consecutivi con almeno una guida completata, fino a IERI
-- compreso (0 = ieri non si è guidato).
create or replace function public.streak_days_before_today(p_profile uuid, p_exclude uuid)
returns int language plpgsql stable security definer set search_path = public as $$
declare
  v_day date := public.rome_day(now()) - 1;
  v_n int := 0;
begin
  while v_n < 60 and exists (
    select 1 from trips where driver_id = p_profile and status = 'completed'
       and id <> p_exclude and public.rome_day(started_at) = v_day) loop
    v_n := v_n + 1;
    v_day := v_day - 1;
  end loop;
  return v_n;
end;
$$;

alter table public.trips add column if not exists xp_breakdown jsonb;

-- NITRO: −10% sulla REP ricevuta.
create or replace function public.xp_events_mascot_rep() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.rep_delta > 0 and exists (
       select 1 from profiles where id = new.profile_id and mascot_id = 'nitro') then
    new.rep_delta := floor(new.rep_delta * 0.9);
  end if;
  return new;
end;
$$;
drop trigger if exists trg_xp_events_mascot_rep on public.xp_events;
create trigger trg_xp_events_mascot_rep before insert on public.xp_events
  for each row execute function public.xp_events_mascot_rep();

-- SPARK: +30 XP per spot pubblicato, al massimo 5 al giorno.
create or replace function public.spots_mascot_bonus() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from profiles where id = new.author_id and mascot_id = 'spark')
     and (select count(*) from spots
           where author_id = new.author_id
             and public.rome_day(created_at) = public.rome_day(now())) <= 5 then
    perform public._grant_xp_rep(new.author_id,
      round(30 * public.bond_mult(new.author_id))::int, 0, 'mascot', new.id);
  end if;
  return new;
end;
$$;
drop trigger if exists trg_spots_mascot_bonus on public.spots;
create trigger trg_spots_mascot_bonus after insert on public.spots
  for each row execute function public.spots_mascot_bonus();

-- R3X: i suoi territori decadono un giorno prima.
create or replace function public.territory_decay_days(p_owner uuid)
returns int language sql stable security definer set search_path = public as $$
  select case when exists (select 1 from profiles where id = p_owner and mascot_id = 'r3x')
              then public.territory_decay_days() - 1
              else public.territory_decay_days() end
$$;

-- === 0041 PARTE 2 ===

-- ---------------------------------------------------------------------
-- 2. Guida: bonus dentro complete_trip (resto invariato dalla live).
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- 3. Territori: R3X +10 XP per esagono e decadimento per proprietario.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.claim_territory_cells(p_cells jsonb, p_drive_score integer DEFAULT NULL::integer)
 RETURNS TABLE(fresh_count integer, stolen_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_profile_id uuid := auth.uid();
  v_actor_username text;
  v_cell jsonb;
  v_q int;
  v_r int;
  v_row public.territory_cells;
  v_expired boolean;
  v_fresh int := 0;
  v_stolen int := 0;
  v_victims jsonb := '{}'::jsonb;
  v_victim_id uuid;
  v_victim_count int;
  v_r3x_xp int;
begin
  if v_profile_id is null then
    raise exception 'Non autenticato';
  end if;

  for v_cell in select * from jsonb_array_elements(p_cells)
  loop
    v_q := (v_cell->>'q')::int;
    v_r := (v_cell->>'r')::int;

    select * into v_row from public.territory_cells
      where q = v_q and r = v_r for update;

    v_expired := v_row is not null
      and v_row.claimed_at < now() - (public.territory_decay_days(v_row.owner_id) || ' days')::interval;

    if v_row is null or v_expired then
      insert into public.territory_cells (q, r, owner_id, claimed_at, drive_score)
        values (v_q, v_r, v_profile_id, now(), p_drive_score)
        on conflict (q, r) do update
          set owner_id = excluded.owner_id, claimed_at = excluded.claimed_at,
              drive_score = excluded.drive_score;
      insert into public.territory_claim_log (q, r, claimant_id, previous_owner_id)
        values (v_q, v_r, v_profile_id, case when v_expired then v_row.owner_id else null end);
      v_fresh := v_fresh + 1;

    elsif v_row.owner_id = v_profile_id then
      update public.territory_cells set claimed_at = now() where q = v_q and r = v_r;
      -- Nessun log/punto: non è un claim, solo un rinnovo.

    else
      update public.territory_cells
        set owner_id = v_profile_id, claimed_at = now(), drive_score = p_drive_score
        where q = v_q and r = v_r;
      insert into public.territory_claim_log (q, r, claimant_id, previous_owner_id)
        values (v_q, v_r, v_profile_id, v_row.owner_id);
      v_stolen := v_stolen + 1;
      v_victims := jsonb_set(v_victims, array[v_row.owner_id::text],
        to_jsonb(coalesce((v_victims->>v_row.owner_id::text)::int, 0) + 1));
    end if;
  end loop;

  -- Una sola notifica per giocatore derubato, non una per cella: una
  -- guida che attraversa il suo quartiere ne toglierebbe decine.
  if v_victims <> '{}'::jsonb then
    select username into v_actor_username from public.profiles where id = v_profile_id;
    for v_victim_id, v_victim_count in
      select key::uuid, value::int from jsonb_each_text(v_victims)
    loop
      insert into public.notifications (profile_id, type, title, body, data)
        values (v_victim_id, 'territory_stolen', 'Territorio conquistato! 🏴',
          coalesce(v_actor_username, 'Qualcuno') || ' ti ha rubato ' ||
            case when v_victim_count = 1 then 'un esagono'
                 else v_victim_count || ' esagoni' end ||
            ' passandoci sopra.',
          jsonb_build_object('actor_id', v_profile_id, 'count', v_victim_count));
    end loop;
  end if;

  -- 0041 R3X: +10 XP per esagono preso (nuovo o rubato), al massimo
  -- 300 XP al giorno da questa fonte.
  if (v_fresh + v_stolen) > 0
     and exists (select 1 from public.profiles where id = v_profile_id and mascot_id = 'r3x') then
    select greatest(0, 300 - coalesce(sum(xp_delta), 0)) into v_r3x_xp
      from public.xp_events
     where profile_id = v_profile_id and source = 'mascot_hex'
       and public.rome_day(created_at) = public.rome_day(now());
    v_r3x_xp := least(v_r3x_xp, round((v_fresh + v_stolen) * 10 * public.bond_mult(v_profile_id))::int);
    if v_r3x_xp > 0 then
      perform public._grant_xp_rep(v_profile_id, v_r3x_xp, 0, 'mascot_hex', null);
    end if;
  end if;

  if v_fresh > 0 or v_stolen > 0 then
    perform public.evaluate_achievements(v_profile_id);
  end if;

  return query select v_fresh, v_stolen;
end;
$function$;

CREATE OR REPLACE FUNCTION public.my_territories()
 RETURNS TABLE(q integer, r integer, claimed_at timestamp with time zone, drive_score smallint)
 LANGUAGE sql
 STABLE
AS $function$
  select tc.q, tc.r, tc.claimed_at, tc.drive_score
  from public.territory_cells tc
  where tc.owner_id = auth.uid()
    and tc.claimed_at >= now() - (public.territory_decay_days(auth.uid()) || ' days')::interval
  order by tc.claimed_at asc;
$function$;

CREATE OR REPLACE FUNCTION public.territory_cells_near(p_q integer, p_r integer, p_cols integer, p_rows integer)
 RETURNS TABLE(q integer, r integer, owner_id uuid, claimed_at timestamp with time zone, drive_score smallint)
 LANGUAGE sql
 STABLE
AS $function$
  select tc.q, tc.r, tc.owner_id, tc.claimed_at, tc.drive_score
  from public.territory_cells tc
  where tc.q between p_q - p_cols and p_q + p_cols
    and tc.r between p_r - p_rows and p_r + p_rows
    and tc.claimed_at >= now() - (public.territory_decay_days(tc.owner_id) || ' days')::interval;
$function$;

-- ---------------------------------------------------------------------
-- 4. Cambio missione giornaliero
-- ---------------------------------------------------------------------
alter table public.mission_templates add column if not exists pool boolean not null default false;
alter table public.missions add column if not exists pool boolean not null default false;

create table if not exists public.mission_swaps (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  day date not null,
  old_mission_id uuid not null references public.missions(id) on delete cascade,
  new_mission_id uuid not null references public.missions(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (profile_id, day)
);
alter table public.mission_swaps enable row level security;
drop policy if exists "mission_swaps_select_self" on public.mission_swaps;
create policy "mission_swaps_select_self" on public.mission_swaps
  for select to authenticated using (auth.uid() = profile_id);

-- Una missione conta per un profilo se non l'ha cambiata e, quando è del
-- pool, se è proprio quella che ha pescato.
create or replace function public.mission_visible_to(p_profile uuid, p_mission uuid, p_pool boolean)
returns boolean language sql stable security definer set search_path = public as $$
  select not exists (select 1 from mission_swaps s
                      where s.profile_id = p_profile and s.old_mission_id = p_mission)
     and (not coalesce(p_pool, false) or exists (
           select 1 from mission_swaps s
            where s.profile_id = p_profile and s.new_mission_id = p_mission))
$$;

insert into public.mission_templates
  (code, title, description, type, target_value, target_metric, xp_reward, rep_reward, icon, difficulty, repeatable, pool)
values
  ('pool_km_8', 'Percorri 8 km', 'Guida per almeno 8 km oggi', 'daily', 8, 'trip_completed', 30, 0, 'route', 'easy', true, true),
  ('pool_km_25', 'Percorri 25 km', 'Guida per almeno 25 km oggi', 'daily', 25, 'trip_completed', 60, 0, 'route', 'hard', true, true),
  ('pool_two_drives', 'Due partenze', 'Avvia due viaggi oggi', 'daily', 2, 'trip_started', 20, 0, 'play_circle', 'easy', true, true),
  ('pool_rate_three', 'Vota 3 auto', 'Dai un voto a 3 avvistamenti', 'daily', 3, 'rating_given', 15, 0, 'star', 'easy', true, true),
  ('pool_comment', 'Di'' la tua', 'Commenta un avvistamento', 'daily', 1, 'comment_added', 15, 0, 'star', 'easy', true, true)
on conflict (code) do nothing;

CREATE OR REPLACE FUNCTION public.generate_daily_missions()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_count int := 0;
  v_template public.mission_templates;
  v_period text := to_char(now(), 'YYYYMMDD');
  v_day_start timestamptz := date_trunc('day', now());
begin
  for v_template in select * from public.mission_templates where type = 'daily' and active and not pool loop
    insert into public.missions (
      code, title, description, type, target_value, target_metric, xp_reward, rep_reward,
      icon, difficulty, reward_badges, reward_titles, reward_profile_items, reward_avatar_frame,
      hidden, secret, repeatable, template_id, starts_at, ends_at
    )
    values (
      v_template.code || '_' || v_period, v_template.title, v_template.description, v_template.type,
      v_template.target_value, v_template.target_metric, v_template.xp_reward, v_template.rep_reward,
      v_template.icon, v_template.difficulty, v_template.reward_badges, v_template.reward_titles,
      v_template.reward_profile_items, v_template.reward_avatar_frame, v_template.hidden,
      v_template.secret, v_template.repeatable, v_template.id,
      v_day_start, v_day_start + interval '1 day' - interval '1 second'
    )
    on conflict (code) do nothing;

    if found then
      v_count := v_count + 1;
    end if;
  end loop;
  return v_count;
end;
$function$;

CREATE OR REPLACE FUNCTION public._record_mission_event_for(p_profile_id uuid, p_event_type text, p_event_payload jsonb, p_idempotency_key text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_rows int;
  v_increment numeric;
  v_mission record;
  v_progress public.mission_progress;
  v_new_value numeric;
begin
  insert into public.mission_event_log (profile_id, event_type, event_payload, idempotency_key)
  values (p_profile_id, p_event_type, coalesce(p_event_payload, '{}'::jsonb), p_idempotency_key)
  on conflict (idempotency_key) do nothing;

  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    return;
  end if;

  v_increment := coalesce((p_event_payload->>'value')::numeric, 1);

  for v_mission in
    select m.* from public.missions m
    where m.target_metric = p_event_type
      and (m.starts_at is null or m.starts_at <= now())
      and (m.ends_at is null or m.ends_at >= now())
      -- 0041: le missioni del pool contano solo per chi le ha pescate,
      -- quelle sostituite non contano più per chi le ha cambiate.
      and public.mission_visible_to(p_profile_id, m.id, m.pool)
  loop
    insert into public.mission_progress (profile_id, mission_id, current_value)
    values (p_profile_id, v_mission.id, 0)
    on conflict (profile_id, mission_id) do nothing;

    select * into v_progress from public.mission_progress
      where profile_id = p_profile_id and mission_id = v_mission.id for update;

    if not v_progress.completed then
      v_new_value := least(v_mission.target_value, v_progress.current_value + v_increment);

      update public.mission_progress set
        current_value = v_new_value,
        completed = v_new_value >= v_mission.target_value,
        completed_at = case when v_new_value >= v_mission.target_value then now() else null end
      where profile_id = p_profile_id and mission_id = v_mission.id;

      if v_new_value >= v_mission.target_value then
        insert into public.notifications (profile_id, type, title, body, data)
          values (p_profile_id, 'mission_complete', 'Missione completata!', v_mission.title,
            jsonb_build_object('mission_id', v_mission.id));
      elsif v_progress.current_value < v_mission.target_value * 0.8
            and v_new_value >= v_mission.target_value * 0.8 then
        insert into public.notifications (profile_id, type, title, body, data)
          values (p_profile_id, 'mission_almost_done', 'Missione quasi completata', v_mission.title,
            jsonb_build_object('mission_id', v_mission.id));
      end if;
    end if;
  end loop;

  perform public.evaluate_achievements(p_profile_id);
end;
$function$;

CREATE OR REPLACE FUNCTION public.claim_mission(p_mission_id uuid, p_idempotency_key text)
 RETURNS mission_claims
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_profile_id uuid := auth.uid();
  v_progress public.mission_progress;
  v_mission public.missions;
  v_claim public.mission_claims;
  v_badge_id uuid;
  v_title text;
  v_key text;
  v_value jsonb;
begin
  if v_profile_id is null then
    raise exception 'Non autenticato';
  end if;

  select * into v_progress from public.mission_progress
    where profile_id = v_profile_id and mission_id = p_mission_id for update;

  if v_progress is null or not v_progress.completed then
    raise exception 'Missione non completata o non trovata';
  end if;

  if exists (select 1 from public.mission_claims where profile_id = v_profile_id and mission_id = p_mission_id) then
    raise exception 'Missione già riscattata';
  end if;

  select * into v_mission from public.missions where id = p_mission_id;

  if not public.mission_visible_to(v_profile_id, v_mission.id, v_mission.pool) then
    raise exception 'Missione non disponibile';
  end if;

  insert into public.mission_claims (profile_id, mission_id, idempotency_key)
  values (v_profile_id, p_mission_id, p_idempotency_key)
  returning * into v_claim;

  perform public._grant_xp_rep(v_profile_id, v_mission.xp_reward, v_mission.rep_reward, 'mission', v_mission.id);

  if v_mission.xp_reward > 0 then
    insert into public.mission_rewards (claim_id, reward_type, reward_value)
      values (v_claim.id, 'xp', jsonb_build_object('amount', v_mission.xp_reward));
  end if;
  if v_mission.rep_reward > 0 then
    insert into public.mission_rewards (claim_id, reward_type, reward_value)
      values (v_claim.id, 'rep', jsonb_build_object('amount', v_mission.rep_reward));
  end if;

  foreach v_badge_id in array coalesce(v_mission.reward_badges, '{}') loop
    insert into public.mission_rewards (claim_id, reward_type, reward_value)
      values (v_claim.id, 'badge', jsonb_build_object('badge_id', v_badge_id));
    insert into public.profile_badges (profile_id, badge_id)
      values (v_profile_id, v_badge_id) on conflict do nothing;
  end loop;

  foreach v_title in array coalesce(v_mission.reward_titles, '{}') loop
    insert into public.mission_rewards (claim_id, reward_type, reward_value)
      values (v_claim.id, 'title', jsonb_build_object('title', v_title));
  end loop;

  if v_mission.reward_avatar_frame is not null then
    insert into public.mission_rewards (claim_id, reward_type, reward_value)
      values (v_claim.id, 'avatar_frame', jsonb_build_object('frame', v_mission.reward_avatar_frame));
  end if;

  for v_key, v_value in select key, value from jsonb_each(coalesce(v_mission.reward_profile_items, '{}'::jsonb)) loop
    insert into public.mission_rewards (claim_id, reward_type, reward_value)
      values (v_claim.id, v_key, jsonb_build_object('value', v_value));
  end loop;

  insert into public.notifications (profile_id, type, title, body, data)
    values (v_profile_id, 'mission_claimed', 'Missione riscattata', v_mission.title,
      jsonb_build_object('mission_id', v_mission.id));

  return v_claim;
end;
$function$;

-- Sostituisce una giornaliera non completata con una del pool. Una volta
-- al giorno. Restituisce la missione nuova.
create or replace function public.reroll_daily_mission(p_mission_id uuid)
returns public.missions language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_old missions;
  v_new missions;
  v_tpl mission_templates;
  v_day date;
  v_period text;
begin
  if v_uid is null then raise exception 'Non autenticato'; end if;

  select * into v_old from missions where id = p_mission_id;
  if v_old is null or v_old.type <> 'daily'
     or v_old.starts_at > now() or v_old.ends_at < now()
     or not public.mission_visible_to(v_uid, v_old.id, v_old.pool) then
    raise exception 'Missione non sostituibile';
  end if;
  if exists (select 1 from mission_progress
              where profile_id = v_uid and mission_id = v_old.id and completed) then
    raise exception 'Missione già completata';
  end if;

  v_day := (v_old.starts_at at time zone 'UTC')::date;
  if exists (select 1 from mission_swaps where profile_id = v_uid and day = v_day) then
    raise exception 'Hai già cambiato una missione oggi';
  end if;

  select t.* into v_tpl from mission_templates t
   where t.type = 'daily' and t.active and t.pool
     and t.target_metric is distinct from v_old.target_metric
   order by random() limit 1;
  if v_tpl is null then
    select t.* into v_tpl from mission_templates t
     where t.type = 'daily' and t.active and t.pool order by random() limit 1;
  end if;
  if v_tpl is null then raise exception 'Nessuna missione di ricambio'; end if;

  v_period := to_char(v_old.starts_at at time zone 'UTC', 'YYYYMMDD');
  insert into missions (
    code, title, description, type, target_value, target_metric, xp_reward, rep_reward,
    icon, difficulty, reward_badges, reward_titles, reward_profile_items, reward_avatar_frame,
    hidden, secret, repeatable, template_id, starts_at, ends_at, pool)
  values (
    v_tpl.code || '_' || v_period, v_tpl.title, v_tpl.description, 'daily',
    v_tpl.target_value, v_tpl.target_metric, v_tpl.xp_reward, v_tpl.rep_reward,
    v_tpl.icon, v_tpl.difficulty, v_tpl.reward_badges, v_tpl.reward_titles,
    v_tpl.reward_profile_items, v_tpl.reward_avatar_frame, v_tpl.hidden,
    v_tpl.secret, v_tpl.repeatable, v_tpl.id, v_old.starts_at, v_old.ends_at, true)
  on conflict (code) do nothing;
  select * into v_new from missions where code = v_tpl.code || '_' || v_period;

  insert into mission_swaps (profile_id, day, old_mission_id, new_mission_id)
    values (v_uid, v_day, v_old.id, v_new.id);
  return v_new;
end;
$$;

-- ---------------------------------------------------------------------
-- 5. Forzieri missioni
-- ---------------------------------------------------------------------
create table if not exists public.mission_chests (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('daily', 'weekly')),
  period text not null,
  xp int not null,
  claimed_at timestamptz not null default now(),
  primary key (profile_id, kind, period)
);
alter table public.mission_chests enable row level security;
drop policy if exists "mission_chests_select_self" on public.mission_chests;
create policy "mission_chests_select_self" on public.mission_chests
  for select to authenticated using (auth.uid() = profile_id);

-- Si apre quando tutte le missioni del periodo corrente sono riscattate.
-- Il periodo è l'inizio delle missioni, così combacia con i generatori.
create or replace function public.claim_mission_chest(p_kind text)
returns int language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_total int;
  v_claimed int;
  v_period text;
  v_xp int := case p_kind when 'daily' then 200 when 'weekly' then 600 end;
begin
  if v_uid is null then raise exception 'Non autenticato'; end if;
  if v_xp is null then raise exception 'Forziere sconosciuto'; end if;

  select count(*), count(c.mission_id), to_char(min(m.starts_at) at time zone 'UTC', 'YYYYMMDD')
    into v_total, v_claimed, v_period
    from missions m
    left join mission_claims c on c.mission_id = m.id and c.profile_id = v_uid
   where m.type = p_kind
     and m.starts_at <= now() and m.ends_at >= now()
     and public.mission_visible_to(v_uid, m.id, m.pool);

  if v_total = 0 or v_claimed < v_total then
    raise exception 'Riscatta prima tutte le missioni';
  end if;

  insert into mission_chests (profile_id, kind, period, xp)
    values (v_uid, p_kind, v_period, v_xp)
    on conflict do nothing;
  if not found then raise exception 'Forziere già aperto'; end if;

  perform public._grant_xp_rep(v_uid, v_xp, 0, 'chest', null);
  return v_xp;
end;
$$;

-- ---------------------------------------------------------------------
-- 6. Pass di guida (stagione = trimestre, ora di Roma)
-- ---------------------------------------------------------------------
create table if not exists public.profile_unlocks (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  item text not null,          -- 'accent:lime', 'emote:esultanza', 'skin:neon', 'title:re_della_stagione'
  source text not null default 'pass',
  unlocked_at timestamptz not null default now(),
  primary key (profile_id, item)
);
alter table public.profile_unlocks enable row level security;
drop policy if exists "profile_unlocks_select" on public.profile_unlocks;
create policy "profile_unlocks_select" on public.profile_unlocks
  for select to authenticated using (true);

create table if not exists public.pass_claims (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  season text not null,
  tier int not null check (tier between 1 and 30),
  reward jsonb not null,
  claimed_at timestamptz not null default now(),
  primary key (profile_id, season, tier)
);
alter table public.pass_claims enable row level security;
drop policy if exists "pass_claims_select_self" on public.pass_claims;
create policy "pass_claims_select_self" on public.pass_claims
  for select to authenticated using (auth.uid() = profile_id);

create or replace function public.pass_season_start(p_at timestamptz)
returns timestamptz language sql stable as $$
  select date_trunc('quarter', p_at at time zone 'Europe/Rome') at time zone 'Europe/Rome'
$$;

create or replace function public.pass_season_key(p_at timestamptz)
returns text language sql stable as $$
  select to_char(p_at at time zone 'Europe/Rome', 'YYYY') || '-Q'
      || to_char(p_at at time zone 'Europe/Rome', 'Q')
$$;

-- Premio di un tier (stessa tabella in lib/features/progression/domain/pass.dart).
create or replace function public.pass_reward_kind(p_tier int)
returns text language sql immutable as $$
  select case
    when p_tier = 30 then 'title'
    when p_tier % 5 = 0 then 'skin'
    when p_tier % 4 = 0 then 'xp150'
    when p_tier % 4 = 1 then 'xp250'
    when p_tier % 4 = 2 then 'accent'
    else 'emote' end
$$;

create or replace function public.my_pass()
returns table (season text, starts_at timestamptz, ends_at timestamptz,
               season_xp int, tier int, claimed int[])
language sql stable security definer set search_path = public as $$
  with s as (
    select public.pass_season_key(now()) k, public.pass_season_start(now()) a
  ), x as (
    select coalesce(sum(e.xp_delta), 0)::int xp from xp_events e, s
     where e.profile_id = auth.uid() and e.created_at >= s.a and e.source <> 'pass'
  )
  select s.k, s.a,
         (date_trunc('quarter', s.a at time zone 'Europe/Rome') + interval '3 months')
           at time zone 'Europe/Rome',
         x.xp, least(30, x.xp / 1000),
         coalesce((select array_agg(c.tier order by c.tier) from pass_claims c
                    where c.profile_id = auth.uid() and c.season = s.k), '{}')
    from s, x
$$;

-- Riscuote un tier (p_tier) o tutti quelli sbloccati e non presi (null).
-- I cosmetici già posseduti diventano XP, così nessun tier è vuoto.
create or replace function public.claim_pass(p_tier int default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_pass record;
  v_t int;
  v_kind text;
  v_item text;
  v_xp int;
  v_reward jsonb;
  v_out jsonb := '[]'::jsonb;
begin
  if v_uid is null then raise exception 'Non autenticato'; end if;
  select * into v_pass from public.my_pass();
  if p_tier is not null and (p_tier < 1 or p_tier > v_pass.tier) then
    raise exception 'Tier non ancora sbloccato';
  end if;

  for v_t in
    select g from generate_series(1, v_pass.tier) g
     where (p_tier is null or g = p_tier) and not (g = any(v_pass.claimed))
     order by g
  loop
    v_kind := public.pass_reward_kind(v_t);
    v_item := null;
    v_xp := 0;
    if v_kind = 'accent' then
      select i into v_item from unnest(array['accent:lime', 'accent:arancio', 'accent:ghiaccio'])
        with ordinality u(i, o)
       where not exists (select 1 from profile_unlocks where profile_id = v_uid and item = u.i)
       order by o limit 1;
      if v_item is null then v_xp := 250; end if;
    elsif v_kind in ('emote', 'skin', 'title') then
      v_item := case v_kind when 'emote' then 'emote:esultanza'
                            when 'skin' then 'skin:neon'
                            else 'title:re_della_stagione' end;
      if exists (select 1 from profile_unlocks where profile_id = v_uid and item = v_item) then
        v_item := null;
        v_xp := 150;
      end if;
    else
      v_xp := case v_kind when 'xp150' then 150 else 250 end;
    end if;

    v_reward := jsonb_build_object('tier', v_t, 'kind', v_kind, 'item', v_item, 'xp', v_xp);
    insert into pass_claims (profile_id, season, tier, reward)
      values (v_uid, v_pass.season, v_t, v_reward)
      on conflict do nothing;
    if not found then continue; end if;

    if v_item is not null then
      insert into profile_unlocks (profile_id, item) values (v_uid, v_item)
        on conflict do nothing;
    end if;
    if v_xp > 0 then
      perform public._grant_xp_rep(v_uid, v_xp, 0, 'pass', null);
    end if;
    v_out := v_out || v_reward;
  end loop;
  return v_out;
end;
$$;

-- ---------------------------------------------------------------------
-- 7. Permessi
-- ---------------------------------------------------------------------
revoke execute on function public.bond_mult(uuid) from public, anon, authenticated;
revoke execute on function public.heat_before(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.streak_days_before_today(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.mission_visible_to(uuid, uuid, boolean) from public, anon, authenticated;

revoke execute on function public.reroll_daily_mission(uuid) from public, anon;
revoke execute on function public.claim_mission_chest(text) from public, anon;
revoke execute on function public.my_pass() from public, anon;
revoke execute on function public.claim_pass(int) from public, anon;
grant execute on function public.reroll_daily_mission(uuid) to authenticated;
grant execute on function public.claim_mission_chest(text) to authenticated;
grant execute on function public.my_pass() to authenticated;
grant execute on function public.claim_pass(int) to authenticated;
