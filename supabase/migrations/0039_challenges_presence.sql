-- =====================================================================
-- HRR — HEAT: sfide 1 vs 1, "visto l'ultima volta", classifica settimana.
--
-- Amici: l'app è privata e chiusa (vedi 0027) — tutti gli utenti sono
-- già amici, quindi nessuna tabella di amicizie. Serve solo sapere quando
-- un pilota è stato visto l'ultima volta (lo stato IN GUIDA arriva dal
-- canale realtime "drivers-live").
--
-- Sfide: A sfida B su una metrica (FLOW migliore, velocità massima, km
-- totali, esagoni presi) per 24 h o 3 giorni, con una posta in XP. B
-- accetta o rifiuta entro 24 h. I punteggi NON sono salvati: si calcolano
-- dai viaggi completati (e dal log territori) nella finestra della sfida,
-- così non serve toccare complete_trip. Alla scadenza la sfida si chiude
-- in modo "pigro" (nessun pg_cron sul progetto): ogni lettura di
-- my_challenges() chiude quelle scadute; il vincitore riceve la posta in
-- XP via xp_events (chi perde non perde XP). Pareggio: nessun premio.
--
-- Scritture solo via RPC security definer; la tabella è leggibile dai
-- due partecipanti.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Visto l'ultima volta
-- ---------------------------------------------------------------------
alter table public.profiles
  add column if not exists last_seen_at timestamptz;

create or replace function public.touch_last_seen()
returns void
language sql
security definer
set search_path = public
as $$
  update public.profiles
     set last_seen_at = now()
   where id = auth.uid()
     and (last_seen_at is null or last_seen_at < now() - interval '2 minutes');
$$;

grant execute on function public.touch_last_seen() to authenticated;

-- ---------------------------------------------------------------------
-- 2. Sfide
-- ---------------------------------------------------------------------
create table if not exists public.challenges (
  id uuid primary key default gen_random_uuid(),
  challenger_id uuid not null references public.profiles(id) on delete cascade,
  opponent_id uuid not null references public.profiles(id) on delete cascade,
  metric text not null check (metric in ('flow','top_speed','km','hexes')),
  duration_hours int not null check (duration_hours in (24, 72)),
  stake_xp int not null check (stake_xp in (100, 250, 500)),
  status text not null default 'pending'
    check (status in ('pending','declined','cancelled','expired','active','finished')),
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  ends_at timestamptz,
  challenger_score numeric,
  opponent_score numeric,
  winner_id uuid references public.profiles(id) on delete set null,
  settled_at timestamptz,
  check (challenger_id <> opponent_id)
);

create index if not exists challenges_challenger_idx
  on public.challenges (challenger_id, status);
create index if not exists challenges_opponent_idx
  on public.challenges (opponent_id, status);

alter table public.challenges enable row level security;

drop policy if exists "challenges_select_participants" on public.challenges;
create policy "challenges_select_participants" on public.challenges
  for select to authenticated
  using (auth.uid() in (challenger_id, opponent_id));

-- Punteggio di un pilota su una metrica in una finestra.
create or replace function public.challenge_score(
  p_profile uuid, p_metric text, p_from timestamptz, p_to timestamptz)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select case p_metric
    when 'flow' then (select coalesce(max(driving_score), 0)::numeric
                        from trips
                       where driver_id = p_profile and status = 'completed'
                         and ended_at >= p_from and ended_at < p_to)
    when 'top_speed' then (select coalesce(max(max_speed_kmh), 0)
                             from trips
                            where driver_id = p_profile and status = 'completed'
                              and ended_at >= p_from and ended_at < p_to)
    when 'km' then (select coalesce(sum(distance_km), 0)
                      from trips
                     where driver_id = p_profile and status = 'completed'
                       and ended_at >= p_from and ended_at < p_to)
    when 'hexes' then (select count(*)::numeric
                         from territory_claim_log
                        where claimant_id = p_profile
                          and claimed_at >= p_from and claimed_at < p_to)
    else 0
  end;
$$;

