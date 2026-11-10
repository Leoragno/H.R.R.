import 'package:flutter_test/flutter_test.dart';

import 'package:hrr_app/features/trip/domain/driver_archetype.dart';
import 'package:hrr_app/features/trip/domain/entities/trip.dart';

DrivingStyleInput _input({
  double km = 15,
  int seconds = 20 * 60,
  double? avg = 45,
  int? score = 65,
  double? accel = 2.0,
  double? z100,
  double peakG = 0.3,
  double? corner = 25,
  int turns = 10,
  int lanes = 3,
  int brakes = 15,
  int stops = 4,
  int stopped = 90,
  double elev = 40,
}) =>
    DrivingStyleInput(
      distanceKm: km,
      durationSeconds: seconds,
      avgSpeedKmh: avg,
      drivingScore: score,
      maxAccelerationMs2: accel,
      zeroToHundredSeconds: z100,
      peakGForce: peakG,
      maxCorneringSpeedKmh: corner,
      turns: turns,
      laneChanges: lanes,
      brakingEvents: brakes,
      totalStops: stops,
      stoppedSeconds: stopped,
      elevationGainM: elev,
    );

DriverArchetype? _match(DrivingStyleInput i) =>
    matchDriverArchetype(i)?.archetype;

void main() {
  test('viaggio troppo corto -> nessun abbinamento', () {
    expect(_match(_input(km: 1.2)), isNull);
    expect(_match(_input(seconds: 120)), isNull);
  });

  test('viaggio vecchio senza telemetria -> nessun input', () {
    final trip = Trip(
      id: 't',
      driverId: 'u',
      startedAt: DateTime(2026),
      distanceKm: 20,
      durationSeconds: 1800,
      xpEarned: 0,
      repEarned: 0,
      status: TripStatus.completed,
    );
    expect(DrivingStyleInput.fromTrip(trip), isNull);
  });

  test('guida media senza estremi -> Brian (equilibrato)', () {
    expect(_match(_input()), DriverArchetype.brianOConner);
  });

  test('partenze brucianti con guida pulita -> Toretto', () {
    expect(_match(_input(accel: 6.5, z100: 6.5, score: 70)),
        DriverArchetype.dominicToretto);
  });

  test('stesse partenze ma guida sporca -> mai Toretto', () {
    final m = _match(_input(accel: 6.5, z100: 6.5, score: 30, brakes: 80));
    expect(m, isNot(DriverArchetype.dominicToretto));
    expect(m, DriverArchetype.mrBean);
  });

  test('picco G da impatto esclude i profili sportivi', () {
    final m = _match(_input(accel: 6.5, z100: 6.5, score: 80, peakG: 1.2));
    expect(m, isNot(DriverArchetype.dominicToretto));
    expect(m, isNot(DriverArchetype.hanLue));
  });

  test('curve veloci e pulite -> Han', () {
    expect(_match(_input(peakG: 0.75, corner: 65, turns: 20, score: 72)),
        DriverArchetype.hanLue);
  });

  test('fluido a velocità sostenuta -> Il Driver', () {
    expect(_match(_input(score: 96, avg: 72, brakes: 5, peakG: 0.2)),
        DriverArchetype.theDriver);
  });

  test('lento e dolcissimo -> Hoke', () {
    expect(_match(_input(score: 92, avg: 25, peakG: 0.15, brakes: 8)),
        DriverArchetype.hokeColburn);
  });

  test('autostrada senza soste -> Saetta McQueen', () {
    expect(
        _match(_input(km: 80, seconds: 3000, avg: 100, stops: 0, score: 60)),
        DriverArchetype.saettaMcQueen);
  });

  test('traffico stop&go -> Fantozzi', () {
    expect(
        _match(_input(km: 5, seconds: 1800, avg: 10, stops: 15, stopped: 900)),
        DriverArchetype.ugoFantozzi);
  });

  test('i motivi mostrati vengono dai dati reali', () {
    final m = matchDriverArchetype(_input(accel: 6.5, z100: 6.5, score: 70))!;
    expect(m.reasons, contains('0-100 in 6.5 s'));
  });

  group('affinità', () {
    test('il primo delle affinità è il pilota abbinato', () {
      final m = matchDriverArchetype(_input(accel: 5.5, z100: 7.5, score: 80))!;
      expect(m.affinities.first.key, m.archetype);
      expect(m.affinities.length, greaterThanOrEqualTo(3));
    });

    test('guida sporca: niente profili sportivi fra le affinità', () {
      final a = archetypeAffinities(_input(score: 30, accel: 6, z100: 6))!;
      expect(a.containsKey(DriverArchetype.dominicToretto), isFalse);
      expect(a.containsKey(DriverArchetype.hanLue), isFalse);
    });

    test('ogni pilota ha sigla e regola', () {
      for (final a in DriverArchetype.values) {
        expect(a.monogram, isNotEmpty);
        expect(a.howToGet, isNotEmpty);
      }
    });
  });

  group('storico piloti', () {
    const sm = DriverArchetype.saettaMcQueen;
    const d = DriverArchetype.theDriver;
    const mb = DriverArchetype.mrBean;

    test('meno di 10 viaggi: in analisi', () {
      final h = buildPilotHistory([sm, d, sm]);
      expect(h.ready, isFalse);
      expect(h.main, sm);
    });

    test('pilota principale = più frequente negli ultimi 10', () {
      final h = buildPilotHistory([sm, sm, d, sm, sm, mb, sm, d, mb, mb, d, d, d]);
      expect(h.ready, isTrue);
      expect(h.lastTen.length, 10);
      expect(h.main, sm);
      expect(h.tally[sm], 5);
      expect(h.isTie, isFalse);
      // Lo storico completo conta per la maestria.
      expect(h.totals[d], 5);
      expect(h.mastery(d), 2);
    });

    test('pareggio: testa a testa, vince il più recente', () {
      final h = buildPilotHistory([d, sm, d, sm, d, sm, d, sm, d, sm]);
      expect(h.main, d);
      expect(h.tiedWith, sm);
    });

    test('maestria a 1/3/6/10/15 viaggi', () {
      expect(masteryLevel(0), 0);
      expect(masteryLevel(1), 1);
      expect(masteryLevel(3), 2);
      expect(masteryLevel(9), 3);
      expect(masteryLevel(15), 5);
    });

    test('nessun viaggio', () {
      final h = buildPilotHistory(const []);
      expect(h.main, isNull);
      expect(h.collected, 0);
    });
  });
}
