import 'dart:math' as math;

import '../../domain/entities/route_point.dart';

/// Riduce il tracciato a [maxPoints] punti al massimo con Douglas-Peucker:
/// toglie i punti quasi allineati (rettilinei) e tiene quelli che danno
/// forma alle curve. La tolleranza parte da 2m e raddoppia finché il
/// risultato non sta nel limite. Primo e ultimo punto restano sempre.
List<RoutePoint> simplifyRoute(List<RoutePoint> points, int maxPoints) {
  if (points.length <= maxPoints || points.length < 3) {
    return List.of(points);
  }
  var tolerance = 2.0;
  var result = _douglasPeucker(points, tolerance);
  while (result.length > maxPoints) {
    tolerance *= 2;
    result = _douglasPeucker(points, tolerance);
  }
  return result;
}

List<RoutePoint> _douglasPeucker(List<RoutePoint> points, double toleranceM) {
  // Proiezione equirettangolare locale in metri: su distanze di pochi km
  // l'errore è trascurabile rispetto alla tolleranza.
  final refLat = points.first.lat * math.pi / 180;
  const mPerDeg = 111320.0;
  final mPerDegLng = mPerDeg * math.cos(refLat);
  final xs = [for (final p in points) p.lng * mPerDegLng];
  final ys = [for (final p in points) p.lat * mPerDeg];

  final keep = List<bool>.filled(points.length, false);
  keep[0] = true;
  keep[points.length - 1] = true;

  // Iterativo (stack esplicito): niente ricorsione profonda su tracciati
  // lunghi e quasi dritti.
  final stack = <(int, int)>[(0, points.length - 1)];
  while (stack.isNotEmpty) {
    final (start, end) = stack.removeLast();
    if (end - start < 2) continue;
    final ax = xs[start], ay = ys[start];
    final dx = xs[end] - ax, dy = ys[end] - ay;
    final lenSq = dx * dx + dy * dy;
    var maxDist = -1.0;
    var maxIdx = start;
    for (var i = start + 1; i < end; i++) {
      final px = xs[i] - ax, py = ys[i] - ay;
      double dist;
      if (lenSq == 0) {
        dist = math.sqrt(px * px + py * py);
      } else {
        final t = ((px * dx + py * dy) / lenSq).clamp(0.0, 1.0);
        final ex = px - t * dx, ey = py - t * dy;
        dist = math.sqrt(ex * ex + ey * ey);
      }
      if (dist > maxDist) {
        maxDist = dist;
        maxIdx = i;
      }
    }
    if (maxDist > toleranceM) {
      keep[maxIdx] = true;
      stack
        ..add((start, maxIdx))
        ..add((maxIdx, end));
    }
  }

  return [
    for (var i = 0; i < points.length; i++)
      if (keep[i]) points[i]
  ];
}

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