-- Chiude le sfide scadute dell'utente corrente (e le richieste mai
-- accettate entro 24 h). Idempotente: ogni sfida si chiude una volta.
create or replace function public.settle_my_challenges()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  c record;
  v_a numeric;
  v_b numeric;
  v_winner uuid;
  v_label text;
begin
  update challenges
     set status = 'expired', settled_at = now()
   where status = 'pending'
     and created_at < now() - interval '24 hours'
     and auth.uid() in (challenger_id, opponent_id);

  for c in
    select * from challenges
     where status = 'active' and ends_at <= now()
       and auth.uid() in (challenger_id, opponent_id)
     for update skip locked
  loop
    v_a := challenge_score(c.challenger_id, c.metric, c.accepted_at, c.ends_at);
    v_b := challenge_score(c.opponent_id, c.metric, c.accepted_at, c.ends_at);
    v_winner := case when v_a > v_b then c.challenger_id
                     when v_b > v_a then c.opponent_id end;

    update challenges
       set status = 'finished', challenger_score = v_a, opponent_score = v_b,
           winner_id = v_winner, settled_at = now()
     where id = c.id;

    v_label := case c.metric when 'flow' then 'FLOW' when 'top_speed' then 'velocità'
                             when 'km' then 'km' else 'esagoni' end;

    if v_winner is not null then
      insert into xp_events (profile_id, source, source_id, xp_delta, rep_delta)
        values (v_winner, 'challenge', c.id, c.stake_xp, 0);
      insert into notifications (profile_id, type, title, body, data) values
        (v_winner, 'challenge_won', 'Sfida vinta',
         'hai vinto la sfida ' || v_label || '. +' || c.stake_xp || ' XP.',
         jsonb_build_object('challenge_id', c.id, 'stake_xp', c.stake_xp)),
        (case when v_winner = c.challenger_id then c.opponent_id else c.challenger_id end,
         'challenge_lost', 'Sfida persa',
         'hai perso la sfida ' || v_label || '. chiedi la rivincita.',
         jsonb_build_object('challenge_id', c.id));
    else
      insert into notifications (profile_id, type, title, body, data)
        select p, 'challenge_draw', 'Sfida pari',
               'la sfida ' || v_label || ' è finita in parità.',
               jsonb_build_object('challenge_id', c.id)
          from unnest(array[c.challenger_id, c.opponent_id]) p;
    end if;
  end loop;
end;
$$;

-- Le mie sfide con i punteggi aggiornati (live per le attive, finali per
-- le chiuse). Chiude prima quelle scadute.
create or replace function public.my_challenges()
returns table (
  id uuid, challenger_id uuid, opponent_id uuid, metric text,
  duration_hours int, stake_xp int, status text, created_at timestamptz,
  accepted_at timestamptz, ends_at timestamptz,
  challenger_score numeric, opponent_score numeric, winner_id uuid)
language plpgsql
security definer
set search_path = public
as $$
begin
  perform settle_my_challenges();
  return query
    select ch.id, ch.challenger_id, ch.opponent_id, ch.metric,
           ch.duration_hours, ch.stake_xp, ch.status, ch.created_at,
           ch.accepted_at, ch.ends_at,
           case when ch.status = 'active'
                then challenge_score(ch.challenger_id, ch.metric, ch.accepted_at, now())
                else ch.challenger_score end,
           case when ch.status = 'active'
                then challenge_score(ch.opponent_id, ch.metric, ch.accepted_at, now())
                else ch.opponent_score end,
           ch.winner_id
      from challenges ch
     where auth.uid() in (ch.challenger_id, ch.opponent_id)
       and (ch.status in ('pending','active')
            or ch.created_at > now() - interval '60 days')
     order by ch.created_at desc
     limit 100;
end;
$$;

-- Nuova sfida. Massimo 3 sfide aperte (in attesa o in corso) per pilota,
-- una sola aperta per coppia.
create or replace function public.create_challenge(
  p_opponent uuid, p_metric text, p_duration_hours int, p_stake_xp int)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_id uuid;
  v_name text;
