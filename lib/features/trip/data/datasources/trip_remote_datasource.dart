import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/trip_model.dart';

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
  }) async {
    final res = await _client.rpc('complete_trip', params: {
      'p_trip_id': tripId,
      'p_distance_km': distanceKm,
      'p_duration_seconds': durationSeconds,
      'p_avg_speed_kmh': avgSpeedKmh,
      'p_max_speed_kmh': maxSpeedKmh,
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
        .select()
        .eq('driver_id', driverId)
        .eq('status', 'completed')
        .order('started_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => TripModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<TripModel> tripById(String tripId) async {
    final row = await _client.from('trips').select().eq('id', tripId).single();
    return TripModel.fromJson(row);
  }
}
