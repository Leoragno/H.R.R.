-- =====================================================================
-- HRR — Notifiche "extra": level up e record personali (velocità e
-- distanza) su un singolo giro. Stesso principio delle altre: nessun
-- dato fittizio, si aggancia a colonne/logiche già esistenti e reali
-- (profiles.level ricalcolato da apply_xp_event, trips.max_speed_kmh/
-- distance_km scritti da complete_trip).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Level up: apply_xp_event (0002) ricalcola profiles.level ad ogni
-- xp_events insert ma non notificava mai il salto. Si legge il livello
-- precedente prima dell'update per confrontarlo col nuovo.
-- ---------------------------------------------------------------------
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

  v_new_level := greatest(1, floor(sqrt(v_new_xp / 100.0))::int + 1);

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

-- ---------------------------------------------------------------------
-- Record personali: complete_trip (0007) già calcola v_suspicious per
-- l'anti-cheat — riusato qui per non premiare record ottenuti con GPS
-- spoofato o mezzi non validi. Confronto contro il massimo storico
-- dell'utente sugli altri viaggi completati (escluso quello corrente).
-- ---------------------------------------------------------------------
create or replace function public.complete_trip(
  p_trip_id uuid,
  p_distance_km numeric,
  p_duration_seconds int,
  p_avg_speed_kmh numeric,
  p_max_speed_kmh numeric,
  p_route_wkt text default null
) returns public.trips
language plpgsql security definer as $$
declare
  v_trip public.trips;
  v_xp int;
  v_rep int;
  v_suspicious boolean;
  v_prev_best_speed numeric;
  v_prev_best_distance numeric;
begin
  select * into v_trip from public.trips where id = p_trip_id for update;

  if v_trip is null then
    raise exception 'Trip % non trovato', p_trip_id;
  end if;
  if v_trip.driver_id <> auth.uid() then
    raise exception 'Non autorizzato a completare questo viaggio';
  end if;
  if v_trip.status <> 'active' then
    raise exception 'Viaggio già finalizzato';
  end if;

  -- Anti-cheat: una velocità media sostenuta oltre questa soglia non è
  -- guida su strada reale (spoofing GPS o altro mezzo) -> nessun premio,
  -- ma il viaggio resta salvato nello storico dell'utente.
  v_suspicious := p_avg_speed_kmh > 160 or p_distance_km > 1500;

  if v_suspicious or p_distance_km <= 0 then
    v_xp := 0;
    v_rep := 0;
  else
    v_xp := greatest(5, round(p_distance_km * 12)::int);
    v_rep := round(p_distance_km * 3)::int;
  end if;

  select max(max_speed_kmh), max(distance_km)
    into v_prev_best_speed, v_prev_best_distance
    from public.trips
    where driver_id = v_trip.driver_id and status = 'completed' and id <> p_trip_id;

  update public.trips set
    ended_at = now(),
    distance_km = p_distance_km,
    duration_seconds = p_duration_seconds,
    avg_speed_kmh = p_avg_speed_kmh,
    max_speed_kmh = p_max_speed_kmh,
    xp_earned = v_xp,
    rep_earned = v_rep,
    status = 'completed',
    route = case when p_route_wkt is not null
      then ST_GeogFromText('SRID=4326;' || p_route_wkt)
      else route end
  where id = p_trip_id
  returning * into v_trip;

  if v_xp > 0 or v_rep > 0 then
    insert into public.xp_events (profile_id, source, source_id, xp_delta, rep_delta)
    values (v_trip.driver_id, 'trip', v_trip.id, v_xp, v_rep);
  end if;

  update public.profiles set
    total_km = total_km + p_distance_km,
    total_trips = total_trips + 1
  where id = v_trip.driver_id;

  if not v_suspicious and v_prev_best_speed is not null and p_max_speed_kmh > v_prev_best_speed then
    insert into public.notifications (profile_id, type, title, body, data)
      values (v_trip.driver_id, 'speed_record', 'Nuovo record di velocità! 🏎️',
        'Hai toccato ' || p_max_speed_kmh || ' km/h, il tuo nuovo record personale.',
        jsonb_build_object('trip_id', v_trip.id, 'max_speed_kmh', p_max_speed_kmh));
  end if;

  if not v_suspicious and v_prev_best_distance is not null and p_distance_km > v_prev_best_distance then
    insert into public.notifications (profile_id, type, title, body, data)
      values (v_trip.driver_id, 'distance_record', 'Nuovo record di distanza! 🛣️',
        'Hai percorso ' || p_distance_km || ' km in un solo giro, il tuo record personale.',
        jsonb_build_object('trip_id', v_trip.id, 'distance_km', p_distance_km));
  end if;

  return v_trip;
end;
$$;

grant execute on function public.complete_trip(uuid, numeric, int, numeric, numeric, text) to authenticated;
