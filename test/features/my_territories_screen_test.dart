// Smoke test di "I miei territori": zone per città ordinate per rischio,
// giorni rimasti, apertura della zona sulle singole celle.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hrr_app/features/game/domain/entities/territory_cell.dart';
import 'package:hrr_app/features/game/domain/hex_grid.dart';
import 'package:hrr_app/features/game/domain/territory_decay.dart';
import 'package:hrr_app/features/game/presentation/providers/territory_location_provider.dart';
import 'package:hrr_app/features/game/presentation/providers/territory_provider.dart';
import 'package:hrr_app/features/game/presentation/screens/my_territories_screen.dart';

void main() {
  final now = DateTime.now();
  TerritoryCell cell(int q, int ageDays) => TerritoryCell(
        coord: HexCoord(q, 0),
        ownerId: 'me',
        claimedAt: now.subtract(Duration(days: ageDays, hours: 1)),
      );

  test('giorni rimasti ed etichette', () {
    expect(territoryDaysLabel(territoryDaysLeft(cell(1, 13), now)), 'OGGI');
    expect(territoryDaysLabel(territoryDaysLeft(cell(1, 12), now)), '1 GIORNO');
    expect(territoryDaysLabel(territoryDaysLeft(cell(1, 4), now)), '9 GIORNI');
  });

  testWidgets('zone ordinate per rischio e celle espandibili', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final cells = [cell(1, 2), cell(2, 3), cell(3, 13)];
    const milano = TerritoryLocation(
        country: 'Italia', region: 'Lombardia', town: 'Milano');
    const monza = TerritoryLocation(
        country: 'Italia', region: 'Lombardia', town: 'Monza');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myTerritoriesProvider.overrideWith((ref) async => cells),
          territoryCellLocationsProvider.overrideWith((ref) async => {
                cells[0].coord.key: milano,
                cells[1].coord.key: milano,
                cells[2].coord.key: monza,
              }),
        ],
        child: const MaterialApp(home: MyTerritoriesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(tester.takeException(), isNull);
    expect(find.text('MILANO'), findsOneWidget);
    expect(find.text('2 esagoni'), findsOneWidget);
    // Monza scade oggi: è la prima zona.
    expect(
      tester.getTopLeft(find.text('MONZA')).dy,
      lessThan(tester.getTopLeft(find.text('MILANO')).dy),
    );

    await tester.tap(find.text('MILANO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('#1,0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