begin
  if v_me is null then raise exception 'not_authenticated'; end if;
  if p_opponent = v_me then raise exception 'cannot_challenge_self'; end if;
  if not exists (select 1 from profiles where id = p_opponent) then
    raise exception 'opponent_not_found';
  end if;
  perform settle_my_challenges();
  if (select count(*) from challenges
       where v_me in (challenger_id, opponent_id)
         and status in ('pending','active')) >= 3 then
    raise exception 'too_many_open_challenges';
  end if;
  if exists (select 1 from challenges
              where status in ('pending','active')
                and ((challenger_id = v_me and opponent_id = p_opponent)
                  or (challenger_id = p_opponent and opponent_id = v_me))) then
    raise exception 'challenge_already_open';
  end if;

  insert into challenges (challenger_id, opponent_id, metric, duration_hours, stake_xp)
    values (v_me, p_opponent, p_metric, p_duration_hours, p_stake_xp)
    returning id into v_id;

  select username into v_name from profiles where id = v_me;
  insert into notifications (profile_id, type, title, body, data)
    values (p_opponent, 'challenge_received', 'Nuova sfida',
            v_name || ' ti ha sfidato. posta ' || p_stake_xp || ' XP.',
            jsonb_build_object('challenge_id', v_id, 'from', v_me,
                               'from_username', v_name));
  return v_id;
end;
$$;

-- Risposta dell'avversario: accetta (parte il timer) o rifiuta.
create or replace function public.respond_challenge(p_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  c record;
  v_name text;
begin
  select * into c from challenges where id = p_id for update;
  if not found or c.opponent_id <> auth.uid() then
    raise exception 'challenge_not_found';
  end if;
  if c.status <> 'pending' or c.created_at < now() - interval '24 hours' then
    raise exception 'challenge_not_pending';
  end if;

  if p_accept then
    if (select count(*) from challenges
         where auth.uid() in (challenger_id, opponent_id)
           and status = 'active') >= 3 then
      raise exception 'too_many_open_challenges';
    end if;
    update challenges
       set status = 'active', accepted_at = now(),
           ends_at = now() + make_interval(hours => c.duration_hours)
     where id = p_id;
  else
    update challenges set status = 'declined', settled_at = now() where id = p_id;
  end if;

  select username into v_name from profiles where id = c.opponent_id;
  insert into notifications (profile_id, type, title, body, data)
    values (c.challenger_id,
            case when p_accept then 'challenge_accepted' else 'challenge_declined' end,
            case when p_accept then 'Sfida accettata' else 'Sfida rifiutata' end,
            v_name || case when p_accept then ' ha accettato la sfida. si parte.'
                           else ' ha rifiutato la sfida.' end,
            jsonb_build_object('challenge_id', p_id));
end;
$$;

-- Ritiro di una sfida ancora in attesa (solo chi l'ha lanciata).
create or replace function public.cancel_challenge(p_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update challenges
     set status = 'cancelled', settled_at = now()
   where id = p_id and challenger_id = auth.uid() and status = 'pending';
$$;

revoke all on function public.challenge_score(uuid, text, timestamptz, timestamptz) from public, anon, authenticated;
revoke all on function public.settle_my_challenges() from public, anon, authenticated;
grant execute on function public.my_challenges() to authenticated;
grant execute on function public.create_challenge(uuid, text, int, int) to authenticated;
grant execute on function public.respond_challenge(uuid, boolean) to authenticated;
grant execute on function public.cancel_challenge(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 3. Classifica XP di un periodo (per "La tua settimana": posizione ora
--    e la settimana prima). xp_events è leggibile solo dal proprietario,
--    quindi la somma passa da qui; restituisce solo id e totale.
-- ---------------------------------------------------------------------
create or replace function public.xp_ranking_between(p_from timestamptz, p_to timestamptz)
returns table (profile_id uuid, xp bigint)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, coalesce(sum(e.xp_delta), 0)::bigint
    from profiles p
    left join xp_events e
      on e.profile_id = p.id and e.created_at >= p_from and e.created_at < p_to
   group by p.id
   order by 2 desc, p.id;
$$;

grant execute on function public.xp_ranking_between(timestamptz, timestamptz) to authenticated;
