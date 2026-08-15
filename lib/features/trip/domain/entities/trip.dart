import 'package:equatable/equatable.dart';

import 'route_point.dart';

enum TripStatus { active, completed, discarded }

TripStatus tripStatusFromString(String value) {
  return TripStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => TripStatus.active,
  );
}

/// Viaggio — entità pura di dominio.
class Trip extends Equatable {
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
  // Punteggio di guida 0-100, calcolato server-side (0024_drive_score.sql)
  // da fluidità/anticipo/curve/efficienza — mai da velocità, tempo o
  // distanza. `null` se il viaggio è troppo corto per un valore onesto.
  final int? drivingScore;
  final TripStatus status;
  final List<RoutePoint> route;

  const Trip({
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
    this.drivingScore,
    required this.status,
    this.route = const [],
  });

  @override
  List<Object?> get props => [
        id,
        driverId,
        carId,
        startedAt,
        endedAt,
        distanceKm,
        durationSeconds,
        avgSpeedKmh,
        maxSpeedKmh,
        xpEarned,
        repEarned,
        drivingScore,
        status,
        route,
      ];
}
