-- =====================================================================
-- HRR — Espande il catalogo achievement (0003_mission_engine.sql ne
-- seminava solo 5, tutti su total_km/total_trips) e collega i traguardi
-- di territorio/car spotting, finora mai valutati perché
-- evaluate_achievements() supportava solo total_km/total_trips/rep/level.
-- =====================================================================

-- ---------------------------------------------------------------------
-- evaluate_achievements — stessa firma/logica di 0003, con 4 metriche in
-- più: xp e driving_score leggono direttamente da profiles (come le
-- 4 originali); territory_cells_owned e cars_spotted sono le uniche che
-- richiedono una subquery, non essendo aggregati già presenti su
-- profiles. territory_cells_owned esclude le celle decadute (stessa
-- soglia "pigra" di territory_decay_days(), 0026) così l'achievement
-- riflette lo stesso possesso mostrato in "I miei territori", non un
-- conteggio storico che include celle perse da tempo.
-- ---------------------------------------------------------------------
create or replace function public.evaluate_achievements(p_profile_id uuid) returns void
language plpgsql security definer as $$
declare
  v_profile public.profiles;
  v_achievement public.achievements;
  v_current numeric;
begin
  select * into v_profile from public.profiles where id = p_profile_id;
  if v_profile is null then
    return;
  end if;

  for v_achievement in
    select a.* from public.achievements a
    where not exists (
      select 1 from public.user_achievements ua
      where ua.profile_id = p_profile_id and ua.achievement_id = a.id
    )
  loop
    v_current := case v_achievement.target_metric
      when 'total_km' then v_profile.total_km
      when 'total_trips' then v_profile.total_trips
      when 'rep' then v_profile.rep
      when 'level' then v_profile.level
      when 'xp' then v_profile.xp
      when 'driving_score' then v_profile.driving_score
      when 'territory_cells_owned' then (
        select count(*) from public.territory_cells
        where owner_id = p_profile_id
          and claimed_at >= now() - (public.territory_decay_days() || ' days')::interval
      )
      when 'cars_spotted' then (
        select count(*) from public.spots where author_id = p_profile_id
      )
      else null
    end;

    if v_current is not null and v_current >= v_achievement.target_value then
      insert into public.user_achievements (profile_id, achievement_id)
        values (p_profile_id, v_achievement.id)
        on conflict do nothing;

      perform public._grant_xp_rep(
        p_profile_id, v_achievement.reward_xp, v_achievement.reward_rep, 'achievement', v_achievement.id
      );

      if v_achievement.reward_badges is not null and array_length(v_achievement.reward_badges, 1) > 0 then
        insert into public.profile_badges (profile_id, badge_id)
        select p_profile_id, b from unnest(v_achievement.reward_badges) as b
        on conflict do nothing;
      end if;

      insert into public.notifications (profile_id, type, title, body, data)
        values (p_profile_id, 'achievement_unlocked', 'Achievement sbloccato', v_achievement.name,
          jsonb_build_object('achievement_id', v_achievement.id));
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- claim_territory_cells — stessa logica di 0026, con una rivalutazione
-- achievement per il claimant a fine funzione: territory_cells_owned
-- (sopra) non passa mai da record_mission_event (nessun evento di
-- dominio "territorio conquistato" pubblicato dal client), quindi senza
-- questa chiamata resterebbe congelato fino al prossimo evento missione
-- indipendente (prossimo viaggio/foto/...).
-- ---------------------------------------------------------------------
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

    elsif p_drive_score is not null and p_drive_score > coalesce(v_row.drive_score, -1) then
      update public.territory_cells
        set owner_id = v_profile_id, claimed_at = now(), drive_score = p_drive_score
        where q = v_q and r = v_r;
      insert into public.territory_claim_log (q, r, claimant_id, previous_owner_id)
        values (v_q, v_r, v_profile_id, v_row.owner_id);
      v_stolen := v_stolen + 1;

      if v_actor_username is null then
        select username into v_actor_username from public.profiles where id = v_profile_id;
      end if;
      insert into public.notifications (profile_id, type, title, body, data)
        values (v_row.owner_id, 'territory_stolen', 'Territorio conquistato! 🏴',
          coalesce(v_actor_username, 'Qualcuno') ||
            ' ti ha rubato un pentagono con un punteggio di guida di ' || p_drive_score || '.',
          jsonb_build_object('q', v_q, 'r', v_r, 'actor_id', v_profile_id,
            'drive_score', p_drive_score));
    end if;
    -- p_drive_score troppo basso/null contro un proprietario reale: nessun
    -- cambiamento, nessun log — il tentativo semplicemente non riesce.
  end loop;

  if v_fresh > 0 or v_stolen > 0 then
    perform public.evaluate_achievements(v_profile_id);
  end if;

  return query select v_fresh, v_stolen;
