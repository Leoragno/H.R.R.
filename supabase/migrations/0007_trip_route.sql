-- =====================================================================
-- HRR — Percorso viaggio: popola finalmente `trips.route` (PostGIS,
-- già presente da 0001_init.sql ma mai scritta/letta) e la espone al
-- client come GeoJSON tramite un computed field PostgREST.
-- =====================================================================

-- ---------------------------------------------------------------------
-- complete_trip: aggiunge p_route_wkt (LINESTRING(lng lat, ...), SRID
-- 4326) opzionale. Il nuovo parametro cambia la firma della funzione
-- (Postgres identifica una funzione anche dai tipi degli argomenti, non
-- solo dal nome): "create or replace" quindi NON sostituisce la vecchia
-- versione a 5 parametri, la affianca come overload. Va droppata
-- esplicitamente, altrimenti resta ambigua per PostgREST/i comandi
-- "grant" senza lista argomenti.
-- ---------------------------------------------------------------------
drop function if exists public.complete_trip(uuid, numeric, int, numeric, numeric);

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

  return v_trip;
end;
$$;

grant execute on function public.complete_trip(uuid, numeric, int, numeric, numeric, text) to authenticated;

-- ---------------------------------------------------------------------
-- route_geojson: computed field PostgREST su public.trips, così il
-- client può leggere `select=*,route_geojson` (senza parentesi: sono
-- un "computed field" scalare, non una relazione da incorporare) senza
-- doversi occupare della codifica WKB del tipo geography lato Dart.
-- ---------------------------------------------------------------------
create or replace function public.route_geojson(t public.trips) returns jsonb
language sql stable as $$
  select case when t.route is null then null else ST_AsGeoJSON(t.route)::jsonb end;
$$;

grant execute on function public.route_geojson(public.trips) to authenticated, anon;
