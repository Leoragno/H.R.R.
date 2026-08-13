// Verifica l'avviso "risparmio energetico attivo" di TripLiveScreen: la
// vera lettura battery_plus non è testabile in automatico (richiede stato
// di sistema reale, vedi trip_live_provider.dart), ma la logica di
// trigger/dedup del popup (ref.listen sulla transizione a
// batterySaverActive == true) sì, iniettando lo stato via uno stub del
// controller — stesso pattern di _StubSummaryController in
// trip_summary_screen_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hrr_app/features/trip/presentation/providers/trip_live_provider.dart';
import 'package:hrr_app/features/trip/presentation/screens/trip_live_screen.dart';

class _StubTripLiveController extends TripLiveController {
  // Parte già "tracking": TripLiveScreen.initState chiama startTrip() solo
  // se lo stato è idle, altrimenti non tocca la logica GPS reale.
  @override
  TripLiveState build() =>
      const TripLiveState(status: TripLiveStatus.tracking, tripId: 'trip-1');

  @override
  Future<void> startTrip() async {}

  void debugSetState(TripLiveState next) => state = next;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'TripLiveScreen mostra l\'avviso risparmio energetico quando si attiva',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripLiveControllerProvider.overrideWith(_StubTripLiveController.new),
        ],
        child: const MaterialApp(home: TripLiveScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Risparmio energetico attivo'), findsNothing);

    final container =
        ProviderScope.containerOf(tester.element(find.byType(TripLiveScreen)));
    final stub =
        container.read(tripLiveControllerProvider.notifier) as _StubTripLiveController;

    stub.debugSetState(
      container.read(tripLiveControllerProvider).copyWith(batterySaverActive: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Risparmio energetico attivo'), findsOneWidget);

    await tester.tap(find.text('Ho capito'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Risparmio energetico attivo'), findsNothing);
  });

  testWidgets(
      'TripLiveScreen non ripete l\'avviso se batterySaverActive resta true',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripLiveControllerProvider.overrideWith(_StubTripLiveController.new),
        ],
        child: const MaterialApp(home: TripLiveScreen()),
      ),
    );
    await tester.pump();

    final container =
        ProviderScope.containerOf(tester.element(find.byType(TripLiveScreen)));
    final stub =
        container.read(tripLiveControllerProvider.notifier) as _StubTripLiveController;

    stub.debugSetState(
      container.read(tripLiveControllerProvider).copyWith(batterySaverActive: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Risparmio energetico attivo'), findsOneWidget);

    // Dismesso dall'utente, poi un altro rebuild a batterySaverActive
    // invariato (true): niente riapertura, solo una vera transizione
    // false->true la giustifica (vedi ref.listen in TripLiveScreen).
    await tester.tap(find.text('Ho capito'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    stub.debugSetState(
      container.read(tripLiveControllerProvider).copyWith(currentSpeedKmh: 42),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Risparmio energetico attivo'), findsNothing);
  });
}
