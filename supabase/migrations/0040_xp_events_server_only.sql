-- =====================================================================
-- HRR — XP solo dal server.
--
-- 0002 aveva aperto `xp_events_insert_self`: ogni utente autenticato
-- poteva inserire righe XP per sé (e il trigger apply_xp_event le somma
-- al profilo). Con sfide e classifica XP settimanale (0039) è un modo
-- banale per gonfiarsi i punti.
--
-- Nessun client scrive in xp_events: le uniche funzioni che lo fanno
-- (_grant_xp_rep, complete_trip, settle_my_challenges) sono SECURITY
-- DEFINER e non passano dalla RLS. Togliere la policy non cambia nulla
-- per l'app; la lettura delle proprie righe resta.
-- =====================================================================

drop policy if exists "xp_events_insert_self" on public.xp_events;
revoke insert, update, delete on public.xp_events from anon, authenticated;
