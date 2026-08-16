import '../../domain/entities/route_point.dart';
import '../../domain/entities/trip.dart';
import '../../domain/repositories/trip_repository.dart';
import '../datasources/trip_remote_datasource.dart';

class TripRepositoryImpl implements TripRepository {
  final TripRemoteDatasource _remote;

  TripRepositoryImpl(this._remote);

  @override
  Future<Trip> startTrip({required String driverId, String? carId}) async {
    final trip = await _remote.startTrip(driverId: driverId, carId: carId);
    return trip.toEntity();
  }

  @override
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
  }) async {
    final trip = await _remote.completeTrip(
      tripId: tripId,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      avgSpeedKmh: avgSpeedKmh,
      maxSpeedKmh: maxSpeedKmh,
      route: route,
      jerkRmsMs3: jerkRmsMs3,
      brakingSoftCount: brakingSoftCount,
      brakingHardCount: brakingHardCount,
      brakingJerkAvgMs3: brakingJerkAvgMs3,
      turnsCount: turnsCount,
      turnGyroStddevAvg: turnGyroStddevAvg,
      totalStops: totalStops,
      stoppedSeconds: stoppedSeconds,
      accelThenBrakeCount: accelThenBrakeCount,
      gpsFixHz: gpsFixHz,
      gyroHz: gyroHz,
      elevationGainM: elevationGainM,
      maxAltitudeM: maxAltitudeM,
      maxAccelerationMs2: maxAccelerationMs2,
      maxDecelerationMs2: maxDecelerationMs2,
      zeroToHundredSeconds: zeroToHundredSeconds,
      peakGForce: peakGForce,
      turnsLeft: turnsLeft,
      turnsRight: turnsRight,
      laneChanges: laneChanges,
      maxCorneringSpeedKmh: maxCorneringSpeedKmh,
    );
    return trip.toEntity();
  }

  @override
  Future<void> discardTrip(String tripId) => _remote.discardTrip(tripId);

  @override
  Future<List<Trip>> recentTrips(String driverId, {int limit = 20}) async {
    final trips = await _remote.recentTrips(driverId, limit: limit);
    return trips.map((t) => t.toEntity()).toList();
  }

  @override
  Future<Trip> tripById(String tripId) async =>
      (await _remote.tripById(tripId)).toEntity();
}
