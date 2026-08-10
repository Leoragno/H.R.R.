-- HRR — Rival: scelta mascotte persistita lato utente (fase 2).
-- Colonna nullable, nessun default: null = "nessuna scelta ancora fatta",
-- gestito lato app da active_mascot_provider.dart (fallback a
-- kMascotCatalog.first) — stesso pattern di vehicle_brand in
-- 0006_profile_vehicle_and_appearance.sql. Nessun CHECK constraint sui
-- 5 id noti, stesso trattamento "testo libero" di accent_color: un id
-- sconosciuto o rimosso da kMascotCatalog in futuro ricade comunque sul
-- fallback client-side, niente da validare lato DB.

alter table public.profiles
  add column mascot_id text;
