-- =====================================================================
-- HRR — Furto dei pentagoni passandoci sopra.
--
-- Prima (0026/0028) una cella attiva di un altro giocatore si rubava solo
-- con un punteggio di guida più alto del suo; il client però non invia
-- più p_drive_score, quindi di fatto nessuno poteva più rubare nulla.
-- Ora basta attraversarla in una guida completata: diventa tua e il
-- proprietario precedente riceve la notifica push. p_drive_score resta
-- nella firma (default null) solo per compatibilità con i client
-- vecchi, e viene salvato se presente.
--
-- Rimuove anche il vecchio overload claim_territory_cells(jsonb) di
-- 0008/0017, mai droppato da 0026: da quando il client chiama la RPC con
-- il solo p_cells, PostgREST non sapeva quale delle due scegliere
-- (PGRST203) e ogni conquista a fine guida falliva in silenzio.
-- =====================================================================

drop function if exists public.claim_territory_cells(jsonb);

create or replace function public.claim_territory_cells(p_cells jsonb, p_drive_score int default null)
returns table (fresh_count int, stolen_count int)
language plpgsql security definer as $$
declare
  v_profile_id uuid := auth.uid();
  v_actor_username text;
  v_cell jsonb;
  v_q int;
  v_r int;
  v_row public.territory_cells;
  v_expired boolean;
  v_fresh int := 0;
  v_stolen int := 0;
  v_victims jsonb := '{}'::jsonb;
  v_victim_id uuid;
  v_victim_count int;
begin
  if v_profile_id is null then
    raise exception 'Non autenticato';
  end if;

  for v_cell in select * from jsonb_array_elements(p_cells)
  loop
    v_q := (v_cell->>'q')::int;
    v_r := (v_cell->>'r')::int;

    select * into v_row from public.territory_cells
      where q = v_q and r = v_r for update;

    v_expired := v_row is not null
      and v_row.claimed_at < now() - (public.territory_decay_days() || ' days')::interval;

    if v_row is null or v_expired then
      insert into public.territory_cells (q, r, owner_id, claimed_at, drive_score)
        values (v_q, v_r, v_profile_id, now(), p_drive_score)
        on conflict (q, r) do update
          set owner_id = excluded.owner_id, claimed_at = excluded.claimed_at,
              drive_score = excluded.drive_score;
      insert into public.territory_claim_log (q, r, claimant_id, previous_owner_id)
        values (v_q, v_r, v_profile_id, case when v_expired then v_row.owner_id else null end);
      v_fresh := v_fresh + 1;

    elsif v_row.owner_id = v_profile_id then
      update public.territory_cells set claimed_at = now() where q = v_q and r = v_r;
      -- Nessun log/punto: non è un claim, solo un rinnovo.

    else
      update public.territory_cells
        set owner_id = v_profile_id, claimed_at = now(), drive_score = p_drive_score
        where q = v_q and r = v_r;
      insert into public.territory_claim_log (q, r, claimant_id, previous_owner_id)
        values (v_q, v_r, v_profile_id, v_row.owner_id);
      v_stolen := v_stolen + 1;
      v_victims := jsonb_set(v_victims, array[v_row.owner_id::text],
        to_jsonb(coalesce((v_victims->>v_row.owner_id::text)::int, 0) + 1));
    end if;
  end loop;

  -- Una sola notifica per giocatore derubato, non una per cella: una
  -- guida che attraversa il suo quartiere ne toglierebbe decine.
  if v_victims <> '{}'::jsonb then
    select username into v_actor_username from public.profiles where id = v_profile_id;
    for v_victim_id, v_victim_count in
      select key::uuid, value::int from jsonb_each_text(v_victims)
    loop
      insert into public.notifications (profile_id, type, title, body, data)
        values (v_victim_id, 'territory_stolen', 'Territorio conquistato! 🏴',
          coalesce(v_actor_username, 'Qualcuno') || ' ti ha rubato ' ||
            case when v_victim_count = 1 then 'un pentagono'
                 else v_victim_count || ' pentagoni' end ||
            ' passandoci sopra.',
          jsonb_build_object('actor_id', v_profile_id, 'count', v_victim_count));
    end loop;
  end if;

  if v_fresh > 0 or v_stolen > 0 then
    perform public.evaluate_achievements(v_profile_id);
  end if;

  return query select v_fresh, v_stolen;
end;
$$;

grant execute on function public.claim_territory_cells(jsonb, int) to authenticated;

notify pgrst, 'reload schema';
