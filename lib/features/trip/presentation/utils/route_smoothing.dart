import '../../domain/entities/route_point.dart';

/// Interpola una curva morbida (Catmull-Rom) attraverso i punti GPS grezzi,
/// solo ai fini del disegno — i punti sorgente (usati per distanza/stat)
/// restano quelli originali. Attenua gli angoli vivi dovuti allo spacing dei
/// fix GPS senza bisogno di un servizio di map-matching esterno.
List<RoutePoint> smoothRouteForDisplay(
  List<RoutePoint> points, {
  int subdivisions = 6,
}) {
  if (points.length < 3) return points;

  final result = <RoutePoint>[points.first];
  for (var i = 0; i < points.length - 1; i++) {
    final p0 = points[i == 0 ? 0 : i - 1];
    final p1 = points[i];
    final p2 = points[i + 1];
    final p3 = points[i + 2 < points.length ? i + 2 : points.length - 1];

    for (var s = 1; s <= subdivisions; s++) {
      result.add(_catmullRom(p0, p1, p2, p3, s / subdivisions));
    }
  }
  return result;
}

RoutePoint _catmullRom(
    RoutePoint p0, RoutePoint p1, RoutePoint p2, RoutePoint p3, double t) {
  final t2 = t * t;
  final t3 = t2 * t;
  double interp(double v0, double v1, double v2, double v3) {
    return 0.5 *
        ((2 * v1) +
            (-v0 + v2) * t +
            (2 * v0 - 5 * v1 + 4 * v2 - v3) * t2 +
            (-v0 + 3 * v1 - 3 * v2 + v3) * t3);
  }

  return RoutePoint(
    interp(p0.lat, p1.lat, p2.lat, p3.lat),
    interp(p0.lng, p1.lng, p2.lng, p3.lng),
  );
}
