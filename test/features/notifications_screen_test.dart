// Smoke test HEAT delle Notifiche: gruppi per giorno, testo ricomposto
// dalla presentazione, "segna tutte lette", stato vuoto.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hrr_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:hrr_app/features/notifications/domain/entities/app_notification.dart';
import 'package:hrr_app/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:hrr_app/features/notifications/presentation/screens/notifications_screen.dart';

class _FakeCtrl extends NotificationsController {
  _FakeCtrl(this.initial);
  final List<AppNotification> initial;

  @override
  List<AppNotification> build() => initial;

  @override
  Future<void> markRead(String id) async {
    state = [for (final n in state) n.id == id ? n.copyWith(read: true) : n];
  }

  @override
  Future<void> markAllRead() async {
    state = [for (final n in state) n.copyWith(read: true)];
  }
}

Widget _app(List<AppNotification> list) => ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        myProfileProvider.overrideWith((ref) => Stream.value(null)),
        notificationsControllerProvider.overrideWith(() => _FakeCtrl(list)),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const NotificationsScreen(),
      ),
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  test('etichette giorno e ora', () {
    final now = DateTime(2026, 11, 10, 15, 0);
    expect(notificationDayLabel(DateTime(2026, 11, 10, 8), now), 'Oggi');
    expect(notificationDayLabel(DateTime(2026, 11, 9, 23), now), 'Ieri');
    expect(notificationDayLabel(DateTime(2026, 11, 2, 9), now), '02/11');
    expect(notificationDayLabel(DateTime(2025, 12, 31), now), '31/12/2025');
    expect(notificationTimeLabel(DateTime(2026, 11, 10, 14, 48), now),
        '12 MIN');
    expect(notificationTimeLabel(DateTime(2026, 11, 10, 12, 0), now), '3 H');
    expect(notificationTimeLabel(DateTime(2026, 11, 9, 22, 40), now), '22:40');
  });

  testWidgets('lista raggruppata e segna tutte lette', (tester) async {
    _phone(tester);
    final now = DateTime.now();
    await tester.pumpWidget(_app([
      AppNotification(
        id: '1',
        type: 'territory_stolen',
        title: 'Territorio rubato',
        body: 'Tump ti ha rubato 2 pentagoni',
        read: false,
        createdAt: now.subtract(const Duration(minutes: 5)),
      ),
      AppNotification(
        id: '2',
        type: 'level_up',
        title: 'Level up',
        data: const {'level': 7},
        read: true,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ]));
    await tester.pump();

    expect(find.text('NOTIFICHE'), findsOneWidget);
    expect(find.text('OGGI'), findsOneWidget);
    expect(find.text('IERI'), findsOneWidget);
    expect(find.textContaining('2 esagoni'), findsOneWidget);
    expect(find.textContaining('livello 7'), findsOneWidget);

    await tester.tap(find.text('segna tutte lette'));
    await tester.pump();
    expect(find.text('segna tutte lette'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stato vuoto', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const []));
    await tester.pump();
    expect(find.textContaining('nessuna notifica'), findsOneWidget);
  });
}
