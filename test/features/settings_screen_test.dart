// Smoke test HEAT delle Impostazioni: gruppi, accento (selezione reale,
// bloccati non selezionabili), username modificabile in linea.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hrr_app/core/theme/accent_provider.dart';
import 'package:hrr_app/core/theme/app_colors.dart';
import 'package:hrr_app/features/auth/domain/entities/app_user.dart';
import 'package:hrr_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:hrr_app/features/settings/presentation/screens/settings_screen.dart';

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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppColor.setAccent(HeatAccent.corallo.color);
  });

  testWidgets('impostazioni: gruppi, accento e username', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(_me)),
      myProfileProvider.overrideWith((ref) => Stream.value(_me)),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const SettingsScreen(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('IMPOSTAZIONI'), findsOneWidget);
    for (final g in ['PROFILO', 'GUIDA', 'ACCOUNT']) {
      expect(find.text(g), findsOneWidget);
    }
    expect(find.text('@leo'), findsOneWidget);
    expect(find.text('Panda'), findsOneWidget);
    expect(find.text('Italia'), findsOneWidget);

    // Bloccato: resta l'accento attuale.
    await tester.tap(find.byKey(const ValueKey('accent_lime')));
    await tester.pump();
    expect(container.read(accentProvider), HeatAccent.corallo);
    expect(find.textContaining('pass di guida'), findsOneWidget);

    // Username in linea.
    await tester.tap(find.text('leo'));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.text('annulla'));
    await tester.pump();
    expect(find.byType(TextField), findsNothing);

    expect(tester.takeException(), isNull);
  });
}
