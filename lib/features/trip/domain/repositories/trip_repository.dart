import '../entities/route_point.dart';
import '../entities/trip.dart';

/// Contratto Trip. Presentation/domain dipendono solo da questa interfaccia.
abstract class TripRepository {
  Future<Trip> startTrip({required String driverId, String? carId});

  /// Chiama la RPC `complete_trip`: il server ricalcola XP/REP e il
  /// punteggio di guida dalla telemetria inviata (mai fidarsi di un valore
  /// calcolato dal client). `route` viene salvato lato server solo se
  /// contiene almeno 2 punti. Gli aggregati opzionali alimentano il
  /// punteggio di guida (vedi 0024_drive_score.sql) — `null`/assenti se il
  /// dato non è stato calcolabile lato client (es. mai un jerk valido).
  Future<Trip> completeTrip({
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
  });

  Future<void> discardTrip(String tripId);

  Future<List<Trip>> recentTrips(String driverId, {int limit = 20});

  Future<Trip> tripById(String tripId);
}
