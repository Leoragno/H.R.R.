import '../entities/trip.dart';

/// Contratto Trip. Presentation/domain dipendono solo da questa interfaccia.
abstract class TripRepository {
  Future<Trip> startTrip({required String driverId, String? carId});

  /// Chiama la RPC `complete_trip`: il server ricalcola XP/REP dalla
  /// telemetria inviata (mai fidarsi di un xp/rep calcolato dal client).
  Future<Trip> completeTrip({
    required String tripId,
    required double distanceKm,
    required int durationSeconds,
    required double avgSpeedKmh,
    required double maxSpeedKmh,
  });

  Future<void> discardTrip(String tripId);

  Future<List<Trip>> recentTrips(String driverId, {int limit = 20});

  Future<Trip> tripById(String tripId);
}
