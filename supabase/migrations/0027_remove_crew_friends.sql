-- =====================================================================
-- HRR — Rimozione di crew e amici: l'app è privata e chiusa, tutti gli
-- utenti sono già "connessi" tra loro. Non serve più un sistema di
-- gruppi (crew) né un grafo di amicizie con richieste di invito — resta
-- una sola classifica globale e una sola mappa live condivisa.
--
-- Le segnalazioni radar di crew ("Velox Crew"/"Pattuglia Crew") NON
-- vengono cancellate: diventano segnalazioni community, visibili e
-- inviabili da/a chiunque, invece di essere ristrette alla propria crew.
--
-- Ordine pensato per non aver mai bisogno di CASCADE: le funzioni
-- "language sql" (dependency-tracked da Postgres come le view) e le RLS
-- policy che referenziano crew_members/crews/profiles.crew_id/friendships
-- vengono ridefinite o droppate PRIMA delle tabelle/colonne che
-- referenziano; le tabelle vengono droppate in ordine figlio → genitore.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Funzioni/RPC crew (plpgsql, nessuna sostituisce query autorevoli
--    altrove) — droppate per prime, nessun altro oggetto dipende da loro.
-- ---------------------------------------------------------------------
drop function if exists public.crew_leave(uuid);
drop function if exists public.crew_cast_disband_vote(uuid);
drop function if exists public.crew_retract_disband_vote(uuid);

-- ---------------------------------------------------------------------
-- 2. Funzioni amici (send/respond/remove sono plpgsql; my_friends/
--    pending_friend_requests/search_profiles_for_friend sono "language
--    sql" e dipendono da public.friendships — vanno droppate prima di
--    droppare quella tabella più sotto).
-- ---------------------------------------------------------------------
drop function if exists public.send_friend_request(uuid);
drop function if exists public.respond_friend_request(uuid, boolean);
drop function if exists public.remove_friend(uuid);
drop function if exists public.my_friends();
drop function if exists public.pending_friend_requests();
drop function if exists public.search_profiles_for_friend(text);

-- ---------------------------------------------------------------------
-- 3. Realtime authorization: via i canali per-crew e per-amico, dentro
--    un unico canale broadcast condiviso "drivers-live" per tutti gli
--    utenti autenticati in guida (sostituisce sia crew-live-<crew_id>
--    che friend-live-<profile_id>).
-- ---------------------------------------------------------------------
drop policy if exists "crew_live_send" on realtime.messages;
drop policy if exists "crew_live_receive" on realtime.messages;
drop policy if exists "friend_live_send" on realtime.messages;
drop policy if exists "friend_live_receive" on realtime.messages;

create policy "drivers_live_send" on realtime.messages
  for insert
  to authenticated
  with check (realtime.topic() = 'drivers-live');

create policy "drivers_live_receive" on realtime.messages
  for select
  to authenticated
  using (realtime.topic() = 'drivers-live');

-- ---------------------------------------------------------------------
-- 4. crew_reports -> community_reports: segnalazioni Velox/Pattuglia
--    visibili e inviabili da/a chiunque, non più ristrette alla crew.
--    Le vecchie policy referenziano crew_members: vanno droppate prima
--    di droppare quella tabella (step 6).
-- ---------------------------------------------------------------------
drop policy if exists "crew_reports_select_crew_member" on public.crew_reports;
drop policy if exists "crew_reports_insert_crew_member" on public.crew_reports;

alter table public.crew_reports rename to community_reports;
alter table public.community_reports drop column crew_id;

drop index if exists idx_crew_reports_crew_recent;
create index idx_community_reports_recent on public.community_reports(created_at desc);

create policy "community_reports_select_all" on public.community_reports
  for select using (true);

create policy "community_reports_insert_self" on public.community_reports
  for insert with check (auth.uid() = reporter_id);

-- ---------------------------------------------------------------------
-- 5. Territory/leaderboard: ridefinisci le RPC "language sql"/plpgsql
--    che referenziano crew_id PRIMA di droppare profiles.crew_id
--    (territory_cells_near è "language sql" ed è quindi
--    dependency-tracked su quella colonna: senza questo passaggio,
--    ALTER TABLE profiles DROP COLUMN crew_id fallirebbe).
-- ---------------------------------------------------------------------
drop function if exists public.territory_cells_near(int, int, int, int);

