-- =====================================================================
-- HRR — Classifica: metrica "Velocità massima" (record a vita, come
-- Km totali — non azzerata dal filtro periodo, calcolata da trips.
-- max_speed_kmh dei viaggi completati).
--
-- Approfittando del giro: la RPC finora ordinava SEMPRE per XP (rank =
-- row_number su xp/period_xp) anche quando il client mostrava un'altra
-- metrica (reputazione, km) — la lista appariva quindi "fuori ordine"
-- per quelle metriche. Aggiungo p_metric e ordino/rankizzo in base alla
-- metrica richiesta, così ogni classifica è davvero ordinata per la
-- colonna che mostra.
-- =====================================================================

drop function if exists public.leaderboard_global(text, int, uuid);

create or replace function public.leaderboard_global(
  p_metric text default 'xp',
  p_period text default 'all',
  p_limit int default 50,
  p_crew_id uuid default null
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
  top_speed_kmh numeric
)
language plpgsql security definer as $$
declare
  v_window_start timestamptz;
begin
  if p_metric not in ('xp', 'rep', 'km', 'speed') then
    raise exception 'Metrica non valida: % (atteso xp|rep|km|speed)', p_metric;
  end if;
  if p_period not in ('all', 'month', 'week', 'day') then
    raise exception 'Periodo non valido: % (atteso all|month|week|day)', p_period;
  end if;

  v_window_start := case p_period
    when 'day' then date_trunc('day', now())
    when 'week' then date_trunc('week', now())
    when 'month' then date_trunc('month', now())
    else null -- 'all': nessun filtro temporale
  end;

  return query
    with base as (
      select
        p.id,
        p.username,
        p.display_name,
        p.avatar_url,
        p.level,
        p.total_km,
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
        -- record di velocità: sempre a vita, come total_km sopra — un
        -- filtro periodo non "azzera" il proprio record personale.
        coalesce((
          select max(t.max_speed_kmh) from public.trips t
          where t.driver_id = p.id and t.status = 'completed'
        ), 0) as m_speed
      from public.profiles p
      where p_crew_id is null or p.crew_id = p_crew_id
    ),
    ranked as (
      select
        b.*,
        (case p_metric
           when 'xp' then m_xp
           when 'rep' then m_rep
           when 'km' then b.total_km
           else m_speed
         end) as m_selected
      from base b
    )
    select
      row_number() over (order by r.m_selected desc)::int,
      r.id, r.username, r.display_name, r.avatar_url, r.level,
      r.m_xp::bigint, r.m_rep::bigint, r.total_km, r.m_speed
    from ranked r
    -- 'all' mostra tutti (anche chi è a zero, coerente col comportamento
    -- storico); i periodi finestrati nascondono chi non ha nulla da
    -- mostrare in quella finestra per la metrica scelta.
    where p_period = 'all' or r.m_selected > 0
    order by r.m_selected desc
    limit p_limit;
end;
$$;

grant execute on function public.leaderboard_global(text, text, int, uuid) to authenticated;
