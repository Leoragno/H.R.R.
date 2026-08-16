import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/route_point.dart';
import '../models/trip_model.dart';

/// Colonna calcolata (0007_trip_route.sql) da includere in ogni select
/// che debba mostrare il percorso (cronologia/dettaglio viaggio).
const _selectWithRoute = '*, route_geojson';

String? _routeToWkt(List<RoutePoint> route) {
  if (route.length < 2) return null;
  final coords = route.map((p) => '${p.lng} ${p.lat}').join(', ');
  return 'LINESTRING($coords)';
}

/// Unico punto della feature Trip che importa supabase_flutter.
class TripRemoteDatasource {
  final SupabaseClient _client;

  TripRemoteDatasource(this._client);

  Future<TripModel> startTrip({required String driverId, String? carId}) async {
    final row = await _client
        .from('trips')
        .insert({
          'driver_id': driverId,
          'car_id': carId,
          'started_at': DateTime.now().toUtc().toIso8601String(),
          'status': 'active',
        })
        .select()
        .single();
    return TripModel.fromJson(row);
  }

  Future<TripModel> completeTrip({
    required String tripId,
    required double distanceKm,
    required int durationSeconds,
    required double avgSpeedKmh,
    required double maxSpeedKmh,
    List<RoutePoint> route = const [],
    double? jerkRmsMs3,
    int brakingSoftCount = 0,
    int brakingHardCount = 0,
    double? brakingJerkAvgMs3,
    int turnsCount = 0,
    double? turnGyroStddevAvg,
    int totalStops = 0,
    int stoppedSeconds = 0,
    int accelThenBrakeCount = 0,
    double? gpsFixHz,
    double? gyroHz,
    double? elevationGainM,
    double? maxAltitudeM,
    double? maxAccelerationMs2,
    double? maxDecelerationMs2,
    double? zeroToHundredSeconds,
    double? peakGForce,
    int turnsLeft = 0,
    int turnsRight = 0,
    int laneChanges = 0,
    double? maxCorneringSpeedKmh,
  }) async {
    final res = await _client.rpc('complete_trip', params: {
      'p_trip_id': tripId,
      'p_distance_km': distanceKm,
      'p_duration_seconds': durationSeconds,
      'p_avg_speed_kmh': avgSpeedKmh,
      'p_max_speed_kmh': maxSpeedKmh,
      'p_route_wkt': _routeToWkt(route),
      'p_jerk_rms_ms3': jerkRmsMs3,
      'p_braking_soft_count': brakingSoftCount,
      'p_braking_hard_count': brakingHardCount,
      'p_braking_jerk_avg_ms3': brakingJerkAvgMs3,
      'p_turns_count': turnsCount,
      'p_turn_gyro_stddev_avg': turnGyroStddevAvg,
      'p_total_stops': totalStops,
      'p_stopped_seconds': stoppedSeconds,
      'p_accel_then_brake_count': accelThenBrakeCount,
      'p_gps_fix_hz': gpsFixHz,
      'p_gyro_hz': gyroHz,
      'p_elevation_gain_m': elevationGainM,
      'p_max_altitude_m': maxAltitudeM,
      'p_max_acceleration_ms2': maxAccelerationMs2,
      'p_max_deceleration_ms2': maxDecelerationMs2,
      'p_zero_to_hundred_seconds': zeroToHundredSeconds,
      'p_peak_g_force': peakGForce,
      'p_turns_left': turnsLeft,
      'p_turns_right': turnsRight,
      'p_lane_changes': laneChanges,
      'p_max_cornering_speed_kmh': maxCorneringSpeedKmh,
    });

    final Map<String, dynamic> row = res is List
        ? Map<String, dynamic>.from(res.first as Map)
        : Map<String, dynamic>.from(res as Map);
    return TripModel.fromJson(row);
  }

  Future<void> discardTrip(String tripId) async {
    await _client.from('trips').update({
      'status': 'discarded',
      'ended_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', tripId);
  }

  Future<List<TripModel>> recentTrips(String driverId, {int limit = 20}) async {
    final rows = await _client
        .from('trips')
        .select(_selectWithRoute)
        .eq('driver_id', driverId)
        .eq('status', 'completed')
        .order('started_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => TripModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<TripModel> tripById(String tripId) async {
    final row = await _client
        .from('trips')
        .select(_selectWithRoute)
        .eq('id', tripId)
        .single();
    return TripModel.fromJson(row);
  }
}
