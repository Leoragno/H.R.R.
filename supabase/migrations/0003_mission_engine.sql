-- =====================================================================
-- HRR — Mission Engine (Fase 5): missioni dinamiche, event-driven,
-- generator idempotente, reward ledger estendibile, achievement, crew.
-- Estende (ALTER) le tabelle già esistenti in 0001_init.sql — non le
-- ricrea. Segue le convenzioni di 0001/0002: security definer per ogni
-- funzione che tocca l'economy, mai fidarsi di valori calcolati dal
-- client, xp_events resta l'unico punto che muta profiles.xp/rep/level.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Helper condiviso: nessuna tabella nel progetto aveva ancora un trigger
-- riutilizzabile per updated_at (veniva impostato a mano in apply_xp_event).
-- ---------------------------------------------------------------------
create or replace function public.set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- =====================================================================
-- NUOVE TABELLE (create prima delle ALTER che le referenziano via FK)
-- =====================================================================

-- ---------------------------------------------------------------------
-- SEASON — nome singolare intenzionale (richiesto esplicitamente così
-- dall'utente, anche se rompe la convenzione plurale delle altre tabelle).
-- ---------------------------------------------------------------------
create table public.season (
  id uuid primary key default uuid_generate_v4(),
  code text unique not null,
  name text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  pass_config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- MISSION TEMPLATES — sorgente del generatore. Aggiungere una missione
-- "senza aggiornare l'app" = inserire una riga qui (o direttamente in
-- missions per una one-off). Le secret vivono qui con secret=true e
-- vengono seminate come righe missions permanenti a fine file (non sono
-- periodiche, quindi non passano dal generatore daily/weekly/seasonal).
-- ---------------------------------------------------------------------
create table public.mission_templates (
  id uuid primary key default uuid_generate_v4(),
  code text unique not null,
  title text not null,
  description text,
  type text not null check (type in ('daily','weekly','seasonal','crew','event','secret')),
  difficulty text not null default 'normal' check (difficulty in ('easy','normal','hard','elite')),
  target_value numeric not null,
  target_metric text not null, -- vedi core/events/mission_event.dart per i valori validi
  xp_reward int not null default 0,
  rep_reward int not null default 0,
  icon text not null default 'target', -- chiave logica, mappata a IconData lato Flutter
  reward_badges uuid[] not null default '{}',
  reward_titles text[] not null default '{}',
  reward_profile_items jsonb not null default '{}'::jsonb, -- es. {"glow":"cyan_pulse","mission_points":50}
  reward_avatar_frame text,
  hidden boolean not null default false,
  secret boolean not null default false,
  repeatable boolean not null default false,
  crew_only boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- =====================================================================
-- ALTER TABELLE ESISTENTI (0001_init.sql)
-- =====================================================================

-- ---------------------------------------------------------------------
-- MISSIONS — da catalogo statico daily/weekly/crew/event a istanza
-- generata dinamicamente, con supporto seasonal/secret e reward estesi.
-- ---------------------------------------------------------------------
alter table public.missions
  add column icon text not null default 'target',
  add column difficulty text not null default 'normal' check (difficulty in ('easy','normal','hard','elite')),
  add column reward_badges uuid[] not null default '{}',
  add column reward_titles text[] not null default '{}',
  add column reward_profile_items jsonb not null default '{}'::jsonb,
  add column reward_avatar_frame text,
  add column hidden boolean not null default false,
  add column secret boolean not null default false,
  add column repeatable boolean not null default false,
  add column season_id uuid references public.season(id) on delete set null,
  add column event_id uuid references public.events(id) on delete set null,
  add column crew_only boolean not null default false,
  add column template_id uuid references public.mission_templates(id) on delete set null,
  add column updated_at timestamptz not null default now();

alter table public.missions drop constraint missions_type_check;
alter table public.missions add constraint missions_type_check
  check (type in ('daily','weekly','seasonal','crew','event','secret'));

create trigger trg_missions_updated_at before update on public.missions
  for each row execute function public.set_updated_at();

create index idx_missions_active on public.missions(type, starts_at, ends_at);
create index idx_missions_target_metric on public.missions(target_metric);

-- ---------------------------------------------------------------------
-- MISSION_PROGRESS — current_value/completed restano qui (fatto
-- runtime per-utente, non duplicato sul catalogo missions). La RLS
-- self-writable di 0001 è un gap rispetto al pattern server-authority
-- del resto dell'app (vedi complete_trip in 0002): da qui in poi ogni
-- scrittura passa solo da record_mission_event()/claim_mission().
-- ---------------------------------------------------------------------
alter table public.mission_progress
  add column updated_at timestamptz not null default now();

drop policy "mission_progress_update_self" on public.mission_progress;
drop policy "mission_progress_insert_self" on public.mission_progress;

create trigger trg_mission_progress_updated_at before update on public.mission_progress
  for each row execute function public.set_updated_at();

create index idx_mission_progress_mission on public.mission_progress(mission_id);

-- =====================================================================
-- ALTRE NUOVE TABELLE
-- =====================================================================

-- ---------------------------------------------------------------------
-- MISSION_EVENT_LOG — ledger di ogni evento in ingresso (bus lato
-- client, replay offline compreso). idempotency_key è la chiave di
-- dedup: un insert che va in conflitto = evento già processato, la RPC
-- ritorna senza rifare nulla. Rende il replay offline exactly-once.
-- ---------------------------------------------------------------------
create table public.mission_event_log (
  id uuid primary key default uuid_generate_v4(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null,
  event_payload jsonb not null default '{}'::jsonb,
  idempotency_key text not null unique,
  processed_at timestamptz not null default now()
);

create index idx_mission_event_log_profile on public.mission_event_log(profile_id, processed_at desc);

-- ---------------------------------------------------------------------
-- MISSION_CLAIMS — un rigo per riscatto (audit). unique(profile_id,
-- mission_id) impedisce il doppio riscatto della stessa istanza a
-- prescindere dalla idempotency_key usata (retry con chiave diversa
-- non bypassa il vincolo); le missioni ripetibili tornano riscattabili
-- tramite una nuova istanza generata dal periodo successivo, non
-- resettando questa riga.
-- ---------------------------------------------------------------------
create table public.mission_claims (
  id uuid primary key default uuid_generate_v4(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  mission_id uuid not null references public.missions(id) on delete cascade,
  idempotency_key text not null unique,
  claimed_at timestamptz not null default now(),
  unique (profile_id, mission_id)
);

create index idx_mission_claims_profile on public.mission_claims(profile_id, claimed_at desc);

-- ---------------------------------------------------------------------
-- MISSION_REWARDS — ledger normalizzato, un rigo per ogni reward item
-- assegnato da un claim. Aggiungere un nuovo tipo di ricompensa (es.
-- "glow") non richiede mai un alter table, solo un nuovo reward_type.
-- ---------------------------------------------------------------------
create table public.mission_rewards (
  id uuid primary key default uuid_generate_v4(),
  claim_id uuid not null references public.mission_claims(id) on delete cascade,
  reward_type text not null check (reward_type in
    ('rep','xp','badge','title','avatar_frame','glow','profile_skin','icon','mission_points')),
  reward_value jsonb not null default '{}'::jsonb,
  granted_at timestamptz not null default now()
);

create index idx_mission_rewards_claim on public.mission_rewards(claim_id);

-- ---------------------------------------------------------------------
-- ACHIEVEMENTS — catalogo permanente, mirror di badges/profile_badges.
-- target_metric/target_value leggono aggregati già presenti su profiles
-- (total_km, total_trips, rep, level) o vengono estesi in futuro con
-- altri aggregati quando esisteranno le feature che li producono.
-- ---------------------------------------------------------------------
create table public.achievements (
  id uuid primary key default uuid_generate_v4(),
  code text unique not null,
  name text not null,
  description text,
  icon text not null default 'trophy',
  rarity text not null default 'common' check (rarity in ('common','uncommon','rare','epic','legendary')),
  target_metric text not null,
  target_value numeric not null,
  reward_rep int not null default 0,
  reward_xp int not null default 0,
  reward_badges uuid[] not null default '{}',
  reward_titles text[] not null default '{}',
  created_at timestamptz not null default now()
);

-- Permanente per costruzione: la primary key impedisce di riottenerlo.
create table public.user_achievements (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  achievement_id uuid not null references public.achievements(id) on delete cascade,
  earned_at timestamptz not null default now(),
  primary key (profile_id, achievement_id)
);

create index idx_user_achievements_profile on public.user_achievements(profile_id);

-- ---------------------------------------------------------------------
-- CREW MISSIONS / CREW PROGRESS — istanza crew-scoped di una missione
-- + ledger di contribuzione per membro. current_value è la somma delle
-- contribution, ricalcolata dentro record_mission_event().
-- ---------------------------------------------------------------------
create table public.crew_missions (
  id uuid primary key default uuid_generate_v4(),
  crew_id uuid not null references public.crews(id) on delete cascade,
  mission_id uuid not null references public.missions(id) on delete cascade,
  target_value numeric not null,
  current_value numeric not null default 0,
  starts_at timestamptz,
  ends_at timestamptz,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (crew_id, mission_id)
);

create trigger trg_crew_missions_updated_at before update on public.crew_missions
  for each row execute function public.set_updated_at();

create index idx_crew_missions_crew on public.crew_missions(crew_id);

create table public.crew_progress (
  crew_id uuid not null references public.crews(id) on delete cascade,
  mission_id uuid not null references public.crew_missions(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  contribution numeric not null default 0,
  updated_at timestamptz not null default now(),
  primary key (crew_id, mission_id, profile_id)
);

create trigger trg_crew_progress_updated_at before update on public.crew_progress
  for each row execute function public.set_updated_at();

create index idx_crew_progress_crew_mission on public.crew_progress(crew_id, mission_id);

-- =====================================================================
-- ROW LEVEL SECURITY
-- =====================================================================
alter table public.season enable row level security;
alter table public.mission_templates enable row level security;
alter table public.mission_event_log enable row level security;
alter table public.mission_claims enable row level security;
alter table public.mission_rewards enable row level security;
alter table public.achievements enable row level security;
alter table public.user_achievements enable row level security;
alter table public.crew_missions enable row level security;
alter table public.crew_progress enable row level security;

-- SEASON: catalogo pubblico.
create policy "season_select_all" on public.season for select using (true);

-- MISSION_TEMPLATES: MAI pubblico — le righe secret contengono titolo/
-- descrizione del segreto in chiaro. Solo le funzioni security definer
-- (generatori, get_secret_mission_slot_count) le leggono, bypassando RLS.
-- Nessuna policy select per authenticated = accesso negato di default.

-- MISSION_EVENT_LOG / MISSION_CLAIMS / MISSION_REWARDS / USER_ACHIEVEMENTS:
-- solo lettura self, nessuna scrittura client-side (solo via RPC).
create policy "mission_event_log_select_self" on public.mission_event_log
  for select using (auth.uid() = profile_id);
create policy "mission_claims_select_self" on public.mission_claims
  for select using (auth.uid() = profile_id);
create policy "mission_rewards_select_self" on public.mission_rewards
  for select using (auth.uid() in (
    select profile_id from public.mission_claims where id = mission_rewards.claim_id
  ));
create policy "user_achievements_select_self" on public.user_achievements
  for select using (auth.uid() = profile_id);

-- ACHIEVEMENTS: catalogo pubblico (a differenza delle secret missions,
-- gli achievement non sono nascosti — l'utente li vede come lista
-- ottenuti/da ottenere).
create policy "achievements_select_all" on public.achievements for select using (true);

-- CREW_MISSIONS: pubblico come le altre tabelle crew-visible; scrittura
-- riservata a owner/officer della crew (stesso pattern di crew_members).
create policy "crew_missions_select_all" on public.crew_missions for select using (true);
create policy "crew_missions_insert_officer" on public.crew_missions for insert
  with check (auth.uid() in (
    select profile_id from public.crew_members
    where crew_id = crew_missions.crew_id and role in ('owner','officer')
  ));

-- CREW_PROGRESS: solo membri della crew, nessuna scrittura client (solo
-- via record_mission_event).
create policy "crew_progress_select_crew_member" on public.crew_progress
  for select using (auth.uid() in (
    select profile_id from public.crew_members where crew_id = crew_progress.crew_id
  ));

-- MISSIONS: la select pubblica esistente ora esclude le missioni segrete
-- finché il chiamante non le ha completate — nascoste a livello di dato,
-- non solo di UI.
drop policy "missions_select_all" on public.missions;
create policy "missions_select_all" on public.missions for select using (
  not secret or exists (
    select 1 from public.mission_progress mp
    where mp.mission_id = missions.id and mp.profile_id = auth.uid() and mp.completed
  )
);

-- =====================================================================
-- FUNZIONI (tutte security definer, mirror di complete_trip in 0002)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Helper interno: unico punto oltre a complete_trip che scrive
-- xp_events, riusato da claim_mission ed evaluate_achievements per
-- evitare la stessa logica duplicata in due posti. Non concesso a
-- PUBLIC: non richiamabile direttamente via client .rpc().
-- ---------------------------------------------------------------------
create or replace function public._grant_xp_rep(
  p_profile_id uuid, p_xp int, p_rep int, p_source text, p_source_id uuid
) returns void
language plpgsql security definer as $$
begin
  if coalesce(p_xp, 0) = 0 and coalesce(p_rep, 0) = 0 then
    return;
  end if;
  insert into public.xp_events (profile_id, source, source_id, xp_delta, rep_delta)
  values (p_profile_id, p_source, p_source_id, coalesce(p_xp, 0), coalesce(p_rep, 0));
end;
$$;

revoke execute on function public._grant_xp_rep(uuid, int, int, text, uuid) from public;

-- ---------------------------------------------------------------------
-- get_secret_mission_slot_count — numero di missioni segrete attive nel
-- pool, senza esporre quali siano (usato dalla UI per il conteggio
-- "SBLOCCATE n / N" senza leggere mission_templates direttamente).
-- ---------------------------------------------------------------------
create or replace function public.get_secret_mission_slot_count() returns int
language sql security definer stable as $$
  select count(*)::int from public.mission_templates where secret and active;
$$;

grant execute on function public.get_secret_mission_slot_count() to authenticated;

-- ---------------------------------------------------------------------
-- evaluate_achievements — valuta gli achievement non ancora ottenuti
-- contro gli aggregati già autorevoli su profiles (total_km, total_trips,
-- rep, level). Auto-assegnati al superamento soglia: gli achievement
-- sono permanenti/non ripetibili, non hanno un pulsante RISCATTA come
-- le missioni (la primary key di user_achievements li rende idempotenti).
-- ---------------------------------------------------------------------
create or replace function public.evaluate_achievements(p_profile_id uuid) returns void
language plpgsql security definer as $$
declare
  v_profile public.profiles;
  v_achievement public.achievements;
  v_current numeric;
begin
  select * into v_profile from public.profiles where id = p_profile_id;
  if v_profile is null then
    return;
  end if;

  for v_achievement in
    select a.* from public.achievements a
    where not exists (
      select 1 from public.user_achievements ua
      where ua.profile_id = p_profile_id and ua.achievement_id = a.id
    )
  loop
    v_current := case v_achievement.target_metric
      when 'total_km' then v_profile.total_km
      when 'total_trips' then v_profile.total_trips
      when 'rep' then v_profile.rep
      when 'level' then v_profile.level
      else null
    end;

    if v_current is not null and v_current >= v_achievement.target_value then
      insert into public.user_achievements (profile_id, achievement_id)
        values (p_profile_id, v_achievement.id)
        on conflict do nothing;

      perform public._grant_xp_rep(
        p_profile_id, v_achievement.reward_xp, v_achievement.reward_rep, 'achievement', v_achievement.id
      );

      if v_achievement.reward_badges is not null and array_length(v_achievement.reward_badges, 1) > 0 then
        insert into public.profile_badges (profile_id, badge_id)
        select p_profile_id, b from unnest(v_achievement.reward_badges) as b
        on conflict do nothing;
      end if;

      insert into public.notifications (profile_id, type, title, body, data)
        values (p_profile_id, 'achievement_unlocked', 'Achievement sbloccato', v_achievement.name,
          jsonb_build_object('achievement_id', v_achievement.id));
    end if;
  end loop;
end;
$$;

revoke execute on function public.evaluate_achievements(uuid) from public;

-- ---------------------------------------------------------------------
-- record_mission_event — unico entrypoint del progress engine. Chiamato
-- dal bus lato client (online o in replay dalla coda offline) per ogni
-- evento di dominio. Dedup via mission_event_log; incrementa solo
-- current_value lato server da fatti grezzi dell'evento (mai un
-- "progress amount" precalcolato dal client); propaga a crew_progress/
-- crew_missions quando la missione è crew-scoped; notifica al 100% e
-- all'80%; rivaluta gli achievement a fine funzione.
-- ---------------------------------------------------------------------
create or replace function public.record_mission_event(
  p_event_type text,
  p_event_payload jsonb,
  p_idempotency_key text
) returns void
language plpgsql security definer as $$
declare
  v_profile_id uuid := auth.uid();
  v_rows int;
  v_crew_id uuid;
  v_increment numeric;
  v_mission record;
  v_progress public.mission_progress;
  v_new_value numeric;
begin
  if v_profile_id is null then
    raise exception 'Non autenticato';
  end if;

  insert into public.mission_event_log (profile_id, event_type, event_payload, idempotency_key)
  values (v_profile_id, p_event_type, coalesce(p_event_payload, '{}'::jsonb), p_idempotency_key)
  on conflict (idempotency_key) do nothing;

  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    return; -- già processato: replay offline idempotente, no-op.
  end if;

  v_increment := coalesce((p_event_payload->>'value')::numeric, 1);
  select crew_id into v_crew_id from public.profiles where id = v_profile_id;

  -- Missioni personali (daily/weekly/seasonal/secret/event) che
  -- ascoltano questo tipo di evento e sono nella finestra attiva.
  for v_mission in
    select m.* from public.missions m
    where m.target_metric = p_event_type
      and (m.starts_at is null or m.starts_at <= now())
      and (m.ends_at is null or m.ends_at >= now())
      and (not m.crew_only or v_crew_id is not null)
  loop
    insert into public.mission_progress (profile_id, mission_id, current_value)
    values (v_profile_id, v_mission.id, 0)
    on conflict (profile_id, mission_id) do nothing;

    select * into v_progress from public.mission_progress
      where profile_id = v_profile_id and mission_id = v_mission.id for update;

    if not v_progress.completed then
      v_new_value := least(v_mission.target_value, v_progress.current_value + v_increment);

      update public.mission_progress set
        current_value = v_new_value,
        completed = v_new_value >= v_mission.target_value,
        completed_at = case when v_new_value >= v_mission.target_value then now() else null end
      where profile_id = v_profile_id and mission_id = v_mission.id;

      if v_new_value >= v_mission.target_value then
        insert into public.notifications (profile_id, type, title, body, data)
          values (v_profile_id, 'mission_complete', 'Missione completata!', v_mission.title,
            jsonb_build_object('mission_id', v_mission.id));
      elsif v_progress.current_value < v_mission.target_value * 0.8
            and v_new_value >= v_mission.target_value * 0.8 then
        insert into public.notifications (profile_id, type, title, body, data)
          values (v_profile_id, 'mission_almost_done', 'Missione quasi completata', v_mission.title,
            jsonb_build_object('mission_id', v_mission.id));
      end if;
    end if;
  end loop;

  -- Fan-out crew: stesso evento contribuisce anche alle crew_missions
  -- attive della crew del profilo, se presente. Nessun emitter separato.
  if v_crew_id is not null then
    for v_mission in
      select cm.* from public.crew_missions cm
      join public.missions m on m.id = cm.mission_id
      where cm.crew_id = v_crew_id
        and m.target_metric = p_event_type
        and (cm.ends_at is null or cm.ends_at >= now())
    loop
      insert into public.crew_progress (crew_id, mission_id, profile_id, contribution)
      values (v_crew_id, v_mission.id, v_profile_id, v_increment)
      on conflict (crew_id, mission_id, profile_id)
        do update set contribution = public.crew_progress.contribution + excluded.contribution;

      update public.crew_missions
        set current_value = (
          select coalesce(sum(contribution), 0) from public.crew_progress
          where crew_id = v_crew_id and mission_id = v_mission.id
        )
        where id = v_mission.id;
    end loop;
  end if;

  perform public.evaluate_achievements(v_profile_id);
end;
$$;

grant execute on function public.record_mission_event(text, jsonb, text) to authenticated;

-- ---------------------------------------------------------------------
-- claim_mission — riscatta una missione completata. Un solo claim per
-- (profile_id, mission_id) grazie al vincolo unique su mission_claims;
-- assegna un mission_rewards per ogni reward non nullo; REP/XP passano
-- da _grant_xp_rep (quindi da xp_events, mai da un update diretto a
-- profiles); badge assegnati anche in profile_badges per compatibilità
-- con il catalogo badge esistente.
-- ---------------------------------------------------------------------
create or replace function public.claim_mission(p_mission_id uuid, p_idempotency_key text)
returns public.mission_claims
language plpgsql security definer as $$
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
$$;

grant execute on function public.claim_mission(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- Generatori — completi, idempotenti (on conflict do nothing sul code
-- period-based), richiamabili via RPC/SQL editor. NESSUN pg_cron/
-- scheduling qui per scelta esplicita: lo scheduling è un layer separato
-- da decidere in seguito (pg_cron / Edge Function / GitHub Actions).
-- mission_progress non viene pre-creata per tutti gli utenti: nasce
-- lazy alla prima insert...on conflict do nothing dentro
-- record_mission_event, evitando un burst O(utenti × missioni).
-- ---------------------------------------------------------------------
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
      hidden, secret, repeatable, crew_only, template_id, starts_at, ends_at
    )
    values (
      v_template.code || '_' || v_period, v_template.title, v_template.description, v_template.type,
      v_template.target_value, v_template.target_metric, v_template.xp_reward, v_template.rep_reward,
      v_template.icon, v_template.difficulty, v_template.reward_badges, v_template.reward_titles,
      v_template.reward_profile_items, v_template.reward_avatar_frame, v_template.hidden,
      v_template.secret, v_template.repeatable, v_template.crew_only, v_template.id,
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
      hidden, secret, repeatable, crew_only, template_id, starts_at, ends_at
    )
    values (
      v_template.code || '_' || v_period, v_template.title, v_template.description, v_template.type,
      v_template.target_value, v_template.target_metric, v_template.xp_reward, v_template.rep_reward,
      v_template.icon, v_template.difficulty, v_template.reward_badges, v_template.reward_titles,
      v_template.reward_profile_items, v_template.reward_avatar_frame, v_template.hidden,
      v_template.secret, v_template.repeatable, v_template.crew_only, v_template.id,
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
      hidden, secret, repeatable, crew_only, season_id, template_id, starts_at, ends_at
    )
    values (
      v_template.code || '_' || v_season.code, v_template.title, v_template.description, v_template.type,
      v_template.target_value, v_template.target_metric, v_template.xp_reward, v_template.rep_reward,
      v_template.icon, v_template.difficulty, v_template.reward_badges, v_template.reward_titles,
      v_template.reward_profile_items, v_template.reward_avatar_frame, v_template.hidden,
      v_template.secret, v_template.repeatable, v_template.crew_only, v_season.id, v_template.id,
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

-- Grant ad authenticated per poterle richiamare facilmente via RPC/SQL
-- editor senza service role, come richiesto. Da restringere a
-- service_role quando verrà collegato lo scheduling reale.
grant execute on function public.generate_daily_missions() to authenticated;
grant execute on function public.generate_weekly_missions() to authenticated;
grant execute on function public.generate_seasonal_missions() to authenticated;

-- =====================================================================
-- REALTIME — mission_progress mancava dalla pubblicazione: senza questo
-- lo stream .stream() lato Flutter sulla progress bar delle missioni non
-- riceve mai un aggiornamento live dopo record_mission_event/claim.
-- =====================================================================
alter publication supabase_realtime add table public.mission_progress;

-- =====================================================================
-- SEED — season attiva + template di partenza (daily/weekly/seasonal +
-- le 5 secret nominate dall'utente) cosi il sistema è testabile subito
-- dopo la migration, senza aspettare un inserimento manuale.
-- =====================================================================

insert into public.season (code, name, starts_at, ends_at) values
  ('season_3', 'Neon Horizon', now(), now() + interval '12 days')
on conflict (code) do nothing;

insert into public.mission_templates
  (code, title, description, type, target_value, target_metric, xp_reward, rep_reward, icon, difficulty, repeatable) values
  ('daily_km_15', 'Percorri 15 km', 'Guida per almeno 15 km oggi', 'daily', 15, 'trip_completed', 40, 80, 'route', 'normal', true),
  ('daily_smooth_drive', 'Guida fluida', 'Completa un viaggio senza frenate brusche', 'daily', 1, 'trip_completed', 20, 60, 'waves', 'easy', true),
  ('daily_start_drive', 'Avvia un viaggio', 'Premi START DRIVE almeno una volta oggi', 'daily', 1, 'trip_started', 10, 20, 'play_circle', 'easy', true)
on conflict (code) do nothing;

insert into public.mission_templates
  (code, title, description, type, target_value, target_metric, xp_reward, rep_reward, icon, difficulty, repeatable) values
  ('weekly_km_100', '100 km questa settimana', 'Accumula 100 km totali entro domenica', 'weekly', 100, 'trip_completed', 150, 300, 'route', 'normal', true),
  ('weekly_trips_5', '5 viaggi completati', 'Completa 5 viaggi in questa settimana', 'weekly', 5, 'trip_started', 0, 150, 'flag_circle', 'normal', true)
on conflict (code) do nothing;

insert into public.mission_templates
  (code, title, description, type, target_value, target_metric, xp_reward, rep_reward, icon, difficulty, repeatable) values
  ('season_level_push', 'Raggiungi Livello 20 stagionale', 'Sali di livello nel Battle Pass di stagione', 'seasonal', 20, 'trip_completed', 0, 250, 'military_tech', 'hard', false)
on conflict (code) do nothing;

-- Secret — sempre nascoste (RLS su missions + niente select pubblica su
-- mission_templates), ricompense alte come richiesto.
insert into public.mission_templates
  (code, title, description, type, target_value, target_metric, xp_reward, rep_reward, icon, difficulty, secret, hidden, repeatable) values
  ('secret_night_owl', 'Night Owl', 'Primo viaggio dopo mezzanotte', 'secret', 1, 'trip_started', 300, 500, 'moon', 'elite', true, true, false),
  ('secret_mountain_explorer', 'Mountain Explorer', 'Visita una montagna', 'secret', 1, 'poi_discovered', 350, 500, 'mountain', 'elite', true, true, false),
  ('secret_ferrari_hunter', 'Ferrari Hunter', 'Trova una Ferrari', 'secret', 1, 'car_spotted', 400, 600, 'search', 'elite', true, true, false),
  ('secret_road_legend', 'Road Legend', 'Percorri 10000 km in totale', 'secret', 10000, 'trip_completed', 1000, 2000, 'trophy', 'elite', true, true, false),
  ('secret_collector', 'Collector', 'Avvista 100 auto differenti', 'secret', 100, 'car_spotted', 800, 1200, 'collections', 'elite', true, true, false)
on conflict (code) do nothing;

-- Le secret sono un pool fisso sempre attivo, non periodico: seminate
-- direttamente come missions permanenti (starts_at=now, ends_at=null),
-- non passano dai generatori daily/weekly/seasonal.
insert into public.missions (
  code, title, description, type, target_value, target_metric, xp_reward, rep_reward,
  icon, difficulty, secret, hidden, repeatable, template_id, starts_at, ends_at
)
select
  code, title, description, type, target_value, target_metric, xp_reward, rep_reward,
  icon, difficulty, secret, hidden, repeatable, id, now(), null
from public.mission_templates where secret
on conflict (code) do nothing;

-- Missioni daily/weekly/seasonal di partenza generate subito, cosi
-- l'app ha dati reali appena la migration è applicata.
select public.generate_daily_missions();
select public.generate_weekly_missions();
select public.generate_seasonal_missions();

-- Achievement di esempio (permanenti, non ripetibili) sugli aggregati
-- già presenti su profiles.
insert into public.achievements (code, name, description, icon, rarity, target_metric, target_value, reward_rep, reward_xp) values
  ('first_trip', 'Primo viaggio', 'Completa il tuo primo viaggio', 'flag', 'common', 'total_trips', 1, 20, 20),
  ('km_100', '100 km', 'Percorri 100 km in totale', 'route', 'common', 'total_km', 100, 50, 50),
  ('km_1000', '1000 km', 'Percorri 1000 km in totale', 'route', 'uncommon', 'total_km', 1000, 150, 150),
  ('km_10000', '10000 km', 'Percorri 10000 km in totale', 'route', 'rare', 'total_km', 10000, 500, 500),
  ('trips_100', '100 viaggi', 'Completa 100 viaggi', 'flag', 'rare', 'total_trips', 100, 400, 400)
on conflict (code) do nothing;
