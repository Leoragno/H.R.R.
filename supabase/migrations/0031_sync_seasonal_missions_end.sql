-- =====================================================================
-- HRR — Le missioni stagionali generate da generate_seasonal_missions()
-- copiano starts_at/ends_at dalla season al momento della generazione
-- (0003_mission_engine.sql) — non restano agganciate dinamicamente alla
-- riga season. Estendere season.ends_at (0029_extend_active_season.sql)
-- non le tocca: restano scadute con la finestra vecchia, e il generatore
-- non le rigenera perché il code (template || '_' || season.code) non è
-- cambiato (on conflict do nothing). Le riallinea qui una volta;
-- ri-eseguibile (no-op se già allineate).
-- =====================================================================

update public.missions m
set ends_at = s.ends_at
from public.season s
where m.season_id = s.id
  and m.ends_at < s.ends_at;
