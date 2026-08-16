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

  // Statistiche di guida persistite da complete_trip (0030_persist_trip_
  // motion_stats.sql) — prima esistevano solo lato client, effimere,
  // mostrate una volta sola in TripSummaryScreen appena finita la corsa.
  // Tutti null sui viaggi completati prima di questa migration.
  final double? elevationGainM;
  final double? maxAltitudeM;
  final double? maxAccelerationMs2;
  final double? maxDecelerationMs2;
  final double? zeroToHundredSeconds;
  final double? peakGForce;
  final int? turnsLeft;
  final int? turnsRight;
  final int? laneChanges;
  final double? maxCorneringSpeedKmh;
  final int? brakingEvents;
  final int? totalStops;
  final int? stoppedSeconds;

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
    this.elevationGainM,
    this.maxAltitudeM,
    this.maxAccelerationMs2,
    this.maxDecelerationMs2,
    this.zeroToHundredSeconds,
    this.peakGForce,
    this.turnsLeft,
    this.turnsRight,
    this.laneChanges,
    this.maxCorneringSpeedKmh,
    this.brakingEvents,
    this.totalStops,
    this.stoppedSeconds,
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
        elevationGainM,
        maxAltitudeM,
        maxAccelerationMs2,
        maxDecelerationMs2,
        zeroToHundredSeconds,
        peakGForce,
        turnsLeft,
        turnsRight,
        laneChanges,
        maxCorneringSpeedKmh,
        brakingEvents,
        totalStops,
        stoppedSeconds,
      ];
}
