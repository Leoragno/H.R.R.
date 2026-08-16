-- =====================================================================
-- HRR — Aggrega su tutti i viaggi completati dell'utente le statistiche
-- di guida persistite da complete_trip (0030_persist_trip_motion_stats.sql):
-- oggi visibili solo viaggio per viaggio in "Dettaglio viaggio"
-- (TripDetailScreen._MotionStatsGrid), mai in un totale/record personale
-- nella tab Statistiche. Sola lettura, self-only (auth.uid(), nessun
-- parametro profilo — stesso principio di "self-only" già usato per
-- achievement/missioni: niente modo di leggere l'aggregato di un altro).
-- =====================================================================

create or replace function public.trip_motion_stats_totals()
returns table (
  elevation_gain_total_m numeric,
  max_altitude_m numeric,
  peak_g_force numeric,
  max_acceleration_ms2 numeric,
  max_deceleration_ms2 numeric,
  best_zero_to_hundred_seconds numeric,
  max_cornering_speed_kmh numeric,
  turns_total bigint,
  lane_changes_total bigint,
  braking_events_total bigint,
  total_stops_total bigint,
  stopped_seconds_total bigint
)
language sql stable security definer as $$
  select
    sum(elevation_gain_m),
    max(max_altitude_m),
    max(peak_g_force),
    max(max_acceleration_ms2),
    max(abs(max_deceleration_ms2)),
    min(zero_to_hundred_seconds),
    max(max_cornering_speed_kmh),
    sum(coalesce(turns_left, 0) + coalesce(turns_right, 0)),
    sum(lane_changes),
    sum(braking_events),
    sum(total_stops),
    sum(stopped_seconds)
  from public.trips
  where driver_id = auth.uid() and status = 'completed';
$$;

grant execute on function public.trip_motion_stats_totals() to authenticated;
