// Smoke test HEAT del percorso d'ingresso: intro, accesso (riga d'errore
// unica), registrazione, "il tuo ride", "scegli il pilota".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hrr_app/features/auth/domain/entities/app_user.dart';
import 'package:hrr_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:hrr_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:hrr_app/features/auth/presentation/screens/login_screen.dart';
import 'package:hrr_app/features/auth/presentation/screens/mascot_onboarding_screen.dart';
import 'package:hrr_app/features/auth/presentation/screens/register_screen.dart';
import 'package:hrr_app/features/auth/presentation/screens/ride_onboarding_screen.dart';
import 'package:hrr_app/features/auth/presentation/screens/splash_screen.dart';

class _FakeAuthRepo implements AuthRepository {
  int signIns = 0;

  @override
  Future<AppUser?> currentUser() async => null;

  @override
  Future<AppUser> signInWithEmail(
      {required String email, required String password}) async {
    signIns++;
    throw Exception('Invalid login credentials');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Override> _overrides(_FakeAuthRepo repo) => [
      authRepositoryProvider.overrideWithValue(repo),
      authStateProvider.overrideWith((ref) => Stream.value(null)),
      myProfileProvider.overrideWith((ref) => Stream.value(null)),
    ];

Widget _app(Widget home, _FakeAuthRepo repo) => ProviderScope(
      overrides: _overrides(repo),
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: home,
      ),
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('intro: tocco porta al login', (tester) async {
    _phone(tester);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (c, s) => const SplashScreen()),
      GoRoute(
          path: '/login',
          builder: (c, s) => const Scaffold(body: Text('LOGIN-OK'))),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: _overrides(_FakeAuthRepo()),
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('HRR'), findsOneWidget);
    expect(find.text('TOCCA PER PARTIRE'), findsOneWidget);
    await tester.tap(find.byType(SplashScreen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('LOGIN-OK'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Chiude i timer dell'intro (loop e auto-avanzamento).
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('accesso: validazione e errore server in riga', (tester) async {
    _phone(tester);
    final repo = _FakeAuthRepo();
    await tester.pumpWidget(_app(const LoginScreen(), repo));
    await tester.pump();

    expect(find.text('IN STRADA'), findsOneWidget);
    await tester.tap(find.text('ACCEDI'));
    await tester.pump();
    expect(find.text('inserisci un\'email valida.'), findsOneWidget);
    expect(repo.signIns, 0);

    await tester.enterText(find.byType(TextField).at(0), 'a@b.it');
    await tester.enterText(find.byType(TextField).at(1), 'segreto1');
    await tester.tap(find.text('ACCEDI'));
    await tester.pump();
    await tester.pump();
    expect(repo.signIns, 1);
    expect(find.text('email o password errati.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registrazione: password diverse', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const RegisterScreen(), _FakeAuthRepo()));
    await tester.pump();
    expect(find.text('PASSO 1 DI 3'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'leo');
    await tester.enterText(fields.at(1), 'leo@hrr.it');
    await tester.enterText(fields.at(2), 'segreto1');
    await tester.enterText(fields.at(3), 'segreto2');
    await tester.tap(find.text('CREA ACCOUNT'));
    await tester.pump();
    expect(find.text('le password non coincidono.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('il tuo ride e scegli il pilota', (tester) async {
    _phone(tester);
    await tester
        .pumpWidget(_app(const RideOnboardingScreen(), _FakeAuthRepo()));
    await tester.pump();
    expect(find.text('PASSO 2 DI 3'), findsOneWidget);
    expect(find.text('prima la marca'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester
        .pumpWidget(_app(const MascotOnboardingScreen(), _FakeAuthRepo()));
    await tester.pump();
    expect(find.text('CORRI CON NITRO'), findsOneWidget);
    expect(find.text('STILE · PRECISIONE'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('pilota successivo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('CORRI CON R3X'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
