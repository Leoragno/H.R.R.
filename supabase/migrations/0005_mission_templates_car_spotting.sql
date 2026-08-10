-- =====================================================================
-- HRR — Fase 1 (2026-08-01): chiude i gap trovati nell'audit del Mission
-- Engine per Car Spotting, aggiunge una classifica globale reale (RPC,
-- sostituisce il PlaceholderScreen lato client) e prepara lo schema per
-- la telemetria avanzata futura (accelerometro/giroscopio/G-force),
-- senza implementarne la raccolta — resta esplicitamente Fase 3.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Mission templates mancanti: 'photo_uploaded' e 'rating_given' erano
-- già pubblicati/loggati (mission_event_log) da car_spotting_controller
-- ma nessuna missione li usava come target_metric — gli eventi non
-- facevano avanzare nulla. Stesso pattern/colonne di 0003, solo dati.
-- ---------------------------------------------------------------------
insert into public.mission_templates
  (code, title, description, type, target_value, target_metric, xp_reward, rep_reward, icon, difficulty, repeatable) values
  ('daily_publish_spot', 'Pubblica un avvistamento', 'Carica la foto di un''auto trovata nella vita reale', 'daily', 1, 'photo_uploaded', 30, 60, 'camera_alt', 'easy', true),
  ('daily_rate_five', 'Vota 5 auto', 'Assegna un voto a stelle a 5 avvistamenti della community', 'daily', 5, 'rating_given', 25, 50, 'star', 'normal', true)
on conflict (code) do nothing;

insert into public.mission_templates
  (code, title, description, type, target_value, target_metric, xp_reward, rep_reward, icon, difficulty, repeatable) values
  ('weekly_spots_5', '5 avvistamenti questa settimana', 'Pubblica 5 spot in questa settimana', 'weekly', 5, 'photo_uploaded', 120, 250, 'camera_alt', 'normal', true)
on conflict (code) do nothing;

-- ---------------------------------------------------------------------
-- leaderboard_global — classifica utenti (globale/mese/settimana).
-- security definer: aggrega xp_events, che è select-self-only via RLS
-- (xp_events_select_self in 0001), per esporre solo il totale periodico
-- per utente, mai le righe grezze — stesso principio già applicato in
-- sync_spot_rating_aggregate (0004): il client legge un aggregato
-- calcolato server-side, mai dati che dovrebbero restare privati.
-- 'all' ordina profiles.xp (il totale già mantenuto da apply_xp_event,
-- nessuna query aggiuntiva); 'week'/'month' sommano xp_events nella
-- finestra corrente. rank è 1-based, calcolato qui per evitare che ogni
-- client lo ricalcoli in modo divergente.
-- ---------------------------------------------------------------------
create or replace function public.leaderboard_global(
  p_period text default 'all',
  p_limit int default 50
) returns table (
  rank int,
  profile_id uuid,
  username text,
  display_name text,
  avatar_url text,
  level int,
  period_xp bigint,
  total_km numeric
)
language plpgsql security definer as $$
declare
  v_window_start timestamptz;
begin
  if p_period not in ('all', 'month', 'week') then
    raise exception 'Periodo non valido: % (atteso all|month|week)', p_period;
  end if;

  if p_period = 'all' then
    return query
      select row_number() over (order by p.xp desc)::int,
             p.id, p.username, p.display_name, p.avatar_url, p.level,
             p.xp, p.total_km
      from public.profiles p
      order by p.xp desc
      limit p_limit;
    return;
  end if;

  v_window_start := case p_period
    when 'week' then date_trunc('week', now())
    else date_trunc('month', now())
  end;

  return query
    select row_number() over (order by sum(e.xp_delta) desc)::int,
           p.id, p.username, p.display_name, p.avatar_url, p.level,
           sum(e.xp_delta)::bigint, p.total_km
    from public.profiles p
    join public.xp_events e
      on e.profile_id = p.id and e.created_at >= v_window_start
    group by p.id
    having sum(e.xp_delta) > 0
    order by sum(e.xp_delta) desc
    limit p_limit;
end;
$$;

grant execute on function public.leaderboard_global(text, int) to authenticated;

-- ---------------------------------------------------------------------
-- telemetry_points — solo schema, nessuna feature client scrive qui in
-- questo giro. Predispone l'architettura per accelerometro/giroscopio/
-- G-force richiesti dal concept (Trip Engine, Fase 3 "telemetria
-- avanzata"). Per-punto (a differenza di trips.route, che è la sola
-- polyline finale) così un domani un Driving AI Score può leggere la
-- serie temporale grezza di un viaggio.
-- ---------------------------------------------------------------------
create table public.telemetry_points (
  id uuid primary key default uuid_generate_v4(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  recorded_at timestamptz not null default now(),
  lat double precision,
  lng double precision,
  speed_kmh numeric(6,2),
  accel_x numeric(6,3),
  accel_y numeric(6,3),
  accel_z numeric(6,3),
  gyro_x numeric(6,3),
  gyro_y numeric(6,3),
  gyro_z numeric(6,3)
);

create index idx_telemetry_points_trip on public.telemetry_points(trip_id, recorded_at);

alter table public.telemetry_points enable row level security;

create policy "telemetry_points_select_owner" on public.telemetry_points for select
  using (auth.uid() = (select driver_id from public.trips where id = trip_id));

create policy "telemetry_points_insert_owner" on public.telemetry_points for insert
  with check (auth.uid() = (select driver_id from public.trips where id = trip_id));
