// Smoke test HEAT di Missioni (righe, RISCUOTI, segrete "???") e
// Achievement (griglia, contatore, avanzamento dei bloccati).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hrr_app/core/events/mission_event.dart';
import 'package:hrr_app/features/achievements/domain/entities/achievement.dart';
import 'package:hrr_app/features/achievements/presentation/providers/achievement_provider.dart';
import 'package:hrr_app/features/achievements/presentation/screens/achievements_screen.dart';
import 'package:hrr_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:hrr_app/features/missions/domain/entities/mission.dart';
import 'package:hrr_app/features/missions/domain/entities/mission_claim.dart';
import 'package:hrr_app/features/missions/domain/entities/mission_progress.dart';
import 'package:hrr_app/features/missions/domain/entities/season.dart';
import 'package:hrr_app/features/missions/domain/repositories/mission_repository.dart';
import 'package:hrr_app/features/missions/presentation/providers/mission_provider.dart';
import 'package:hrr_app/features/missions/presentation/screens/missions_screen.dart';

final _now = DateTime.now();

Mission _m(String id, String title, MissionType type,
        {double target = 10, int xp = 50}) =>
    Mission(
      id: id,
      code: id,
      title: title,
      description: '',
      icon: 'route',
      type: type,
      difficulty: MissionDifficulty.normal,
      targetValue: target,
      targetMetric: 'km',
      rewardXp: xp,
      rewardRep: 0,
      rewardBadgeIds: const [],
      rewardTitles: const [],
      rewardProfileItems: const {},
      hidden: false,
      secret: type == MissionType.secret,
      repeatable: false,
      endsAt: type == MissionType.secret
          ? null
          : _now.add(const Duration(hours: 5, minutes: 30)),
      createdAt: _now,
      updatedAt: _now,
    );

class _FakeMissions implements MissionRepository {
  final missions = [
    _m('a', 'guida 10 km', MissionType.daily),
    _m('b', 'una guida di notte', MissionType.daily, target: 1, xp: 100),
    _m('s', 'alba al volante', MissionType.secret, target: 1),
  ];

  @override
  Future<List<Mission>> activeMissions({MissionType? type}) async =>
      missions.where((m) => type == null || m.type == type).toList();
  @override
  Future<void> ensureCurrentPeriodMissions() async {}
  @override
  Future<int> secretMissionSlotCount() async => 3;
  @override
  Future<Season?> activeSeason() async => null;
  @override
  Future<List<String>> myClaimedMissionIds() async => const [];
  @override
  Future<List<MissionProgress>> myProgress() async => const [];
  @override
  Stream<List<MissionProgress>> watchMyProgress() => Stream.value(const []);
  @override
  Future<MissionClaim> claimMission(String missionId) =>
      throw UnimplementedError();
  @override
  Future<void> recordEvent(MissionEvent event) async {}
  @override
  Future<void> recordRawEvent({
    required String eventType,
    required Map<String, dynamic> payload,
    required String idempotencyKey,
  }) async {}
}

Widget _app(Widget home, List<Override> overrides) => ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        myProfileProvider.overrideWith((ref) => Stream.value(null)),
        ...overrides,
      ],
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
  testWidgets('missioni: progresso, RISCUOTI e segrete nascoste',
      (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const MissionsScreen(), [
      missionRepositoryProvider.overrideWithValue(_FakeMissions()),
      myMissionProgressProvider.overrideWith((ref) => Stream.value([
            MissionProgress(
              profileId: 'me',
              missionId: 'a',
              currentValue: 4,
              completed: false,
              updatedAt: _now,
            ),
            MissionProgress(
              profileId: 'me',
              missionId: 'b',
              currentValue: 1,
              completed: true,
              updatedAt: _now,
            ),
          ])),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('MISSIONI'), findsOneWidget);
    expect(find.text('4/10'), findsOneWidget);
    expect(find.text('RISCUOTI'), findsOneWidget);
    expect(find.textContaining('NUOVE TRA 5H'), findsOneWidget);
    // Da riscattare in cima.
    expect(
      tester.getTopLeft(find.text('una guida di notte')).dy,
      lessThan(tester.getTopLeft(find.text('guida 10 km')).dy),
    );

    await tester.tap(find.text('SEGRETE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('alba al volante'), findsOneWidget);
    expect(find.textContaining('missione segreta'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('achievement: contatore e card', (tester) async {
    _phone(tester);
    Achievement a(String id, String name, {DateTime? at}) => Achievement(
          id: id,
          code: id,
          name: name,
          description: 'desc $name',
          icon: 'route',
          rarity: AchievementRarity.rare,
          targetMetric: 'total_km',
          targetValue: 100,
          rewardRep: 0,
          rewardXp: 50,
          rewardBadgeIds: const [],
          rewardTitles: const [],
          earnedAt: at,
        );
    await tester.pumpWidget(_app(const AchievementsScreen(), [
      myAchievementsProvider.overrideWith((ref) async => [
            a('1', 'Cento km'),
            a('2', 'Primo viaggio', at: _now),
          ]),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('PRIMO VIAGGIO'), findsOneWidget);
    expect(find.text('CENTO KM'), findsOneWidget);
    // Ottenuto prima del bloccato.
    expect(
      tester.getTopLeft(find.text('PRIMO VIAGGIO')).dx,
      lessThan(tester.getTopLeft(find.text('CENTO KM')).dx),
    );
    expect(tester.takeException(), isNull);
  });
}
