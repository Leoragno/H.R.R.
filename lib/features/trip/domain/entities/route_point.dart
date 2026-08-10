import 'package:equatable/equatable.dart';

/// Punto del percorso percorso durante un viaggio (lat/lng). Usato sia
/// live (TripLiveController, mentre traccia) sia come dato persistito
/// (Trip.route, letto da `trips.route` via il computed field
/// `route_geojson`).
class RoutePoint extends Equatable {
  final double lat;
  final double lng;
  const RoutePoint(this.lat, this.lng);

  @override
  List<Object?> get props => [lat, lng];
}
