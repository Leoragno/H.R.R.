import 'package:equatable/equatable.dart';

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
  final TripStatus status;

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
    required this.status,
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
        status,
      ];
}
