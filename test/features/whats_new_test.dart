// Novità HEAT: 7 slide, avanti/indietro, nome utente sull'ultima, chiusura;
// la prima apertura le mostra una volta sola.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hrr_app/features/auth/domain/entities/app_user.dart';
import 'package:hrr_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:hrr_app/features/home/presentation/widgets/whats_new_overlay.dart';

const _me = AppUser(
  id: 'me',
  username: 'leo',
  displayName: 'Leo',
  level: 5,
  xp: 100,
  rep: 10,
  title: '',
  vehicleBrand: 'Fiat',
  vehicleModel: 'Panda',
  country: 'IT',
  mascotId: 'nitro',
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _pump(WidgetTester tester, {bool once = false}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [myProfileProvider.overrideWith((ref) => Stream.value(_me))],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                once ? maybeShowWhatsNew(context) : showWhatsNew(context),
            child: const Text('apri'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('apri'));
  await _settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('scorre le 7 slide e chiude con IN STRADA', (tester) async {
    await _pump(tester);
    expect(find.text('NOVITÀ · 1 / 7'), findsOneWidget);
    expect(find.text('SCOPRI'), findsOneWidget);

    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text(i == 0 ? 'SCOPRI' : 'AVANTI'));
      await _settle(tester);
    }
    expect(find.text('NOVITÀ · 7 / 7'), findsOneWidget);
    expect(find.text('IN STRADA, LEO'), findsOneWidget);
    expect(find.text('salta'), findsNothing);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await _settle(tester);
    expect(find.text('NOVITÀ · 6 / 7'), findsOneWidget);

    await tester.tap(find.text('salta'));
    await _settle(tester);
    expect(find.textContaining('NOVITÀ'), findsNothing);
  });

  testWidgets('prima apertura: una volta sola', (tester) async {
    await _pump(tester, once: true);
    expect(find.text('NOVITÀ · 1 / 7'), findsOneWidget);
    await tester.tap(find.text('salta'));
    await _settle(tester);

    await tester.tap(find.text('apri'));
    await _settle(tester);
    expect(find.textContaining('NOVITÀ'), findsNothing);
  });
}
