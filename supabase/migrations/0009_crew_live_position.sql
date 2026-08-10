-- =====================================================================
-- HRR — Mappa "Guida": posizione live dei membri della crew.
--
-- Nessuna nuova tabella per la posizione: i fix GPS cambiano troppo
-- spesso per giustificare una scrittura persistita ad ogni update (vedi
-- TripLiveController, che già throttling-a-parte non scrive mai la route
-- lato server prima di fine corsa). Si usa invece un canale Realtime
-- privato per crew, "crew-live-<crew_id>":
--   - chi guida fa `track()` (Presence) all'avvio della corsa e
--     `sendBroadcastMessage` ad ogni fix GPS (evento "position");
--   - gli altri membri della crew, sulla mappa della sezione guida,
--     si iscrivono in sola lettura allo stesso canale.
--
-- I canali Realtime privati non hanno RLS propria finché non si
-- autorizza esplicitamente `realtime.messages` (Supabase "Realtime
-- Authorization"): senza queste policy nessuno potrebbe unirsi al
-- canale. Il topic incorpora il crew_id, quindi la policy si limita a
-- verificare che l'utente autenticato sia membro di quella crew — sia
-- per pubblicare (guidatore) sia per ricevere (osservatori).
-- =====================================================================

alter table realtime.messages enable row level security;

grant select, insert on realtime.messages to authenticated;

create policy "crew_live_send" on realtime.messages
  for insert
  to authenticated
  with check (
    realtime.topic() like 'crew-live-%'
    and exists (
      select 1 from public.crew_members cm
      where cm.profile_id = auth.uid()
        and cm.crew_id = replace(realtime.topic(), 'crew-live-', '')::uuid
    )
  );

create policy "crew_live_receive" on realtime.messages
  for select
  to authenticated
  using (
    realtime.topic() like 'crew-live-%'
    and exists (
      select 1 from public.crew_members cm
      where cm.profile_id = auth.uid()
        and cm.crew_id = replace(realtime.topic(), 'crew-live-', '')::uuid
    )
  );