create or replace function public.territory_cells_near(
  p_q int, p_r int, p_cols int, p_rows int
) returns table (q int, r int, owner_id uuid, claimed_at timestamptz, drive_score smallint)
language sql stable as $$
  select tc.q, tc.r, tc.owner_id, tc.claimed_at, tc.drive_score
  from public.territory_cells tc
  where tc.q between p_q - p_cols and p_q + p_cols
    and tc.r between p_r - p_rows and p_r + p_rows
    and tc.claimed_at >= now() - (public.territory_decay_days() || ' days')::interval;
$$;

grant execute on function public.territory_cells_near(int, int, int, int) to authenticated;

drop function if exists public.territory_standings(text, uuid, int, int);

create or replace function public.territory_standings(
  p_period_days int default 30,
  p_limit int default 50
) returns table (
  profile_id uuid,
  username text,
  display_name text,
  avatar_url text,
  cell_count bigint,
  stolen bigint,
  growth bigint,
  decline bigint
)
language plpgsql stable as $$
declare
  v_window_start timestamptz := now() - (p_period_days || ' days')::interval;
begin
  return query
    select p.id, p.username, p.display_name, p.avatar_url,
      owned.cell_count,
      coalesce(stolen_log.n, 0),
      coalesce(growth_log.n, 0),
      coalesce(decline_log.n, 0)
    from public.profiles p
    join lateral (
      select count(*) cell_count from public.territory_cells tc where tc.owner_id = p.id
    ) owned on true
    left join lateral (
      select count(*) n from public.territory_claim_log l
      where l.claimant_id = p.id and l.previous_owner_id is not null and l.claimed_at >= v_window_start
    ) stolen_log on true
    left join lateral (
      select count(*) n from public.territory_claim_log l
      where l.claimant_id = p.id and l.claimed_at >= v_window_start
    ) growth_log on true
    left join lateral (
      select count(*) n from public.territory_claim_log l
      where l.previous_owner_id = p.id and l.claimed_at >= v_window_start
    ) decline_log on true
    where owned.cell_count > 0
    order by owned.cell_count desc
    limit p_limit;
end;
$$;

grant execute on function public.territory_standings(int, int) to authenticated;

drop function if exists public.leaderboard_global(text, text, int, uuid);

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
    else null
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
        coalesce((
          select max(t.max_speed_kmh) from public.trips t
          where t.driver_id = p.id and t.status = 'completed'
        ), 0) as m_speed
      from public.profiles p
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
    where p_period = 'all' or r.m_selected > 0
    order by r.m_selected desc
    limit p_limit;
end;
$$;

grant execute on function public.leaderboard_global(text, text, int) to authenticated;

-- ---------------------------------------------------------------------
-- 6. Mission engine: rimuovi il fan-out verso crew_progress/crew_missions
--    e il gate crew_only dal motore di progresso (plpgsql: non è
--    dependency-tracked sulle colonne/tabelle crew, ma va comunque
--    aggiornato prima che quelle tabelle spariscano, altrimenti la
--    prossima chiamata runtime fallirebbe).
-- ---------------------------------------------------------------------
create or replace function public._record_mission_event_for(
  p_profile_id uuid,
  p_event_type text,
  p_event_payload jsonb,
  p_idempotency_key text
) returns void
language plpgsql security definer as $$
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
$$;

-- generate_daily_missions / generate_weekly_missions / generate_seasonal_missions
-- copiano crew_only da mission_templates a missions: quella colonna sparisce
-- da entrambe le tabelle più sotto, quindi vanno riscritte senza.
create or replace function public.generate_daily_missions() returns int
language plpgsql security definer as $$
declare
  v_count int := 0;
  v_template public.mission_templates;
  v_period text := to_char(now(), 'YYYYMMDD');
  v_day_start timestamptz := date_trunc('day', now());
