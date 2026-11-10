import 'package:flutter_test/flutter_test.dart';

import 'package:hrr_app/features/progression/domain/progression.dart';

void main() {
  group('livelli', () {
    test('need(l) = 1500 + 150·l', () {
      expect(xpNeededForLevel(1), 1650);
      expect(xpNeededForLevel(14), 3600);
    });

    test('XP totali 0 -> LV 1 a inizio barra', () {
      final p = levelProgressFromTotalXp(0);
      expect(p.level, 1);
      expect(p.xpInLevel, 0);
      expect(p.xpNeeded, 1650);
      expect(p.fraction, 0);
    });

    test('esattamente la soglia porta al livello successivo', () {
      final p = levelProgressFromTotalXp(1650);
      expect(p.level, 2);
      expect(p.xpInLevel, 0);
      expect(p.xpNeeded, 1800);
    });

    test('totale cumulativo coerente con need(l)', () {
      // LV 14 con 2340 XP nel livello (come nel prototipo).
      var total = 2340;
      for (var l = 1; l < 14; l++) {
        total += xpNeededForLevel(l);
      }
      final p = levelProgressFromTotalXp(total);
      expect(p.level, 14);
      expect(p.xpInLevel, 2340);
      expect(p.xpNeeded, 3600);
      expect(p.title, 'PRO');
    });

    test('titoli per fascia', () {
      expect(levelTitle(4), 'ROOKIE');
      expect(levelTitle(5), 'STREET');
      expect(levelTitle(10), 'PRO');
      expect(levelTitle(20), 'ELITE');
      expect(levelTitle(30), 'LEGGENDA');
      expect(levelTitle(45), 'MITO');
    });
  });

  group('notte e HEAT', () {
    test('notte = dalle 22 alle 6', () {
      expect(isNightTime(DateTime(2026, 1, 1, 22)), isTrue);
      expect(isNightTime(DateTime(2026, 1, 1, 3)), isTrue);
      expect(isNightTime(DateTime(2026, 1, 1, 6)), isFalse);
      expect(isNightTime(DateTime(2026, 1, 1, 21, 59)), isFalse);
    });

    test('HEAT parte da 1, +1 per guida notturna, −1 diurna, 1..5', () {
      DateTime n(int d) => DateTime(2026, 1, d, 23);
      DateTime g(int d) => DateTime(2026, 1, d, 12);
      expect(heatFromTripStarts(const []), 1);
      expect(heatFromTripStarts([n(1), n(2)]), 3);
      expect(heatFromTripStarts([n(1), n(2), n(3), n(4), n(5), n(6)]), 5);
      expect(heatFromTripStarts([n(1), n(2), g(3)]), 2);
      expect(heatFromTripStarts([g(1), g(2)]), 1);
    });

    test('VOLT: ±2 per guida', () {
      DateTime n(int d) => DateTime(2026, 1, d, 23);
      DateTime g(int d) => DateTime(2026, 1, d, 12);
      expect(heatFromTripStarts([n(1)], volt: true), 3);
      expect(heatFromTripStarts([n(1), n(2), g(3)], volt: true), 3);
    });

    test('moltiplicatore = 1 + (heat−1)·0.25', () {
      expect(heatMultiplier(1), 1.0);
      expect(heatMultiplier(5), 2.0);
    });
  });

  group('serie di giorni', () {
    final today = DateTime(2026, 3, 10, 18);

    test('nessuna guida -> 0', () {
      expect(streakDays(const [], today), 0);
    });

    test('giorni consecutivi fino a oggi', () {
      expect(
        streakDays([
          DateTime(2026, 3, 10, 8),
          DateTime(2026, 3, 9, 20),
          DateTime(2026, 3, 9, 7),
          DateTime(2026, 3, 8, 12),
          DateTime(2026, 3, 6, 12),
        ], today),
        3,
      );
    });

    test('ultima guida ieri: la serie è ancora viva', () {
      expect(
          streakDays([DateTime(2026, 3, 9), DateTime(2026, 3, 8)], today), 2);
    });

    test('buco di due giorni: serie persa', () {
      expect(streakDays([DateTime(2026, 3, 8)], today), 0);
    });

    test('bonus serie = 10/giorno, max 70', () {
      expect(streakBonusXp(3), 30);
      expect(streakBonusXp(12), 70);
    });
  });

  test('grado FLOW', () {
    expect(flowGrade(92), 'S');
    expect(flowGrade(85), 'S');
    expect(flowGrade(75), 'A');
    expect(flowGrade(65), 'B');
    expect(flowGrade(40), 'C');
  });
}
