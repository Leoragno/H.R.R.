-- =====================================================================
-- HRR — Notifiche "per schermata" (fase 2, dopo le notifiche generali di
-- 0001/0003/0004): Car Spotting (voto/commento ricevuto), Crew (ingresso,
-- promozione/retrocessione, uscita/espulsione, voto di scioglimento,
-- scioglimento) e Territorio (esagono rubato). Stesso principio ovunque:
-- solo il server decide se/cosa notificare, mai il client.
--
-- Approfitta anche di una lacuna pre-esistente: spots.comment_count non
-- era mai aggiornato da nessun trigger (a differenza di average_rating/
-- rating_count, sincronizzati da sync_spot_rating_aggregate in 0004) —
-- lo stesso trigger che genera la notifica di commento lo sistema.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Car Spotting: commento ricevuto (+ fix comment_count mai aggiornato).
-- ---------------------------------------------------------------------
create or replace function public.notify_on_spot_comment() returns trigger
language plpgsql security definer as $$
declare
  v_author_id uuid;
  v_commenter_username text;
begin
  update public.spots set comment_count = comment_count + 1
    where id = new.spot_id
    returning author_id into v_author_id;

  if v_author_id is not null and v_author_id <> new.author_id then
    select username into v_commenter_username from public.profiles where id = new.author_id;
    insert into public.notifications (profile_id, type, title, body, data)
      values (v_author_id, 'comment', 'Nuovo commento! 💬',
        coalesce(v_commenter_username, 'Qualcuno') || ' ha commentato il tuo spot',
        jsonb_build_object('spot_id', new.spot_id, 'comment_id', new.id));
  end if;
  return new;
end;
$$;

create trigger trg_notify_on_spot_comment
after insert on public.spot_comments
for each row execute function public.notify_on_spot_comment();

-- ---------------------------------------------------------------------
-- Car Spotting: voto ricevuto. Solo al primo voto (insert), non ad ogni
-- ri-voto (update) — rateSpot() usa upsert, quindi cambiare idea sullo
-- stesso spot non deve spammare il proprietario.
-- ---------------------------------------------------------------------
create or replace function public.notify_on_spot_rating() returns trigger
language plpgsql security definer as $$
declare
  v_author_id uuid;
  v_rater_username text;
begin
  select author_id into v_author_id from public.spots where id = new.spot_id;

  if v_author_id is not null and v_author_id <> new.profile_id then
    select username into v_rater_username from public.profiles where id = new.profile_id;
    insert into public.notifications (profile_id, type, title, body, data)
      values (v_author_id, 'rating', 'Nuovo voto! ⭐',
        coalesce(v_rater_username, 'Qualcuno') || ' ha votato il tuo spot',
        jsonb_build_object('spot_id', new.spot_id, 'rating', new.rating));
  end if;
  return new;
end;
$$;

create trigger trg_notify_on_spot_rating
after insert on public.spot_ratings
for each row execute function public.notify_on_spot_rating();

-- ---------------------------------------------------------------------
-- Crew: nuovo membro. Notifica tutti gli altri membri già presenti (non
-- chi si è appena unito).
-- ---------------------------------------------------------------------
create or replace function public.notify_on_crew_join() returns trigger
language plpgsql security definer as $$
declare
  v_crew_name text;
  v_joiner_username text;
begin
  select name into v_crew_name from public.crews where id = new.crew_id;
  select username into v_joiner_username from public.profiles where id = new.profile_id;

  insert into public.notifications (profile_id, type, title, body, data)
    select cm.profile_id, 'crew_member_joined', 'Nuovo membro! 🚗',
      coalesce(v_joiner_username, 'Qualcuno') || ' si è unito a ' || coalesce(v_crew_name, 'la crew'),
      jsonb_build_object('crew_id', new.crew_id, 'profile_id', new.profile_id)
    from public.crew_members cm
    where cm.crew_id = new.crew_id and cm.profile_id <> new.profile_id;

  return new;
end;
$$;

create trigger trg_notify_on_crew_join
after insert on public.crew_members
for each row execute function public.notify_on_crew_join();

-- ---------------------------------------------------------------------
-- Crew: cambio ruolo (promozione/retrocessione da parte del proprietario,
-- o successione automatica in crew_leave). Notifica solo l'interessato.
-- ---------------------------------------------------------------------
create or replace function public.notify_on_crew_role_change() returns trigger
language plpgsql security definer as $$
declare
  v_crew_name text;
  v_title text;
  v_body text;
