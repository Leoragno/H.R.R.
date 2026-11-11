import 'package:flutter_test/flutter_test.dart';
import 'package:hrr_app/features/trip/domain/entities/route_point.dart';
import 'package:hrr_app/features/trip/presentation/utils/route_smoothing.dart';

void main() {
  test('simplifyRoute toglie i punti di un rettilineo, tiene la curva', () {
    // Rettilineo verso est (~1.1km), poi svolta a 90° verso nord.
    final points = <RoutePoint>[
      for (var i = 0; i <= 100; i++) RoutePoint(45.0, 9.0 + i * 0.00014),
      for (var i = 1; i <= 100; i++) RoutePoint(45.0 + i * 0.0001, 9.014),
    ];
    final out = simplifyRoute(points, 50);
    expect(out.length, lessThanOrEqualTo(50));
    expect(out.first, points.first);
    expect(out.last, points.last);
    // Lo spigolo della svolta deve sopravvivere.
    expect(out.any((p) => p.lat == 45.0 && p.lng == points[100].lng), isTrue);
  });

  test('simplifyRoute rispetta il limite anche su un tracciato a zigzag', () {
    final points = <RoutePoint>[
      for (var i = 0; i < 3000; i++)
        RoutePoint(45.0 + (i.isEven ? 0 : 0.0003), 9.0 + i * 0.0001),
    ];
    final out = simplifyRoute(points, 1400);
    expect(out.length, lessThanOrEqualTo(1400));
  });
}
