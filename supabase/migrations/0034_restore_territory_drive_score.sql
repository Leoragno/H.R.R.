-- =====================================================================
-- HRR — Ripristina territory_cells.drive_score.
--
-- La colonna (0026_territory_decay_counterattack.sql) era stata droppata
-- a mano sul DB remoto, ma territory_cells_near, my_territories e
-- claim_territory_cells la leggono/scrivono ancora: ogni chiamata falliva
-- con "column tc.drive_score does not exist" e la mappa non mostrava più
-- nessun pentagono. Il client non invia più p_drive_score (resta null),
-- ma le RPC devono comunque trovare la colonna.
-- =====================================================================

alter table public.territory_cells
  add column if not exists drive_score smallint;

notify pgrst, 'reload schema';
