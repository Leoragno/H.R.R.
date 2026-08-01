import '../../domain/entities/trip.dart';

/// DTO che rispecchia la tabella `trips` (colonna `route` PostGIS esclusa
/// di proposito: non è consumata lato client in questa fase).
class TripModel {
  final String id;
  final String driverId;
  final String? carId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double distanceKm;
  final int durationSeconds;
  final double? avgSpeedKmh;
  final double? maxSpeedKmh;
  final int xpEarned;
  final int repEarned;
  final TripStatus status;

  const TripModel({
    required this.id,
    required this.driverId,
    this.carId,
    required this.startedAt,
    this.endedAt,
    required this.distanceKm,
    required this.durationSeconds,
    this.avgSpeedKmh,
    this.maxSpeedKmh,
    required this.xpEarned,
    required this.repEarned,
    required this.status,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      carId: json['car_id'] as String?,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] == null
          ? null
          : DateTime.parse(json['ended_at'] as String),
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      avgSpeedKmh: (json['avg_speed_kmh'] as num?)?.toDouble(),
      maxSpeedKmh: (json['max_speed_kmh'] as num?)?.toDouble(),
      xpEarned: json['xp_earned'] as int? ?? 0,
      repEarned: json['rep_earned'] as int? ?? 0,
      status: tripStatusFromString(json['status'] as String? ?? 'active'),
    );
  }

  Trip toEntity() => Trip(
        id: id,
        driverId: driverId,
        carId: carId,
        startedAt: startedAt,
        endedAt: endedAt,
        distanceKm: distanceKm,
        durationSeconds: durationSeconds,
        avgSpeedKmh: avgSpeedKmh,
        maxSpeedKmh: maxSpeedKmh,
        xpEarned: xpEarned,
        repEarned: repEarned,
        status: status,
      );
}
