-- =====================================================================
-- HRR — Sistema amici: la tabella public.friendships esiste fin da
-- 0001_init.sql ma non era mai stata collegata a nulla (nessuna RPC,
-- nessun client) — "Aggiungi amici" in classifica era un pulsante morto.
-- Qui si aggiungono le RPC per richiedere/accettare/rimuovere amicizie e
-- la posizione live in guida dei propri amici.
--
-- Posizione live: stesso principio di 0009_crew_live_position.sql (nessuna
-- tabella, canale Realtime effimero), ma un canale per PROFILO invece che
-- per crew — "friend-live-<profile_id>": chi guida pubblica solo sul
-- proprio canale, i suoi amici accettati si iscrivono in sola lettura.
-- Niente canale unico condiviso da tutti gli utenti: la RLS sotto lega
-- l'accesso in lettura a un'amicizia accettata reale, altrimenti chiunque
-- autenticato potrebbe origliare la posizione live di chiunque altro.
-- =====================================================================

-- ---------------------------------------------------------------------
-- send_friend_request — crea una richiesta 'pending'. Se l'altro utente
-- ha già una richiesta pending verso di noi, la accetta subito invece di
-- crearne una seconda parallela (altrimenti la PK (requester_id,
-- addressee_id) permetterebbe comunque due righe indipendenti, una per
-- direzione, mai risolte in un'amicizia unica).
-- ---------------------------------------------------------------------
create or replace function public.send_friend_request(p_addressee_id uuid)
returns text
language plpgsql security definer as $$
declare
  v_me uuid := auth.uid();
  v_existing_status text;
  v_reverse_pending boolean;
  v_username text;
begin
  if v_me is null then
    raise exception 'Non autenticato';
  end if;
  if p_addressee_id = v_me then
    raise exception 'Non puoi aggiungere te stesso';
  end if;

  select status into v_existing_status
    from public.friendships
    where requester_id = v_me and addressee_id = p_addressee_id;
  if v_existing_status is not null then
    raise exception 'Richiesta già inviata';
  end if;

  select true into v_reverse_pending
    from public.friendships
    where requester_id = p_addressee_id and addressee_id = v_me and status = 'pending';

  if v_reverse_pending then
    update public.friendships set status = 'accepted'
      where requester_id = p_addressee_id and addressee_id = v_me;

    select username into v_username from public.profiles where id = v_me;
    insert into public.notifications (profile_id, type, title, body, data)
      values (p_addressee_id, 'friend_accepted', 'Richiesta accettata! 🤝',
        coalesce(v_username, 'Qualcuno') || ' ha accettato la tua richiesta di amicizia',
        jsonb_build_object('profile_id', v_me));
    return 'accepted';
  end if;

  insert into public.friendships (requester_id, addressee_id, status)
    values (v_me, p_addressee_id, 'pending');

  select username into v_username from public.profiles where id = v_me;
  insert into public.notifications (profile_id, type, title, body, data)
    values (p_addressee_id, 'friend_request', 'Nuova richiesta di amicizia 🤝',
      coalesce(v_username, 'Qualcuno') || ' vuole aggiungerti come amico',
      jsonb_build_object('profile_id', v_me));
  return 'sent';
end;
$$;

grant execute on function public.send_friend_request(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- respond_friend_request — l'addressee accetta o rifiuta una richiesta
-- in arrivo. Rifiuto = riga cancellata (non uno status 'declined': niente
-- distingue oggi un rifiuto vecchio da uno recente, e senza quella
-- distinzione tenerla in giro servirebbe solo a bloccare un futuro nuovo
-- tentativo di richiesta).
-- ---------------------------------------------------------------------
create or replace function public.respond_friend_request(p_requester_id uuid, p_accept boolean)
returns void
language plpgsql security definer as $$
declare
  v_me uuid := auth.uid();
  v_username text;
begin
  if v_me is null then
    raise exception 'Non autenticato';
  end if;

  if not exists (
    select 1 from public.friendships
    where requester_id = p_requester_id and addressee_id = v_me and status = 'pending'
  ) then
    raise exception 'Richiesta non trovata';
  end if;

  if p_accept then
    update public.friendships set status = 'accepted'
      where requester_id = p_requester_id and addressee_id = v_me;

    select username into v_username from public.profiles where id = v_me;
    insert into public.notifications (profile_id, type, title, body, data)
      values (p_requester_id, 'friend_accepted', 'Richiesta accettata! 🤝',
        coalesce(v_username, 'Qualcuno') || ' ha accettato la tua richiesta di amicizia',
        jsonb_build_object('profile_id', v_me));
  else
    delete from public.friendships
      where requester_id = p_requester_id and addressee_id = v_me;
  end if;
end;
$$;

grant execute on function public.respond_friend_request(uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------
-- remove_friend — cancella l'amicizia (o la richiesta pending, in
-- entrata o in uscita) in qualunque direzione sia salvata la riga.
-- Nessuna notifica: un "unfriend" silenzioso è la norma in questo tipo
-- di feature.
-- ---------------------------------------------------------------------
create or replace function public.remove_friend(p_other_id uuid)
returns void
language plpgsql security definer as $$
begin
  if auth.uid() is null then
    raise exception 'Non autenticato';
  end if;

  delete from public.friendships
    where (requester_id = auth.uid() and addressee_id = p_other_id)
       or (requester_id = p_other_id and addressee_id = auth.uid());
end;
$$;

grant execute on function public.remove_friend(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- my_friends / pending_friend_requests / search_profiles_for_friend —
-- sola lettura, nessun security definer: la RLS già esistente su
-- friendships (friendships_select_participant) e profiles
-- (profiles_select_all) basta da sola, meno privilegio del necessario è
-- meglio quando non serve scavalcare nulla.
-- ---------------------------------------------------------------------
create or replace function public.my_friends()
returns table (
  profile_id uuid, username text, display_name text,
  avatar_url text, accent_color text, level int
)
language sql stable as $$
  select p.id, p.username, p.display_name, p.avatar_url, p.accent_color, p.level
  from public.friendships f
  join public.profiles p
    on p.id = case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
  where f.status = 'accepted'
    and (f.requester_id = auth.uid() or f.addressee_id = auth.uid());
$$;

grant execute on function public.my_friends() to authenticated;

-- Solo le richieste in arrivo (di cui io sono addressee): quelle in
-- uscita non hanno un'azione da compiere, la UI le mostra già come
-- "inviata" via search_profiles_for_friend.relationship.
create or replace function public.pending_friend_requests()
returns table (
  requester_id uuid, username text, display_name text,
  avatar_url text, accent_color text, level int, created_at timestamptz
)
language sql stable as $$
  select p.id, p.username, p.display_name, p.avatar_url, p.accent_color, p.level, f.created_at
  from public.friendships f
  join public.profiles p on p.id = f.requester_id
  where f.status = 'pending' and f.addressee_id = auth.uid()
  order by f.created_at desc;
$$;

grant execute on function public.pending_friend_requests() to authenticated;

create or replace function public.search_profiles_for_friend(p_query text)
returns table (
  profile_id uuid, username text, display_name text,
  avatar_url text, level int, relationship text
)
language sql stable as $$
  select p.id, p.username, p.display_name, p.avatar_url, p.level,
    coalesce((
      select case
        when f.status = 'accepted' then 'accepted'
        when f.requester_id = auth.uid() then 'pending_outgoing'
        else 'pending_incoming'
      end
      from public.friendships f
      where (f.requester_id = auth.uid() and f.addressee_id = p.id)
         or (f.requester_id = p.id and f.addressee_id = auth.uid())
      limit 1
    ), 'none') as relationship
  from public.profiles p
  where p.id <> auth.uid()
    and p.username ilike p_query || '%'
  order by p.username
  limit 20;
$$;

grant execute on function public.search_profiles_for_friend(text) to authenticated;

-- ---------------------------------------------------------------------
-- Realtime authorization per "friend-live-<profile_id>" (vedi commento
-- di testa). realtime.messages e il grant a livello di tabella sono già
-- abilitati da 0009_crew_live_position.sql — qui solo le due nuove policy.
-- ---------------------------------------------------------------------
create policy "friend_live_send" on realtime.messages
  for insert
  to authenticated
  with check (
    realtime.topic() like 'friend-live-%'
    and replace(realtime.topic(), 'friend-live-', '') = auth.uid()::text
  );

create policy "friend_live_receive" on realtime.messages
  for select
  to authenticated
  using (
    realtime.topic() like 'friend-live-%'
    and (
      replace(realtime.topic(), 'friend-live-', '') = auth.uid()::text
      or exists (
        select 1 from public.friendships f
        where f.status = 'accepted'
          and (
            (f.requester_id = auth.uid() and f.addressee_id = replace(realtime.topic(), 'friend-live-', '')::uuid)
            or (f.addressee_id = auth.uid() and f.requester_id = replace(realtime.topic(), 'friend-live-', '')::uuid)
          )
      )
    )
  );
