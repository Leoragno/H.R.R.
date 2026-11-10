// Smoke test della Classifica HEAT: hero del leader, righe, sheet metrica.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hrr_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:hrr_app/features/leaderboard/domain/entities/leaderboard_entry.dart';
import 'package:hrr_app/features/leaderboard/domain/repositories/leaderboard_repository.dart';
import 'package:hrr_app/features/leaderboard/presentation/providers/leaderboard_provider.dart';
import 'package:hrr_app/features/leaderboard/presentation/screens/leaderboard_screen.dart';

LeaderboardEntry _e(int rank, String name, int xp, {String? mascot}) =>
    LeaderboardEntry(
      rank: rank,
      profileId: 'id$rank',
      username: name,
      displayName: name,
      level: 10 - rank,
      periodXp: xp,
      periodRep: 0,
      totalKm: 100.0 * rank,
      topSpeedKmh: 120,
      mascotId: mascot,
      country: rank.isEven ? 'IT' : 'FR',
    );

class _FakeRepo implements LeaderboardRepository {
  _FakeRepo(this.list);
  final List<LeaderboardEntry> list;

  @override
  Future<List<LeaderboardEntry>> global({
    required LeaderboardMetric metric,
    required LeaderboardPeriod period,
    int limit = 50,
  }) async =>
      list;
}

void main() {
  Future<void> pump(WidgetTester tester, List<LeaderboardEntry> list) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          leaderboardRepositoryProvider.overrideWithValue(_FakeRepo(list)),
        ],
        // Animazioni ridotte: la mascotte fluttua all'infinito.
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const LeaderboardScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('leader, righe e cambio metrica', (tester) async {
    await pump(tester, [
      _e(1, 'marco.r', 12840, mascot: 'r3x'),
      _e(2, 'giulia.v', 9300, mascot: 'spark'),
      _e(3, 'luca', 4100),
    ]);
    expect(tester.takeException(), isNull);
    expect(find.text('BLACKLIST #1 · DA BATTERE'), findsOneWidget);
    expect(find.text('12.840 XP · LV 9'), findsOneWidget);
    expect(find.text('giulia.v'), findsOneWidget);

    await tester.tap(find.text('XP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('DISTANZA TOTALE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(find.text('100 km · LV 9'), findsOneWidget);
  });

  testWidgets('classifica vuota', (tester) async {
    await pump(tester, const []);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('nessun pilota'), findsOneWidget);
  });
}
