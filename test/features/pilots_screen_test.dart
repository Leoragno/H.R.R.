// Smoke test di "Che pilota sei": pilota attuale, striscia, collezione con
// i bloccati come "???" e foglio di dettaglio con COME SI OTTIENE.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hrr_app/features/pilots/presentation/screens/pilots_screen.dart';
import 'package:hrr_app/features/progression/presentation/progression_providers.dart';
import 'package:hrr_app/features/trip/domain/driver_archetype.dart';

void main() {
  Future<void> pump(WidgetTester tester, PilotHistory h) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pilotHistoryProvider.overrideWithValue(h)],
        child: const MaterialApp(home: PilotsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('pilota pronto, collezione e dettaglio', (tester) async {
    final h = buildPilotHistory([
      for (var i = 0; i < 7; i++) DriverArchetype.theDriver,
      DriverArchetype.baby,
      DriverArchetype.baby,
      DriverArchetype.hokeColburn,
    ]);
    await pump(tester, h);

    expect(tester.takeException(), isNull);
    expect(find.text('IL TUO PILOTA'), findsWidgets);
    expect(find.text('Il Driver'), findsWidgets);
    // 11 piloti, 3 visti -> 8 bloccati.
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('3/11'), 200, scrollable: list);
    expect(find.text('3/11'), findsOneWidget);

    final baby = find.text('Baby').last;
    await tester.ensureVisible(baby);
    await tester.pumpAndSettle();
    await tester.tap(baby);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.text('COME SI OTTIENE'), findsOneWidget);
    expect(find.text(DriverArchetype.baby.howToGet), findsOneWidget);
    // Baby non è il principale: perk descritto ma non attivo.
    expect(find.text(DriverArchetype.baby.perk), findsOneWidget);
    expect(find.text('SINERGIA'), findsNothing);
  });

  testWidgets('perk attivo sul pilota principale con 2 stelle', (tester) async {
    final h = buildPilotHistory(
        [for (var i = 0; i < 3; i++) DriverArchetype.hokeColburn]);
    await pump(tester, h);
    expect(tester.takeException(), isNull);
    expect(find.text('PERK ATTIVO · ${DriverArchetype.hokeColburn.perk}'),
        findsOneWidget);
  });

  test('ogni pilota ha un perk', () {
    for (final a in DriverArchetype.values) {
      expect(a.perk, isNotEmpty);
    }
  });

  testWidgets('nessun viaggio: tutto bloccato, nessuna eccezione',
      (tester) async {
    await pump(tester, buildPilotHistory(const []));
    expect(tester.takeException(), isNull);
    expect(find.text('NESSUN VIAGGIO ANCORA'), findsOneWidget);
    expect(find.text('???'), findsWidgets);
  });
}
