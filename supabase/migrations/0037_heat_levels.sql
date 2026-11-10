-- =====================================================================
-- HRR — Curva livelli HEAT (handoff "HRR · Heat").
--
-- Prima: level = floor(sqrt(xp / 100)) + 1  (0002, 0018).
-- Ora:   per passare dal livello l al successivo servono 1500 + 150·l XP,
--        stessa regola di lib/features/progression/domain/progression.dart
--        (xpNeededForLevel / levelProgressFromTotalXp).
--
-- ATTENZIONE: la nuova curva è più lenta. I profili esistenti vengono
-- ricalcolati in fondo a questo file e il loro livello può SCENDERE
-- (es. 10.000 XP: prima LV 11, ora LV 6). Nessuna notifica viene inviata
-- per il ricalcolo.
-- =====================================================================

create or replace function public.heat_level_from_xp(p_xp bigint)
returns int
language plpgsql immutable as $$
declare
  v_level int := 1;
  v_rest bigint := greatest(0, coalesce(p_xp, 0));
begin
  while v_rest >= 1500 + 150 * v_level loop
    v_rest := v_rest - (1500 + 150 * v_level);
    v_level := v_level + 1;
  end loop;
  return v_level;
end;
$$;

-- Stessa funzione di 0018 (notifica di level up), con la nuova curva.
create or replace function public.apply_xp_event() returns trigger
language plpgsql security definer as $$
declare
  v_old_level int;
  v_new_xp bigint;
  v_new_level int;
begin
  select level into v_old_level from public.profiles where id = NEW.profile_id;

  update public.profiles
  set xp = xp + NEW.xp_delta,
      rep = rep + NEW.rep_delta,
      updated_at = now()
  where id = NEW.profile_id
  returning xp into v_new_xp;

  v_new_level := public.heat_level_from_xp(v_new_xp);

  update public.profiles
  set level = v_new_level
  where id = NEW.profile_id;

  if v_new_level > coalesce(v_old_level, 1) then
    insert into public.notifications (profile_id, type, title, body, data)
      values (NEW.profile_id, 'level_up', 'Livello superiore! 🚀',
        'Sei salito al livello ' || v_new_level || '.',
        jsonb_build_object('level', v_new_level));
  end if;

  return NEW;
end;
$$;

-- Riallinea i profili esistenti alla nuova curva (senza notifiche).
update public.profiles
set level = public.heat_level_from_xp(xp)
where level is distinct from public.heat_level_from_xp(xp);