begin
  if new.role = old.role then
    return new;
  end if;

  select name into v_crew_name from public.crews where id = new.crew_id;

  if new.role = 'owner' then
    v_title := 'Sei il nuovo capo! 👑';
    v_body := 'Ora guidi tu ' || coalesce(v_crew_name, 'la crew') || '.';
  elsif new.role = 'officer' then
    v_title := 'Promosso! 🎖️';
    v_body := 'Sei diventato Ufficiale in ' || coalesce(v_crew_name, 'la crew') || '.';
  else
    v_title := 'Cambio di ruolo';
    v_body := 'Ora sei Membro in ' || coalesce(v_crew_name, 'la crew') || '.';
  end if;

  insert into public.notifications (profile_id, type, title, body, data)
    values (new.profile_id, 'crew_role_changed', v_title, v_body,
      jsonb_build_object('crew_id', new.crew_id, 'role', new.role));

  return new;
end;
$$;

create trigger trg_notify_on_crew_role_change
after update of role on public.crew_members
for each row execute function public.notify_on_crew_role_change();

-- ---------------------------------------------------------------------
-- Crew: uscita volontaria o espulsione. auth.uid() = profilo rimosso →
-- uscita volontaria (notifica chi resta); altrimenti è il proprietario
-- che ha espulso qualcuno (notifica l'espulso). Se la crew stessa non
-- esiste più (cascade delete da crew_cast_disband_vote quando scioglie
-- la crew), non è né un'uscita né un'espulsione: si salta, lo
-- scioglimento ha già la sua notifica dedicata.
-- ---------------------------------------------------------------------
create or replace function public.notify_on_crew_membership_removed() returns trigger
language plpgsql security definer as $$
declare
  v_crew_name text;
  v_username text;
begin
  if not exists (select 1 from public.crews where id = old.crew_id) then
    return old;
  end if;

  select name into v_crew_name from public.crews where id = old.crew_id;

  if auth.uid() = old.profile_id then
    select username into v_username from public.profiles where id = old.profile_id;
    insert into public.notifications (profile_id, type, title, body, data)
      select cm.profile_id, 'crew_member_left', 'Qualcuno ha lasciato la crew 👋',
        coalesce(v_username, 'Un membro') || ' ha lasciato ' || coalesce(v_crew_name, 'la crew'),
        jsonb_build_object('crew_id', old.crew_id, 'profile_id', old.profile_id)
      from public.crew_members cm
      where cm.crew_id = old.crew_id;
  else
    insert into public.notifications (profile_id, type, title, body, data)
      values (old.profile_id, 'crew_kicked', 'Espulso dalla crew',
        'Sei stato rimosso da ' || coalesce(v_crew_name, 'la crew') || '.',
        jsonb_build_object('crew_id', old.crew_id));
  end if;

  return old;
end;
$$;

create trigger trg_notify_on_crew_membership_removed
after delete on public.crew_members
for each row execute function public.notify_on_crew_membership_removed();

-- ---------------------------------------------------------------------
-- Crew: voto di scioglimento avviato (solo al primo voto, per non
-- spammare ad ogni voto successivo) e scioglimento effettivo (a tutti i
-- membri, prima della delete che li rimuove — altrimenti non ci sarebbe
-- più nessuno a cui notificarlo).
-- ---------------------------------------------------------------------
create or replace function public.crew_cast_disband_vote(p_crew_id uuid)
returns table (votes_count int, members_count int, disbanded boolean)
language plpgsql security definer as $$
declare
  v_members_count int;
  v_votes_count int;
  v_crew_name text;
  v_voter_username text;
begin
  if not exists (
    select 1 from public.crew_members
    where crew_id = p_crew_id and profile_id = auth.uid()
  ) then
    raise exception 'Non sei membro di questa crew';
  end if;

  insert into public.crew_disband_votes (crew_id, profile_id)
  values (p_crew_id, auth.uid())
  on conflict (crew_id, profile_id) do nothing;

  select count(*) into v_members_count
  from public.crew_members where crew_id = p_crew_id;
  select count(*) into v_votes_count
  from public.crew_disband_votes where crew_id = p_crew_id;

  select name into v_crew_name from public.crews where id = p_crew_id;

  if v_votes_count >= v_members_count then
    insert into public.notifications (profile_id, type, title, body, data)
      select cm.profile_id, 'crew_disbanded', 'Crew sciolta 💔',
        coalesce(v_crew_name, 'La crew') || ' è stata sciolta per voto unanime.',
        jsonb_build_object('crew_id', p_crew_id)
      from public.crew_members cm where cm.crew_id = p_crew_id;

    delete from public.crews where id = p_crew_id;
    return query select v_votes_count, v_members_count, true;
    return;
  end if;

  if v_votes_count = 1 then
    select username into v_voter_username from public.profiles where id = auth.uid();
    insert into public.notifications (profile_id, type, title, body, data)
      select cm.profile_id, 'crew_disband_vote_started', 'Voto di scioglimento in corso ⚠️',
        coalesce(v_voter_username, 'Un membro') || ' vuole sciogliere ' || coalesce(v_crew_name, 'la crew') || '.',
        jsonb_build_object('crew_id', p_crew_id)
      from public.crew_members cm
      where cm.crew_id = p_crew_id and cm.profile_id <> auth.uid();
  end if;

  return query select v_votes_count, v_members_count, false;
end;
$$;

grant execute on function public.crew_cast_disband_vote(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- Territorio: esagono/i rubato/i. claim_territory_cells già scorre ogni
-- cella della chiamata corrente: qui si aggrega quante celle sono state
-- rubate a ciascuna vittima in questa singola chiamata (un utente può
-- attraversare più esagoni della stessa vittima in un colpo) e si invia
-- una sola notifica per vittima, non una per esagono.
-- ---------------------------------------------------------------------
create or replace function public.claim_territory_cells(p_cells jsonb)
returns table (fresh_count int, stolen_count int)
language plpgsql security definer as $$
declare
  v_profile_id uuid := auth.uid();
  v_cell jsonb;
  v_q int;
  v_r int;
  v_owner uuid;
  v_fresh int := 0;
  v_stolen int := 0;
  v_stolen_from jsonb := '{}'::jsonb;
  v_claimant_username text;
  v_victim record;
begin
  if v_profile_id is null then
    raise exception 'Non autenticato';
  end if;

  for v_cell in select * from jsonb_array_elements(p_cells)
  loop
    v_q := (v_cell->>'q')::int;
    v_r := (v_cell->>'r')::int;

    select tc.owner_id into v_owner from public.territory_cells tc
      where tc.q = v_q and tc.r = v_r for update;

    if v_owner is null then
      insert into public.territory_cells (q, r, owner_id) values (v_q, v_r, v_profile_id);
      insert into public.territory_claim_log (q, r, claimant_id, previous_owner_id)
        values (v_q, v_r, v_profile_id, null);
      v_fresh := v_fresh + 1;
    elsif v_owner <> v_profile_id then
      update public.territory_cells set owner_id = v_profile_id, claimed_at = now()
        where q = v_q and r = v_r;
      insert into public.territory_claim_log (q, r, claimant_id, previous_owner_id)
        values (v_q, v_r, v_profile_id, v_owner);
      v_stolen := v_stolen + 1;
      v_stolen_from := jsonb_set(
        v_stolen_from, array[v_owner::text],
        to_jsonb(coalesce((v_stolen_from->>(v_owner::text))::int, 0) + 1));
    end if;
    -- v_owner = v_profile_id: già mia, nessuna scrittura/log.
  end loop;

  if v_stolen_from <> '{}'::jsonb then
    select username into v_claimant_username from public.profiles where id = v_profile_id;
    for v_victim in select key::uuid as victim_id, value::int as cnt from jsonb_each_text(v_stolen_from)
    loop
      insert into public.notifications (profile_id, type, title, body, data)
        values (v_victim.victim_id, 'territory_stolen', 'Territorio conquistato! 🏴',
          coalesce(v_claimant_username, 'Qualcuno') || ' ti ha rubato ' || v_victim.cnt ||
            case when v_victim.cnt = 1 then ' esagono' else ' esagoni' end,
          jsonb_build_object('cells_stolen', v_victim.cnt));
    end loop;
  end if;

  return query select v_fresh, v_stolen;
end;
$$;

grant execute on function public.claim_territory_cells(jsonb) to authenticated;
