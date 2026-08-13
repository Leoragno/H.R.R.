import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:hrr_app/features/game/domain/hex_grid.dart';

// Distanza approssimata in metri fra due punti lat/lon (Haversine),
// sufficiente per verificare scale/proiezioni locali su scala urbana.
double _metersBetween(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

void main() {
  group('HexGrid.centerOf', () {
    test('è la vera inversa di cellOf per una griglia di celle', () {
      for (var r = -20; r <= 20; r += 3) {
        for (var q = -20; q <= 20; q += 3) {
          final cell = HexCoord(q, r);
          final (lat, lon) = HexGrid.centerOf(cell);
          expect(HexGrid.cellOf(lat, lon), cell,
              reason: 'centerOf($cell) deve ricadere dentro $cell stessa');
        }
      }
    });

    test('celle adiacenti sullo stesso rigo distano ~hexMeters*1.732 m', () {
      final a = HexGrid.centerOf(const HexCoord(0, 0));
      final b = HexGrid.centerOf(const HexCoord(1, 0));
      final dist = _metersBetween(a.$1, a.$2, b.$1, b.$2);
      expect(dist, closeTo(HexGrid.hexMeters * 1.732, 0.5));
    });
  });

  group('HexGrid.polygonOf', () {
    test('produce 6 vertici equidistanti dal centro al raggio atteso', () {
      const cell = HexCoord(4, -7);
      final (centerLat, centerLon) = HexGrid.centerOf(cell);
      final corners = HexGrid.polygonOf(cell);
      expect(corners.length, 6);

      const expectedRadius = HexGrid.hexMeters * 0.94;
      for (final (lat, lon) in corners) {
        final dist = _metersBetween(centerLat, centerLon, lat, lon);
        expect(dist, closeTo(expectedRadius, 0.5));
      }
    });

    test('poligoni di celle adiacenti non si sovrappongono e restano vicini',
        () {
      // Due celle adiacenti: i vertici più vicini fra i due poligoni non
      // devono sovrapporsi (gap positivo, lo 0.94× lascia un margine) né
      // essere distanti quanto il raggio pieno (altrimenti la proiezione
      // sarebbe disallineata dalla spaziatura reale della griglia).
      final polyA = HexGrid.polygonOf(const HexCoord(0, 0));
      final polyB = HexGrid.polygonOf(const HexCoord(1, 0));

      var minGap = double.infinity;
      for (final pa in polyA) {
        for (final pb in polyB) {
          final d = _metersBetween(pa.$1, pa.$2, pb.$1, pb.$2);
          if (d < minGap) minGap = d;
        }
      }

      expect(minGap, greaterThan(0));
      expect(minGap, lessThan(HexGrid.hexMeters * 0.2));
    });
  });
}
