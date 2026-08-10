import 'package:equatable/equatable.dart';

/// Bounding box geografica, indipendente da MapLibre (la conversione da
/// `LatLngBounds` avviene nel widget mappa, unico punto che importa
/// maplibre_gl in questa feature).
///
/// Arrotondata a una griglia di ~0.01° (circa 1 km) apposta: due bounding
/// box quasi identiche (l'utente ha spostato la mappa di pochi metri)
/// diventano la stessa chiave — è la base della cache "non rifare la
/// stessa richiesta Overpass/Waze per un pan trascurabile".
class RadarBounds extends Equatable {
  final double south;
  final double west;
  final double north;
  final double east;

  const RadarBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  static const _gridDeg = 0.01;

  factory RadarBounds.quantized({
    required double south,
    required double west,
    required double north,
    required double east,
  }) {
    double floor(double v) => (v / _gridDeg).floor() * _gridDeg;
    double ceil(double v) => (v / _gridDeg).ceil() * _gridDeg;
    return RadarBounds(
      south: floor(south),
      west: floor(west),
      north: ceil(north),
      east: ceil(east),
    );
  }

  @override
  List<Object?> get props => [south, west, north, east];
}
