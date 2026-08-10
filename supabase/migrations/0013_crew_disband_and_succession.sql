-- =====================================================================
-- HRR — Lasciare/eliminare una crew.
--
-- Eliminare una crew richiede il voto unanime di tutti i membri attuali
-- (se la crew ha un solo membro — il proprietario da solo — il suo
-- stesso voto è già "tutti", quindi si scioglie all'istante). Non esiste
-- una policy DELETE su public.crews apposta: la cancellazione avviene
-- solo dentro crew_cast_disband_vote() (security definer), mai da un
-- client direttamente.
--
-- Se il proprietario abbandona una crew che ha ancora altri membri, la
-- proprietà passa automaticamente al membro rimasto più "anziano"
-- (prima un eventuale officer, poi per data di ingresso) — nessuna crew
-- deve mai restare senza un owner valido.
-- =====================================================================

create table public.crew_disband_votes (
  crew_id uuid not null references public.crews(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  voted_at timestamptz not null default now(),
  primary key (crew_id, profile_id)
);

alter table public.crew_disband_votes enable row level security;

-- Sola lettura per i membri della crew (per mostrare "X/Y hanno votato");
-- scritture solo tramite le RPC sotto (security definer, bypassano RLS).
create policy "crew_disband_votes_select_members" on public.crew_disband_votes
  for select using (
    auth.uid() in (
      select profile_id from public.crew_members
      where crew_id = crew_disband_votes.crew_id
    )
  );

-- ---------------------------------------------------------------------
-- crew_cast_disband_vote: registra il voto del chiamante per sciogliere
-- la crew; se a quel punto tutti i membri attuali hanno votato, elimina
-- la crew (cascade su crew_members/crew_disband_votes, SET NULL su
-- profiles.crew_id via il vincolo esistente).
-- ---------------------------------------------------------------------
create or replace function public.crew_cast_disband_vote(p_crew_id uuid)
returns table (votes_count int, members_count int, disbanded boolean)
language plpgsql security definer as $$
declare
  v_members_count int;
  v_votes_count int;
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

  if v_votes_count >= v_members_count then
    delete from public.crews where id = p_crew_id;
    return query select v_votes_count, v_members_count, true;
    return;
  end if;

  return query select v_votes_count, v_members_count, false;
end;
$$;

grant execute on function public.crew_cast_disband_vote(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- crew_retract_disband_vote: un membro ritira il proprio voto — rompe
-- l'unanimità e la votazione resta in sospeso finché non rivota.
-- ---------------------------------------------------------------------
create or replace function public.crew_retract_disband_vote(p_crew_id uuid)
returns void
language plpgsql security definer as $$
begin
  delete from public.crew_disband_votes
  where crew_id = p_crew_id and profile_id = auth.uid();
end;
$$;

grant execute on function public.crew_retract_disband_vote(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- crew_leave: lascia la crew. Se il chiamante è il proprietario e
-- restano altri membri, trasferisce prima la proprietà (officer più
-- anziano, altrimenti il membro più anziano per data di ingresso).
-- ---------------------------------------------------------------------
create or replace function public.crew_leave(p_crew_id uuid)
returns void
language plpgsql security definer as $$
declare
  v_is_owner boolean;
  v_successor uuid;
begin
  select (owner_id = auth.uid()) into v_is_owner
  from public.crews where id = p_crew_id;

  if v_is_owner is null then
    raise exception 'Crew non trovata';
  end if;

  if v_is_owner then
    select profile_id into v_successor
    from public.crew_members
    where crew_id = p_crew_id and profile_id <> auth.uid()
    order by (role = 'officer') desc, joined_at asc
    limit 1;

    if v_successor is not null then
      update public.crews set owner_id = v_successor where id = p_crew_id;
      update public.crew_members set role = 'owner'
        where crew_id = p_crew_id and profile_id = v_successor;
    end if;
  end if;

  delete from public.crew_members
    where crew_id = p_crew_id and profile_id = auth.uid();
  update public.profiles set crew_id = null where id = auth.uid();
  -- un eventuale voto di disbandimento lasciato da chi se ne va non ha
  -- più senso: lo ritiriamo così non blocca a metà una votazione altrui.
  delete from public.crew_disband_votes
    where crew_id = p_crew_id and profile_id = auth.uid();
end;
$$;

grant execute on function public.crew_leave(uuid) to authenticated;
