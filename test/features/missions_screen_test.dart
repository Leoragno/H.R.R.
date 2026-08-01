// Smoke test per MissionsScreen: la UI ora legge da Riverpod (missioni,
// progresso, stagione, profilo reali via Supabase), quindi il test monta
// uno ProviderScope con override che riproducono gli stessi contenuti del
// vecchio mock — verifica che il collegamento ai provider non abbia
// cambiato nulla di visibile.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hrr_app/features/auth/domain/entities/app_user.dart';
import 'package:hrr_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:hrr_app/features/missions/domain/entities/crew_mission.dart';
import 'package:hrr_app/features/missions/domain/entities/mission.dart';
import 'package:hrr_app/features/missions/domain/entities/mission_claim.dart';
import 'package:hrr_app/features/missions/domain/entities/mission_progress.dart';
import 'package:hrr_app/features/missions/domain/entities/mission_reward.dart';
import 'package:hrr_app/features/missions/domain/entities/season.dart';
import 'package:hrr_app/features/missions/domain/repositories/mission_repository.dart';
import 'package:hrr_app/features/missions/presentation/providers/mission_provider.dart';
import 'package:hrr_app/features/missions/presentation/screens/missions_screen.dart';
import 'package:hrr_app/core/events/mission_event.dart';

final _now = DateTime.now();

Mission _mission({
  required String id,
  required String title,
  required String description,
  required double targetValue,
  MissionType type = MissionType.daily,
  int rewardRep = 60,
}) {
  return Mission(
    id: id,
    code: id,
    title: title,
    description: description,
    icon: 'route',
    type: type,
    difficulty: MissionDifficulty.normal,
    targetValue: targetValue,
    targetMetric: 'trip_completed',
    rewardXp: 0,
    rewardRep: rewardRep,
    rewardBadgeIds: const [],
    rewardTitles: const [],
    rewardProfileItems: const {},
    hidden: false,
    secret: type == MissionType.secret,
    repeatable: true,
    crewOnly: false,
    createdAt: _now,
    updatedAt: _now,
  );
}

/// Repository fake — copre solo `claimMission` (unico metodo che
/// `MissionController` invoca realmente in questi test); il resto della
/// schermata legge dai provider di sola lettura, sovrascritti
/// direttamente sotto senza passare da qui.
class _FakeMissionRepository implements MissionRepository {
  @override
  Future<MissionClaim> claimMission(String missionId) async {
    return MissionClaim(
      id: 'claim-1',
      profileId: 'user-1',
      missionId: missionId,
      claimedAt: _now,
      rewards: [
        MissionReward(
            id: 'r1',
            claimId: 'claim-1',
            type: MissionRewardType.rep,
            value: const {'amount': 60},
            grantedAt: _now),
      ],
    );
  }

  @override
  Future<List<Mission>> activeMissions({MissionType? type}) async => const [];
  @override
  Future<List<MissionProgress>> myProgress() async => const [];
  @override
  Stream<List<MissionProgress>> watchMyProgress() => const Stream.empty();
  @override
  Future<void> recordEvent(MissionEvent event) async {}
  @override
  Future<void> recordRawEvent(
      {required String eventType,
      required Map<String, dynamic> payload,
      required String idempotencyKey}) async {}
  @override
  Future<int> secretMissionSlotCount() async => 0;
  @override
  Future<List<CrewMission>> crewMissions(String crewId) async => const [];
  @override
  Future<Season?> activeSeason() async => null;
  @override
  Future<List<String>> myClaimedMissionIds() async => const [];
}

Future<void> _pumpMissionsScreen(WidgetTester tester) async {
  final dailyMissions = [
    _mission(
        id: 'm1',
        title: 'Percorri 15 km',
        description: 'Guida per almeno 15 km oggi',
        targetValue: 15),
    _mission(
        id: 'm2',
        title: 'Guida fluida',
        description: 'Completa un viaggio senza frenate brusche',
        targetValue: 1),
  ];

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        missionRepositoryProvider.overrideWithValue(_FakeMissionRepository()),
        activeMissionsProvider(type: MissionType.daily)
            .overrideWith((ref) async => dailyMissions),
        activeMissionsProvider(type: MissionType.weekly)
            .overrideWith((ref) async => const []),
        activeMissionsProvider(type: MissionType.seasonal)
            .overrideWith((ref) async => const []),
        activeMissionsProvider(type: MissionType.secret)
            .overrideWith((ref) async => const []),
        myMissionProgressProvider.overrideWith(
          (ref) => Stream.value([
            MissionProgress(
                profileId: 'user-1',
                missionId: 'm1',
                currentValue: 8.4,
                completed: false,
                updatedAt: _now),
            MissionProgress(
                profileId: 'user-1',
                missionId: 'm2',
                currentValue: 1,
                completed: true,
                completedAt: _now,
                updatedAt: _now),
          ]),
        ),
        myClaimedMissionIdsProvider.overrideWith((ref) async => const []),
        secretMissionSlotCountProvider.overrideWith((ref) async => 6),
        activeSeasonProvider.overrideWith(
          (ref) async => Season(
              id: 's1',
              code: 'season_3',
              name: 'Neon Horizon',
              startsAt: _now,
              endsAt: _now.add(const Duration(days: 12))),
        ),
        myProfileProvider.overrideWith(
          (ref) => Stream.value(
            const AppUser(
              id: 'user-1',
              username: 'leo',
              displayName: 'Leonardo',
              level: 18,
              xp: 12400,
              rep: 900,
              title: 'Street Legend',
            ),
          ),
        ),
      ],
      child: const MaterialApp(home: MissionsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('MissionsScreen si costruisce e mostra il tab Daily di default',
      (tester) async {
    await _pumpMissionsScreen(tester);

    expect(find.text('MISSIONS'), findsOneWidget);
    expect(find.text('Percorri 15 km'), findsOneWidget);
  });

  testWidgets(
      'Cambiare tab mostra Season con Battle Pass e Secret con missioni nascoste',
      (tester) async {
    await _pumpMissionsScreen(tester);

    await tester.tap(find.text('SEASON'));
    await tester.pumpAndSettle();
    expect(find.text('BATTLE PASS · TRACK'), findsOneWidget);

    await tester.tap(find.text('SECRET'));
    await tester.pumpAndSettle();
    expect(find.text('??? MISSIONE SEGRETA'), findsWidgets);
  });

  testWidgets(
      'RISCATTA su una missione pronta mostra la celebrazione e CONTINUA la chiude',
      (tester) async {
    await _pumpMissionsScreen(tester);

    await tester.tap(find.text('RISCATTA').first);
    await tester.pumpAndSettle();
    expect(find.text('MISSION COMPLETE'), findsOneWidget);

    await tester.tap(find.text('CONTINUA'));
    await tester.pumpAndSettle();
    expect(find.text('MISSION COMPLETE'), findsNothing);
  });
}
