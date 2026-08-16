-- =====================================================================
-- HRR — La season seminata da 0003_mission_engine.sql (season_3, "Neon
-- Horizon") copriva solo starts_at..starts_at+12gg: è scaduta senza che
-- nulla la rinnovasse (0003 non prevedeva un generatore di season, a
-- differenza di generate_daily/weekly_missions), lasciando activeSeason()
-- a restituire null — tab SEASON vuota, generate_seasonal_missions()
-- che solleva eccezione, "SEASON END 0 giorni" in Missions. Stesso
-- difetto di fondo delle missioni daily/weekly (0028 lo ha risolto per
-- quelle con generazione lazy), qui risolto estendendo la finestra della
-- season esistente così le missioni stagionali già generate/in corso
-- restano collegate alla stessa season_id invece di essere orfane sotto
-- una nuova riga.
-- =====================================================================

update public.season
set ends_at = greatest(ends_at, now() + interval '30 days')
where code = 'season_3';
