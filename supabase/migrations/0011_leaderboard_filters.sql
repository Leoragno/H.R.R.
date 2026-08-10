-- =====================================================================
-- HRR — Classifica: filtri aggiuntivi (scope "La mia crew", periodo
-- "oggi", metrica reputazione). p_crew_id è un nuovo parametro: cambia
-- la firma della funzione, quindi va droppata esplicitamente la
-- versione a 2 argomenti — "create or replace" da sola l'affiancherebbe
-- come overload invece di sostituirla (stesso motivo già documentato in
-- 0007_trip_route.sql per complete_trip).
-- =====================================================================

drop function if exists public.leaderboard_global(text, int);

create or replace function public.leaderboard_global(
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
  total_km numeric
)
language plpgsql security definer as $$
declare
  v_window_start timestamptz;
begin
  if p_period not in ('all', 'month', 'week', 'day') then
    raise exception 'Periodo non valido: % (atteso all|month|week|day)', p_period;
  end if;

  -- 'all' ordina profiles.xp/rep (i totali già mantenuti da apply_xp_event,
  -- nessuna aggregazione aggiuntiva); gli altri periodi sommano xp_events
  -- nella finestra corrente. p_crew_id filtra a un'unica crew quando
  -- presente (classifica "La mia crew"), altrimenti resta globale.
  if p_period = 'all' then
    return query
      select row_number() over (order by p.xp desc)::int,
             p.id, p.username, p.display_name, p.avatar_url, p.level,
             p.xp, p.rep, p.total_km
      from public.profiles p
      where p_crew_id is null or p.crew_id = p_crew_id
      order by p.xp desc
      limit p_limit;
    return;
  end if;

  v_window_start := case p_period
    when 'day' then date_trunc('day', now())
    when 'week' then date_trunc('week', now())
    else date_trunc('month', now())
  end;

  return query
    select row_number() over (order by sum(e.xp_delta) desc)::int,
           p.id, p.username, p.display_name, p.avatar_url, p.level,
           sum(e.xp_delta)::bigint, sum(e.rep_delta)::bigint, p.total_km
    from public.profiles p
    join public.xp_events e
      on e.profile_id = p.id and e.created_at >= v_window_start
    where p_crew_id is null or p.crew_id = p_crew_id
    group by p.id
    having sum(e.xp_delta) > 0
    order by sum(e.xp_delta) desc
    limit p_limit;
end;
$$;

grant execute on function public.leaderboard_global(text, int, uuid) to authenticated;
