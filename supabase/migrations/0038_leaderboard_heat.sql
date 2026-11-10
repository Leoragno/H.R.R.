-- HEAT · Classifica: nuove metriche del redesign (velocità media, guida più
-- lunga, miglior 0-100) + mascotte e paese per hero/bandiere.
-- Solo ridefinizione della RPC: nessun dato toccato.
--
-- Metriche: xp | rep | km | speed | avg | long | zero
--   avg  = km totali / ore totali dei viaggi completati (media pesata)
--   long = distanza del viaggio completato più lungo
--   zero = miglior 0-100 in secondi (ordinamento CRESCENTE, esclusi i null)
-- Il periodo filtra xp/rep (xp_events) e le metriche da viaggio (started_at).

drop function if exists public.leaderboard_global(text, text, int);

create or replace function public.leaderboard_global(
  p_metric text default 'xp',
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
  period_rep bigint,
  total_km numeric,
  top_speed_kmh numeric,
  avg_speed_kmh numeric,
  longest_trip_km numeric,
  best_zero_to_hundred numeric,
  mascot_id text,
  country text
)
language plpgsql security definer as $$
declare
  v_window_start timestamptz;
begin
  if p_metric not in ('xp', 'rep', 'km', 'speed', 'avg', 'long', 'zero') then
    raise exception 'Metrica non valida: % (atteso xp|rep|km|speed|avg|long|zero)', p_metric;
  end if;
  if p_period not in ('all', 'month', 'week', 'day') then
    raise exception 'Periodo non valido: % (atteso all|month|week|day)', p_period;
  end if;

  v_window_start := case p_period
    when 'day' then date_trunc('day', now())
    when 'week' then date_trunc('week', now())
    when 'month' then date_trunc('month', now())
    else null
  end;

  return query
    with trip_agg as (
      select
        t.driver_id,
        sum(t.distance_km) as km,
        sum(t.duration_seconds) as secs,
        max(t.max_speed_kmh) as top,
        max(t.distance_km) as longest,
        min(t.zero_to_hundred_seconds) filter (
          where t.zero_to_hundred_seconds > 0
        ) as zero
      from public.trips t
      where t.status = 'completed'
        and (v_window_start is null or t.started_at >= v_window_start)
      group by t.driver_id
    ),
    base as (
      select
        p.id,
        p.username,
        p.display_name,
        p.avatar_url,
        p.level,
        p.mascot_id,
        p.country,
        (case when p_period = 'all' then p.total_km
              else coalesce(a.km, 0) end) as m_km,
        (case when p_period = 'all' then p.xp::numeric
              else coalesce((
                select sum(e.xp_delta) from public.xp_events e
                where e.profile_id = p.id and e.created_at >= v_window_start
              ), 0)
         end) as m_xp,
        (case when p_period = 'all' then p.rep::numeric
              else coalesce((
                select sum(e.rep_delta) from public.xp_events e
                where e.profile_id = p.id and e.created_at >= v_window_start
              ), 0)
         end) as m_rep,
        coalesce(a.top, 0) as m_speed,
        (case when coalesce(a.secs, 0) > 0
              then round(a.km / (a.secs / 3600.0), 1)
              else 0 end) as m_avg,
        coalesce(a.longest, 0) as m_long,
        a.zero as m_zero
      from public.profiles p
      left join trip_agg a on a.driver_id = p.id
    ),
    ranked as (
      select
        b.*,
        (case p_metric
           when 'xp' then m_xp
           when 'rep' then m_rep
           when 'km' then m_km
           when 'speed' then m_speed
           when 'avg' then m_avg
           when 'long' then m_long
           else m_zero
         end) as m_selected
      from base b
    )
    select
      (case when p_metric = 'zero'
            then row_number() over (order by r.m_selected asc)
            else row_number() over (order by r.m_selected desc)
       end)::int,
      r.id, r.username, r.display_name, r.avatar_url, r.level,
      r.m_xp::bigint, r.m_rep::bigint, r.m_km, r.m_speed,
      r.m_avg, r.m_long, r.m_zero, r.mascot_id, r.country
    from ranked r
    where (p_metric = 'zero' and r.m_selected is not null)
       or (p_metric <> 'zero' and (p_period = 'all' or r.m_selected > 0))
    order by
      (case when p_metric = 'zero' then r.m_selected end) asc,
      (case when p_metric <> 'zero' then r.m_selected end) desc
    limit p_limit;
end;
$$;

grant execute on function public.leaderboard_global(text, text, int) to authenticated;
