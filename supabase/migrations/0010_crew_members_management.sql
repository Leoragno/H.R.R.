-- =====================================================================
-- HRR — Gestione membri crew (promuovi/retrocedi/espelli): oggi la RLS
-- su crew_members permette solo insert (self-join) e delete (self-leave
-- o kick da parte del proprietario, vedi crew_members_delete_self_or_owner
-- in 0001_init.sql), ma nessuna policy UPDATE esiste — cambiare `role`
-- per promuovere/retrocedere un membro verrebbe quindi sempre rifiutato
-- da Postgres (RLS nega di default se nessuna policy corrisponde).
-- Questa migration aggiunge la sola policy mancante, riservata al
-- proprietario della crew.
-- =====================================================================

create policy "crew_members_update_owner" on public.crew_members
  for update
  using (
    auth.uid() in (select owner_id from public.crews where id = crew_id)
  )
  with check (
    auth.uid() in (select owner_id from public.crews where id = crew_id)
    -- Il proprietario può solo alternare officer/member su un ALTRO
    -- membro: mai assegnare 'owner' (nessun flow di trasferimento
    -- proprietà in questa versione) né toccare la propria riga (che
    -- resta sempre 'owner').
    and role in ('officer', 'member')
    and profile_id <> auth.uid()
  );
