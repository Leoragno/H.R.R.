// Smoke test per la schermata di riepilogo "ricca" (mappa, distribuzione
// velocità, grafici Speed/Elevation Over Time): verifica che si costruisca
// e renderizzi senza eccezioni con dati sintetici — il flusso GPS reale
// non è testabile in un ambiente automatizzato senza permesso di
// geolocalizzazione (vedi trip_live_provider.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hrr_app/features/trip/domain/entities/trip.dart';
import 'package:hrr_app/features/trip/presentation/providers/trip_live_provider.dart';
import 'package:hrr_app/features/trip/presentation/screens/trip_summary_screen.dart';

Trip _fakeTrip() {
  final start = DateTime(2026, 8, 3, 10, 0);
  return Trip(
    id: 'trip-1',
    driverId: 'user-1',
    startedAt: start,
    endedAt: start.add(const Duration(minutes: 18)),
    distanceKm: 12.4,
    durationSeconds: 18 * 60,
    avgSpeedKmh: 41,
    maxSpeedKmh: 98,
    xpEarned: 120,
    repEarned: 30,
    status: TripStatus.completed,
  );
}

List<RoutePoint> _fakeRoute() => const [
      RoutePoint(45.4642, 9.1900),
      RoutePoint(45.4650, 9.1950),
      RoutePoint(45.4700, 9.2000),
      RoutePoint(45.4750, 9.2100),
    ];

List<TelemetrySample> _fakeSamples() => [
      for (var i = 0; i < 40; i++)
        TelemetrySample(
          i * 30,
          20 + 70 * (i / 40),
          120 + 15 * (i % 5),
        ),
    ];

/// TripSummaryScreen legge il riepilogo da lastTripSummaryControllerProvider
/// (non più da un `extra` di GoRouter, perso quando il router si
/// riaggiorna — vedi trip_live_provider.dart) quindi il test lo inietta
/// tramite override invece che via costruttore.
class _StubSummaryController extends LastTripSummaryController {
  _StubSummaryController(this._summary);
  final TripSummary? _summary;
  @override
  TripSummary? build() => _summary;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'TripSummaryScreen si costruisce con dati sintetici senza eccezioni',
      (tester) async {
    final summary = TripSummary(
      trip: _fakeTrip(),
      routePoints: _fakeRoute(),
      samples: _fakeSamples(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lastTripSummaryControllerProvider
              .overrideWith(() => _StubSummaryController(summary)),
        ],
        child: const MaterialApp(home: TripSummaryScreen()),
      ),
    );
    // Non pumpAndSettle: NeonCtaButton anima la sheen in loop infinito e
    // flutter_animate usa timer per i delay — bastano due pump (come nel
    // pattern già usato in car_spotting_test.dart).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('DRIVE COMPLETED'), findsOneWidget);

    // ListView non costruisce i figli fuori viewport: scorriamo passo per
    // passo per verificare anche le sezioni più in basso.
    final listFinder = find.byType(Scrollable).first;
    for (final label in [
      'Statistiche del trip',
      'Speed Over Time',
      'Elevation Over Time',
      'Elimina trip',
    ]) {
      await tester.scrollUntilVisible(find.text(label), 300,
          scrollable: listFinder);
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('TripSummaryScreen regge una corsa senza campioni di telemetria',
      (tester) async {
    final summary = TripSummary(trip: _fakeTrip(), routePoints: const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lastTripSummaryControllerProvider
              .overrideWith(() => _StubSummaryController(summary)),
        ],
        child: const MaterialApp(home: TripSummaryScreen()),
      ),
    );
    // Non pumpAndSettle: NeonCtaButton anima la sheen in loop infinito e
    // flutter_animate usa timer per i delay — bastano due pump (come nel
    // pattern già usato in car_spotting_test.dart).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('DRIVE COMPLETED'), findsOneWidget);

    final listFinder = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Elimina trip'), 400,
        scrollable: listFinder);
    // Nessun campione -> niente sezione elevazione.
    expect(find.text('Elevation Over Time'), findsNothing);
    expect(find.text('Elimina trip'), findsOneWidget);
  });
}
