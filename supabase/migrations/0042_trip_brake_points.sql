-- =====================================================================
-- HRR — Frenate brusche sul percorso (handoff HEAT: Risultato/Dettaglio
-- "route with harsh-brake segments").
--
-- Il client sa dove ha frenato (ultimo fix GPS al momento della frenata)
-- e lo invia dopo complete_trip. Solo dati di presentazione: non entrano
-- in XP, FLOW o classifiche, quindi basta un controllo di proprietà.
-- Additiva: nessun dato esistente cambia.
-- =====================================================================

alter table public.trips add column if not exists brake_points jsonb;

create or replace function public.set_trip_brake_points(p_trip_id uuid, p_points jsonb)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if jsonb_typeof(p_points) <> 'array' or jsonb_array_length(p_points) > 200 then
    raise exception 'invalid_points';
  end if;
  -- Ogni elemento: [lat, lng] numerici e plausibili.
  if exists (
    select 1 from jsonb_array_elements(p_points) e
     where jsonb_typeof(e) <> 'array'
        or jsonb_array_length(e) <> 2
        or jsonb_typeof(e->0) <> 'number' or jsonb_typeof(e->1) <> 'number'
        or abs((e->>0)::numeric) > 90 or abs((e->>1)::numeric) > 180
  ) then
    raise exception 'invalid_points';
  end if;

  update public.trips
     set brake_points = p_points
   where id = p_trip_id
     and driver_id = auth.uid()
     and status = 'completed';
end;
$$;

revoke all on function public.set_trip_brake_points(uuid, jsonb) from public, anon;
grant execute on function public.set_trip_brake_points(uuid, jsonb) to authenticated;