begin
  for v_template in select * from public.mission_templates where type = 'daily' and active loop
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
$$;

create or replace function public.generate_weekly_missions() returns int
language plpgsql security definer as $$
declare
  v_count int := 0;
  v_template public.mission_templates;
  v_period text := to_char(now(), 'IYYY_IW');
  v_week_start timestamptz := date_trunc('week', now());
begin
  for v_template in select * from public.mission_templates where type = 'weekly' and active loop
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
      v_week_start, v_week_start + interval '7 days' - interval '1 second'
    )
    on conflict (code) do nothing;

    if found then
      v_count := v_count + 1;
    end if;
  end loop;
  return v_count;
end;
$$;

create or replace function public.generate_seasonal_missions() returns int
language plpgsql security definer as $$
declare
  v_count int := 0;
  v_template public.mission_templates;
  v_season public.season;
begin
  select * into v_season from public.season
    where starts_at <= now() and ends_at >= now()
    order by starts_at desc limit 1;

  if v_season is null then
    raise exception 'Nessuna stagione attiva: crea una riga in season prima di generare le missioni stagionali';
  end if;

  for v_template in select * from public.mission_templates where type = 'seasonal' and active loop
    insert into public.missions (
      code, title, description, type, target_value, target_metric, xp_reward, rep_reward,
      icon, difficulty, reward_badges, reward_titles, reward_profile_items, reward_avatar_frame,
      hidden, secret, repeatable, season_id, template_id, starts_at, ends_at
    )
    values (
      v_template.code || '_' || v_season.code, v_template.title, v_template.description, v_template.type,
      v_template.target_value, v_template.target_metric, v_template.xp_reward, v_template.rep_reward,
      v_template.icon, v_template.difficulty, v_template.reward_badges, v_template.reward_titles,
      v_template.reward_profile_items, v_template.reward_avatar_frame, v_template.hidden,
      v_template.secret, v_template.repeatable, v_season.id, v_template.id,
      v_season.starts_at, v_season.ends_at
    )
    on conflict (code) do nothing;

    if found then
      v_count := v_count + 1;
    end if;
  end loop;
  return v_count;
end;
$$;

-- ---------------------------------------------------------------------
-- 7. Notifiche: i 6 tipi crew_* smettono di essere generati (le funzioni
--    trigger sono droppate insieme a crew_members più sotto, i loro
--    trigger sono owned dalla tabella e spariscono con essa).
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- 8. Drop tabelle crew, ordine figlio -> genitore (nessun CASCADE
--    necessario con questo ordine).
-- ---------------------------------------------------------------------
drop table if exists public.crew_disband_votes;
drop table if exists public.crew_progress;
drop table if exists public.crew_missions;
drop table if exists public.chat_messages;
drop table if exists public.crew_members;

drop function if exists public.notify_on_crew_join();
drop function if exists public.notify_on_crew_role_change();
drop function if exists public.notify_on_crew_membership_removed();

-- events.crew_id e profiles.crew_id referenziano crews: vanno rimossi
-- prima di poter droppare la tabella senza CASCADE.
alter table public.events drop column if exists crew_id;
alter table public.profiles drop constraint if exists fk_profiles_crew;
alter table public.profiles drop column if exists crew_id;

drop table if exists public.crews;

-- ---------------------------------------------------------------------
-- 9. Drop tabella friendships (le funzioni che la referenziavano sono
--    già state droppate allo step 2).
-- ---------------------------------------------------------------------
drop table if exists public.friendships;

-- ---------------------------------------------------------------------
-- 10. missions / mission_templates: rimuovi crew_only e il tipo 'crew'.
-- ---------------------------------------------------------------------
alter table public.missions drop column if exists crew_only;
alter table public.missions drop constraint if exists missions_type_check;
alter table public.missions add constraint missions_type_check
  check (type in ('daily','weekly','seasonal','event','secret'));

alter table public.mission_templates drop column if exists crew_only;
alter table public.mission_templates drop constraint if exists mission_templates_type_check;
alter table public.mission_templates add constraint mission_templates_type_check
  check (type in ('daily','weekly','seasonal','event','secret'));