end;
$$;

-- =====================================================================
-- SEED — nuovi achievement, stesso stile di 0003 (code/name/description/
-- icon/rarity/target_metric/target_value/reward_rep/reward_xp).
-- =====================================================================

insert into public.achievements (code, name, description, icon, rarity, target_metric, target_value, reward_rep, reward_xp) values
  ('km_10', '10 km', 'Percorri 10 km in totale', 'route', 'common', 'total_km', 10, 10, 10),
  ('km_500', '500 km', 'Percorri 500 km in totale', 'route', 'uncommon', 'total_km', 500, 100, 100),
  ('trips_10', '10 viaggi', 'Completa 10 viaggi', 'flag', 'uncommon', 'total_trips', 10, 80, 80),
  ('trips_50', '50 viaggi', 'Completa 50 viaggi', 'flag', 'rare', 'total_trips', 50, 250, 250),
  ('level_5', 'Livello 5', 'Raggiungi il livello 5', 'military_tech', 'common', 'level', 5, 40, 40),
  ('level_10', 'Livello 10', 'Raggiungi il livello 10', 'military_tech', 'uncommon', 'level', 10, 100, 100),
  ('level_25', 'Livello 25', 'Raggiungi il livello 25', 'military_tech', 'rare', 'level', 25, 300, 300),
  ('level_50', 'Livello 50', 'Raggiungi il livello 50', 'workspace_premium', 'epic', 'level', 50, 800, 800),
  ('rep_500', '500 REP', 'Accumula 500 REP', 'trophy', 'common', 'rep', 500, 30, 30),
  ('rep_5000', '5000 REP', 'Accumula 5000 REP', 'trophy', 'uncommon', 'rep', 5000, 150, 150),
  ('rep_20000', '20000 REP', 'Accumula 20000 REP', 'trophy', 'rare', 'rep', 20000, 400, 400),
  ('rep_100000', '100000 REP', 'Accumula 100000 REP', 'workspace_premium', 'epic', 'rep', 100000, 1000, 1000),
  ('xp_1000', '1000 XP', 'Accumula 1000 XP', 'bolt', 'common', 'xp', 1000, 30, 30),
  ('xp_50000', '50000 XP', 'Accumula 50000 XP', 'bolt', 'uncommon', 'xp', 50000, 120, 120),
  ('xp_500000', '500000 XP', 'Accumula 500000 XP', 'bolt', 'rare', 'xp', 500000, 350, 350),
  ('driving_score_8', 'Guida pulita', 'Raggiungi un punteggio di guida di 8.0', 'speed', 'uncommon', 'driving_score', 8, 150, 150),
  ('driving_score_95', 'Guida impeccabile', 'Raggiungi un punteggio di guida di 9.5', 'speed', 'legendary', 'driving_score', 9.5, 600, 600),
  ('territory_first', 'Prima conquista', 'Rivendica il tuo primo esagono', 'hexagon', 'common', 'territory_cells_owned', 1, 20, 20),
  ('territory_10', '10 esagoni', 'Possiedi 10 esagoni contemporaneamente', 'hexagon', 'uncommon', 'territory_cells_owned', 10, 100, 100),
  ('territory_50', '50 esagoni', 'Possiedi 50 esagoni contemporaneamente', 'hexagon', 'rare', 'territory_cells_owned', 50, 300, 300),
  ('territory_200', 'Impero territoriale', 'Possiedi 200 esagoni contemporaneamente', 'hexagon', 'epic', 'territory_cells_owned', 200, 800, 800),
  ('spot_first', 'Prima segnalazione', 'Carica la tua prima foto in Car Spotting', 'camera', 'common', 'cars_spotted', 1, 20, 20),
  ('spot_10', '10 segnalazioni', 'Carica 10 foto in Car Spotting', 'camera', 'uncommon', 'cars_spotted', 10, 100, 100),
  ('spot_50', 'Cacciatore di auto', 'Carica 50 foto in Car Spotting', 'camera', 'rare', 'cars_spotted', 50, 300, 300),
  ('spot_200', 'Fotografo leggendario', 'Carica 200 foto in Car Spotting', 'camera', 'legendary', 'cars_spotted', 200, 900, 900)
on conflict (code) do nothing;
