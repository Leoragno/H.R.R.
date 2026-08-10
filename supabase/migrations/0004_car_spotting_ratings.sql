-- =====================================================================
-- HRR — Car Spotting: sistema di valutazione a stelle (0.5–5, mezze
-- stelle ammesse). Sostituisce like/dislike per questa feature — non
-- tocca spot_reactions (resta nello schema, semplicemente non più usata
-- da Car Spotting). Estende (ALTER) spots, crea spot_ratings. Segue le
-- convenzioni di 0001/0002/0003: security definer per ogni funzione che
-- tocca l'economy, mai fidarsi di un valore calcolato dal client.
-- =====================================================================

alter table public.spots
  add column average_rating numeric(2,1) not null default 0,
  add column rating_count int not null default 0,
  -- Posizione generale inserita a mano dall'utente (es. "Milano"), non
  -- GPS: `location` (geography) resta per una futura mappa reale, fuori
  -- scope in questo giro ("non implementare mappe avanzate").
  add column location_label text;

-- ---------------------------------------------------------------------
-- spot_ratings — un voto per (spot, utente). Nessuna policy DELETE:
-- un voto, una volta dato, si aggiorna ma non si cancella mai. Questo
-- è ciò che rende sicura l'idempotenza del reward in on_spot_rating_given
-- sotto (senza DELETE non è possibile farmare REP cancellando e
-- rivotando lo stesso spot).
-- ---------------------------------------------------------------------
create table public.spot_ratings (
  id uuid primary key default uuid_generate_v4(),
  spot_id uuid not null references public.spots(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  rating numeric(2,1) not null check (
    rating >= 0.5 and rating <= 5 and (rating * 2) = floor(rating * 2)
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (spot_id, profile_id)
);

create index idx_spot_ratings_spot on public.spot_ratings(spot_id);
create index idx_spot_ratings_profile on public.spot_ratings(profile_id);

alter table public.spot_ratings enable row level security;

-- Il voto è visibile solo a chi lo ha dato: la media aggregata su
-- spots (pubblica via spots_select_all) è l'unica cosa che gli altri
-- utenti vedono. Nessuno deve poter leggere "chi ha votato cosa".
create policy "spot_ratings_select_self" on public.spot_ratings
  for select using (auth.uid() = profile_id);

create policy "spot_ratings_insert_self" on public.spot_ratings
  for insert with check (auth.uid() = profile_id);

create policy "spot_ratings_update_self" on public.spot_ratings
  for update using (auth.uid() = profile_id);

create trigger trg_spot_ratings_updated_at
  before update on public.spot_ratings
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- Aggregazione: spots.average_rating/rating_count restano sempre
-- coerenti con spot_ratings, ricalcolati ad ogni insert/update/delete.
-- security definer perché l'utente che vota non ha (né deve avere)
-- UPDATE su spots.
-- ---------------------------------------------------------------------
create or replace function public.sync_spot_rating_aggregate() returns trigger
language plpgsql security definer as $$
declare
  v_spot_id uuid := coalesce(new.spot_id, old.spot_id);
begin
  update public.spots set
    average_rating = coalesce(
      (select round(avg(rating), 1) from public.spot_ratings where spot_id = v_spot_id), 0),
    rating_count = (select count(*) from public.spot_ratings where spot_id = v_spot_id)
  where id = v_spot_id;
  return null;
end;
$$;

create trigger trg_sync_spot_rating_aggregate
after insert or update of rating or delete on public.spot_ratings
for each row execute function public.sync_spot_rating_aggregate();

-- =====================================================================
-- Mission Engine — RatingReceived deve accreditare il PROPRIETARIO dello
-- spot, mai chi vota. record_mission_event() esistente deriva sempre il
-- profilo da auth.uid(), quindi non è utilizzabile così com'è per questo
-- caso. Si estrae il corpo esistente in una funzione interna parametrica
-- su p_profile_id (stesso identico comportamento, nessuna logica
-- duplicata) e record_mission_event diventa un thin wrapper che la
-- richiama con auth.uid() — comportamento invariato per ogni chiamante
-- esistente (trip/missions/achievements).
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
  v_crew_id uuid;
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
    return; -- già processato: replay offline / re-invio idempotente, no-op.
  end if;

  v_increment := coalesce((p_event_payload->>'value')::numeric, 1);
  select crew_id into v_crew_id from public.profiles where id = p_profile_id;

  for v_mission in
    select m.* from public.missions m
    where m.target_metric = p_event_type
      and (m.starts_at is null or m.starts_at <= now())
      and (m.ends_at is null or m.ends_at >= now())
      and (not m.crew_only or v_crew_id is not null)
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

  if v_crew_id is not null then
    for v_mission in
      select cm.* from public.crew_missions cm
      join public.missions m on m.id = cm.mission_id
      where cm.crew_id = v_crew_id
        and m.target_metric = p_event_type
        and (cm.ends_at is null or cm.ends_at >= now())
    loop
      insert into public.crew_progress (crew_id, mission_id, profile_id, contribution)
      values (v_crew_id, v_mission.id, p_profile_id, v_increment)
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

  perform public.evaluate_achievements(p_profile_id);
end;
$$;

revoke execute on function public._record_mission_event_for(uuid, text, jsonb, text) from public;

create or replace function public.record_mission_event(
  p_event_type text,
  p_event_payload jsonb,
  p_idempotency_key text
) returns void
language plpgsql security definer as $$
begin
  if auth.uid() is null then
    raise exception 'Non autenticato';
  end if;
  perform public._record_mission_event_for(auth.uid(), p_event_type, p_event_payload, p_idempotency_key);
end;
$$;

grant execute on function public.record_mission_event(text, jsonb, text) to authenticated;

-- ---------------------------------------------------------------------
-- on_spot_rating_given — unico produttore di 'rating_received'. Solo
-- AFTER INSERT (non UPDATE): modificare un voto già dato non deve mai
-- rigenerare reward per il proprietario ("non premiare la modifica
-- continua del voto"). L'idempotency key è fissa per coppia
-- (spot, votante): anche se in futuro si aprisse un path di re-insert,
-- mission_event_log deduplica comunque. REP proporzionale al voto dato
-- (round(rating): 0.5–1★→1 REP, 5★→5 REP) — il valore della community
-- si riflette nella qualità del voto ricevuto, non in un flat reward.
-- ---------------------------------------------------------------------
create or replace function public.on_spot_rating_given() returns trigger
language plpgsql security definer as $$
declare
  v_author uuid;
begin
  select author_id into v_author from public.spots where id = new.spot_id;
  if v_author is null or v_author = new.profile_id then
    return new; -- spot cancellato in concorrenza, o auto-voto: nessun reward.
  end if;

  perform public._record_mission_event_for(
    v_author,
    'rating_received',
    jsonb_build_object('rating', new.rating),
    'rating_received:' || new.spot_id || ':' || new.profile_id
  );

  perform public._grant_xp_rep(v_author, 0, round(new.rating)::int, 'rating_received', new.id);

  return new;
end;
$$;

create trigger trg_on_spot_rating_given
after insert on public.spot_ratings
for each row execute function public.on_spot_rating_given();
