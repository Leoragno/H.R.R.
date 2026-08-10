import '../../domain/entities/route_point.dart';
import '../../domain/entities/trip.dart';

/// DTO che rispecchia la tabella `trips`. La colonna `route` (PostGIS
/// geography) non viene letta direttamente: il client legge invece il
/// computed field `route_geojson` (vedi 0007_trip_route.sql), che
/// evita di dover decodificare la WKB lato Dart.
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
  final List<RoutePoint> route;

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
    this.route = const [],
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
      route: _routeFromGeoJson(json['route_geojson']),
    );
  }

  /// `route_geojson` è un LineString GeoJSON standard: coordinate in
  /// ordine [lng, lat], da invertire per ottenere i nostri RoutePoint.
  static List<RoutePoint> _routeFromGeoJson(dynamic geojson) {
    if (geojson is! Map) return const [];
    final coords = geojson['coordinates'];
    if (coords is! List) return const [];
    return [
      for (final c in coords)
        if (c is List && c.length >= 2)
          RoutePoint((c[1] as num).toDouble(), (c[0] as num).toDouble()),
    ];
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
        route: route,
      );
}
