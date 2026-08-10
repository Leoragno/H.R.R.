-- =====================================================================
-- HRR — Onboarding veicolo ("il tuo ride") + campi Impostazioni.
-- Aggiunge a profiles i campi per marca/modello del veicolo principale
-- (raccolti nell'onboarding post-registrazione) e paese/colore accento
-- (schermata Impostazioni). Colonne nullable: un profilo senza
-- vehicle_brand è ciò che fa scattare il redirect all'onboarding lato
-- app (vedi app_router.dart), niente da fare qui oltre alla colonna.
-- =====================================================================

alter table public.profiles
  add column vehicle_brand text,
  add column vehicle_model text,
  add column country text,
  add column accent_color text not null default '#35e0ff';
