-- =====================================================================
-- HRR — Trip economy (Fase 2): XP/REP centralizzati + realtime + storage
-- =====================================================================

-- ---------------------------------------------------------------------
-- xp_events -> profiles: unico punto che può mutare profiles.xp/rep/level
-- (vedi ARCHITECTURE.md §4). Un trigger evita che due dispositivi in
-- corsa contemporaneamente sovrascrivano lo stesso valore letto stale.
-- ---------------------------------------------------------------------
create or replace function public.apply_xp_event() returns trigger
language plpgsql security definer as $$
declare
  v_new_xp bigint;
begin
  update public.profiles
  set xp = xp + NEW.xp_delta,
      rep = rep + NEW.rep_delta,
      updated_at = now()
  where id = NEW.profile_id
  returning xp into v_new_xp;

  update public.profiles
  set level = greatest(1, floor(sqrt(v_new_xp / 100.0))::int + 1)
  where id = NEW.profile_id;

  return NEW;
end;
$$;

create trigger trg_apply_xp_event
  after insert on public.xp_events
  for each row execute function public.apply_xp_event();

-- Necessaria per far scrivere xp_events da missioni/badge lato client;
-- complete_trip() sotto passa comunque da SECURITY DEFINER e non dipende
-- da questa policy per funzionare.
create policy "xp_events_insert_self" on public.xp_events
  for insert with check (auth.uid() = profile_id);

-- ---------------------------------------------------------------------
-- complete_trip: entrypoint atomico chiamato a fine corsa. Calcola XP/REP
-- lato server dai dati di telemetria inviati (non fida mai di un xp/rep
-- calcolato dal client), aggiorna trip/profilo e scrive l'evento di audit
-- in un'unica transazione.
--
-- (2026-08-01: rimosso l'update su `cars` che era qui — irraggiungibile
-- da quando il Garage è stato tolto dal client, il quale non passa più
-- `car_id` a startTrip(); usava anche una formula di livello divergente
-- (/50.0) mai riconciliata con quella di apply_xp_event sopra (/100.0).
-- Se `complete_trip` è già stato applicato al tuo progetto, rilancia solo
-- questo blocco `create or replace function` — è idempotente, non serve
-- rieseguire l'intera 0002.)
-- ---------------------------------------------------------------------
create or replace function public.complete_trip(
  p_trip_id uuid,
  p_distance_km numeric,
  p_duration_seconds int,
  p_avg_speed_kmh numeric,
  p_max_speed_kmh numeric
) returns public.trips
language plpgsql security definer as $$
declare
  v_trip public.trips;
  v_xp int;
  v_rep int;
  v_suspicious boolean;
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

  update public.trips set
    ended_at = now(),
    distance_km = p_distance_km,
    duration_seconds = p_duration_seconds,
    avg_speed_kmh = p_avg_speed_kmh,
    max_speed_kmh = p_max_speed_kmh,
    xp_earned = v_xp,
    rep_earned = v_rep,
    status = 'completed'
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

  return v_trip;
end;
$$;

grant execute on function public.complete_trip to authenticated;

-- ---------------------------------------------------------------------
-- Storage: foto Garage (car-photos/{owner_id}/{car_id}.jpg)
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('car-photos', 'car-photos', true)
on conflict (id) do nothing;

create policy "car_photos_public_read" on storage.objects
  for select using (bucket_id = 'car-photos');

create policy "car_photos_owner_write" on storage.objects
  for insert with check (
    bucket_id = 'car-photos' and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "car_photos_owner_update" on storage.objects
  for update using (
    bucket_id = 'car-photos' and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "car_photos_owner_delete" on storage.objects
  for delete using (
    bucket_id = 'car-photos' and auth.uid()::text = (storage.foldername(name))[1]
  );

-- ---------------------------------------------------------------------
-- Realtime: profiles e cars mancavano dalla pubblicazione — senza questo
-- gli stream .stream() lato Flutter su Garage e sull'HUD pilota non
-- ricevono mai un aggiornamento live dopo un viaggio.
-- ---------------------------------------------------------------------
alter publication supabase_realtime add table public.profiles;
alter publication supabase_realtime add table public.cars;
