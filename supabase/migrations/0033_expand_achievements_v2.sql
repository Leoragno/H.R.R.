-- =====================================================================
-- HRR — Espande ancora il catalogo achievement: più scalini sulle
-- metriche già valutate (0028_expand_achievements.sql) e 4 metriche
-- nuove tratte dalle statistiche di guida persistite da complete_trip
-- (0030_persist_trip_motion_stats.sql, già aggregate lato Statistiche in
-- 0032_trip_motion_stats_totals.sql): dislivello totale, svolte totali,
-- soste totali, cambi corsia totali. Alcuni via, un po' più "simpatici"
-- nel testo (su richiesta esplicita) — restano comunque calcolati da un
-- dato reale, mai finti.
-- =====================================================================

-- ---------------------------------------------------------------------
-- evaluate_achievements — stessa firma/logica di 0028, con 4 rami in più
-- per le nuove metriche. Tutte e 4 richiedono una subquery (non sono
-- aggregati già presenti su profiles), stesso pattern già usato per
-- territory_cells_owned/cars_spotted.
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
      when 'elevation_gain_total_m' then (
        select coalesce(sum(elevation_gain_m), 0) from public.trips
        where driver_id = p_profile_id and status = 'completed'
      )
      when 'turns_total' then (
        select coalesce(sum(coalesce(turns_left, 0) + coalesce(turns_right, 0)), 0)
        from public.trips where driver_id = p_profile_id and status = 'completed'
      )
      when 'total_stops_total' then (
        select coalesce(sum(total_stops), 0) from public.trips
        where driver_id = p_profile_id and status = 'completed'
      )
      when 'lane_changes_total' then (
        select coalesce(sum(lane_changes), 0) from public.trips
        where driver_id = p_profile_id and status = 'completed'
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

-- =====================================================================
-- SEED — nuovi scalini sulle metriche esistenti + i 4 nuovi target_metric
-- sopra, stesso stile di 0003/0028.
-- =====================================================================

insert into public.achievements (code, name, description, icon, rarity, target_metric, target_value, reward_rep, reward_xp) values
  -- Km — nuovi scalini fra quelli già seminati (10/100/500/1000/10000)
  ('km_1', 'Il primo chilometro', 'Percorri il tuo primo chilometro', 'route', 'common', 'total_km', 1, 5, 5),
  ('km_50', 'Mezzo centinaio', 'Percorri 50 km in totale', 'route', 'common', 'total_km', 50, 20, 20),
  ('km_250', 'Un quarto di migliaio', 'Percorri 250 km in totale', 'route', 'uncommon', 'total_km', 250, 70, 70),
  ('km_2500', 'Tour d''Italia', 'Percorri 2500 km in totale', 'route', 'rare', 'total_km', 2500, 300, 300),
  ('km_5000', 'Attraversata continentale', 'Percorri 5000 km in totale', 'route', 'rare', 'total_km', 5000, 400, 400),
  ('km_25000', 'Giro del mondo', 'Percorri 25000 km in totale — quanto la circonferenza terrestre', 'route', 'epic', 'total_km', 25000, 900, 900),

  -- Viaggi — nuovi scalini fra quelli già seminati (1/10/50/100)
  ('trips_5', 'Cinque su cinque', 'Completa 5 viaggi', 'flag', 'common', 'total_trips', 5, 25, 25),
  ('trips_25', 'Abbonato alla strada', 'Completa 25 viaggi', 'flag', 'uncommon', 'total_trips', 25, 120, 120),
  ('trips_250', 'Instancabile', 'Completa 250 viaggi', 'flag', 'epic', 'total_trips', 250, 600, 600),
  ('trips_500', 'Chilometraggio d''acciaio', 'Completa 500 viaggi', 'flag', 'legendary', 'total_trips', 500, 1200, 1200),

  -- Livello — nuovi scalini fra quelli già seminati (5/10/25/50)
  ('level_1', 'Si parte!', 'Raggiungi il livello 1', 'military_tech', 'common', 'level', 1, 5, 5),
  ('level_15', 'A metà dell''opera', 'Raggiungi il livello 15', 'military_tech', 'uncommon', 'level', 15, 150, 150),
  ('level_35', 'Veterano', 'Raggiungi il livello 35', 'military_tech', 'rare', 'level', 35, 400, 400),
  ('level_75', 'Leggenda vivente', 'Raggiungi il livello 75', 'workspace_premium', 'epic', 'level', 75, 900, 900),
  ('level_100', 'Cento e lode', 'Raggiungi il livello 100', 'workspace_premium', 'legendary', 'level', 100, 1500, 1500),

  -- REP — nuovi scalini fra quelli già seminati (500/5000/20000/100000)
  ('rep_100', 'Prima buona fama', 'Accumula 100 REP', 'trophy', 'common', 'rep', 100, 15, 15),
  ('rep_1000', 'Reputazione solida', 'Accumula 1000 REP', 'trophy', 'uncommon', 'rep', 1000, 60, 60),
  ('rep_2500', 'Nome noto in giro', 'Accumula 2500 REP', 'trophy', 'uncommon', 'rep', 2500, 100, 100),
  ('rep_10000', 'Personaggio pubblico', 'Accumula 10000 REP', 'trophy', 'rare', 'rep', 10000, 250, 250),
  ('rep_50000', 'Celebrità locale', 'Accumula 50000 REP', 'trophy', 'epic', 'rep', 50000, 700, 700),
  ('rep_250000', 'Mito della strada', 'Accumula 250000 REP', 'workspace_premium', 'legendary', 'rep', 250000, 1500, 1500),

  -- XP — nuovi scalini fra quelli già seminati (1000/50000/500000)
  ('xp_100', 'Riscaldamento', 'Accumula 100 XP', 'bolt', 'common', 'xp', 100, 10, 10),
  ('xp_10000', 'Motore caldo', 'Accumula 10000 XP', 'bolt', 'uncommon', 'xp', 10000, 80, 80),
  ('xp_100000', 'Sotto pressione', 'Accumula 100000 XP', 'bolt', 'rare', 'xp', 100000, 250, 250),
  ('xp_250000', 'Turbo permanente', 'Accumula 250000 XP', 'bolt', 'epic', 'xp', 250000, 600, 600),
  ('xp_1000000', 'Un milione di motivi', 'Accumula 1000000 XP', 'bolt', 'legendary', 'xp', 1000000, 1500, 1500),

  -- Punteggio di guida (scala 0-10) — nuovi scalini fra quelli già
  -- seminati (8.0/9.5)
  ('driving_score_5', 'Ancora vivo', 'Raggiungi un punteggio di guida di 5.0', 'speed', 'common', 'driving_score', 5.0, 20, 20),
  ('driving_score_6', 'Si può migliorare', 'Raggiungi un punteggio di guida di 6.0', 'speed', 'common', 'driving_score', 6.0, 40, 40),
  ('driving_score_7', 'Buona media', 'Raggiungi un punteggio di guida di 7.0', 'speed', 'uncommon', 'driving_score', 7.0, 90, 90),
  ('driving_score_9', 'Quasi perfetto', 'Raggiungi un punteggio di guida di 9.0', 'speed', 'rare', 'driving_score', 9.0, 350, 350),
  ('driving_score_10', 'Chirurgo del volante', 'Raggiungi il punteggio di guida perfetto: 10.0', 'speed', 'legendary', 'driving_score', 10.0, 1200, 1200),

  -- Territorio — nuovi scalini fra quelli già seminati (1/10/50/200)
  ('territory_5', 'Primi confini', 'Possiedi 5 esagoni contemporaneamente', 'hexagon', 'common', 'territory_cells_owned', 5, 40, 40),
  ('territory_25', 'Piccolo regno', 'Possiedi 25 esagoni contemporaneamente', 'hexagon', 'uncommon', 'territory_cells_owned', 25, 150, 150),
  ('territory_100', 'Signore del territorio', 'Possiedi 100 esagoni contemporaneamente', 'hexagon', 'rare', 'territory_cells_owned', 100, 400, 400),
  ('territory_500', 'Conquistatore', 'Possiedi 500 esagoni contemporaneamente', 'hexagon', 'epic', 'territory_cells_owned', 500, 900, 900),
  ('territory_1000', 'Imperatore d''asfalto', 'Possiedi 1000 esagoni contemporaneamente', 'hexagon', 'legendary', 'territory_cells_owned', 1000, 1500, 1500),

  -- Car Spotting — nuovi scalini fra quelli già seminati (1/10/50/200)
  ('spot_5', 'Occhio allenato', 'Carica 5 foto in Car Spotting', 'camera', 'common', 'cars_spotted', 5, 40, 40),
  ('spot_25', 'Paparazzo di quartiere', 'Carica 25 foto in Car Spotting', 'camera', 'uncommon', 'cars_spotted', 25, 150, 150),
  ('spot_100', 'Collezionista seriale', 'Carica 100 foto in Car Spotting', 'camera', 'rare', 'cars_spotted', 100, 400, 400),
  ('spot_500', 'Archivio vivente', 'Carica 500 foto in Car Spotting', 'camera', 'legendary', 'cars_spotted', 500, 1200, 1200),

  -- Dislivello totale (nuova metrica: elevation_gain_total_m)
  ('elevation_100', 'Prima salita', 'Accumula 100 m di dislivello in totale', 'mountain', 'common', 'elevation_gain_total_m', 100, 20, 20),
  ('elevation_1000', 'Collinare', 'Accumula 1000 m di dislivello in totale', 'mountain', 'uncommon', 'elevation_gain_total_m', 1000, 100, 100),
  ('elevation_8848', 'Sull''Everest (in auto)', 'Accumula 8848 m di dislivello in totale — l''altezza dell''Everest, un metro alla volta', 'mountain', 'epic', 'elevation_gain_total_m', 8848, 800, 800),
  ('elevation_20000', 'Oltre le nuvole', 'Accumula 20000 m di dislivello in totale', 'mountain', 'legendary', 'elevation_gain_total_m', 20000, 1400, 1400),

  -- Svolte totali (nuova metrica: turns_total)
  ('turns_100', 'Prime curve', 'Completa 100 svolte in totale', 'steering', 'common', 'turns_total', 100, 20, 20),
  ('turns_1000', 'Il timoniere', 'Completa 1000 svolte in totale', 'steering', 'rare', 'turns_total', 1000, 300, 300),
  ('turns_5000', 'Nato per girare', 'Completa 5000 svolte in totale', 'steering', 'epic', 'turns_total', 5000, 800, 800),

  -- Soste totali (nuova metrica: total_stops_total)
  ('stops_100', 'Rosso, giallo, verde', 'Fermati 100 volte in totale (semafori, stop, code)', 'traffic', 'common', 'total_stops_total', 100, 20, 20),
  ('stops_1000', 'Il semaforista', 'Fermati 1000 volte in totale', 'traffic', 'rare', 'total_stops_total', 1000, 300, 300),
  ('stops_5000', 'Maestro dell''attesa', 'Fermati 5000 volte in totale', 'traffic', 'epic', 'total_stops_total', 5000, 800, 800),

  -- Cambi corsia totali (nuova metrica: lane_changes_total)
  ('lane_100', 'Primo sorpasso', 'Cambia corsia 100 volte in totale', 'waves', 'common', 'lane_changes_total', 100, 20, 20),
  ('lane_500', 'Slalom', 'Cambia corsia 500 volte in totale', 'waves', 'uncommon', 'lane_changes_total', 500, 120, 120),
  ('lane_2000', 'Il serpente dell''asfalto', 'Cambia corsia 2000 volte in totale', 'waves', 'rare', 'lane_changes_total', 2000, 350, 350)
on conflict (code) do nothing;
