-- HRR — Rival: notifica a chi viene superato in classifica.
-- Il sorpasso è rilevato client-side (leaderboard_screen.dart, confronto
-- tra fetch successive di leaderboard_global), quindi qui non c'è alcun
-- trigger da agganciare: serve una RPC callabile dal client, stesso
-- schema di claim_territory_cells (0017_social_and_crew_notifications.sql)
-- — security definer, usa auth.uid() come attore, legge lo username
-- server-side (mai fidarsi di un nome passato dal client).
-- Niente numero di posizione nel testo: il chiamante non ha (e non deve
-- fidarsi di) il rank aggiornato della vittima.

create or replace function public.notify_leaderboard_overtake(p_victim_id uuid)
returns void
language plpgsql security definer as $$
declare
  v_actor_id uuid := auth.uid();
  v_actor_username text;
begin
  if v_actor_id is null or v_actor_id = p_victim_id then
    return;
  end if;

  select username into v_actor_username from public.profiles where id = v_actor_id;

  insert into public.notifications (profile_id, type, title, body, data)
    values (p_victim_id, 'leaderboard_overtaken', 'Sorpasso in classifica! 📉',
      coalesce(v_actor_username, 'Qualcuno') || ' ti ha superato nella classifica settimanale.',
      jsonb_build_object('actor_id', v_actor_id));
end;
$$;

grant execute on function public.notify_leaderboard_overtake(uuid) to authenticated;
