import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entities/mission_claim.dart';
import '../../domain/usecases/claim_mission_usecase.dart';
import 'mission_provider.dart';

part 'mission_controller.g.dart';

/// Riscatto missione. Orchestrazione: chiama la RPC via [ClaimMissionUseCase],
/// poi invalida progresso/lista missioni cosi la UI riflette subito
/// l'esito (claim consumato, reward assegnati) senza aspettare il giro
/// realtime.
@riverpod
class MissionController extends _$MissionController {
  @override
  FutureOr<void> build() {
    // no-op initial state
  }

  Future<MissionClaim?> claim(String missionId) async {
    state = const AsyncLoading();
    final useCase = ClaimMissionUseCase(ref.read(missionRepositoryProvider));

    MissionClaim? result;
    state = await AsyncValue.guard(() async {
      result = await useCase(missionId);
    });

    ref.invalidate(activeMissionsProvider);
    ref.invalidate(myMissionProgressProvider);
    ref.invalidate(myClaimedMissionIdsProvider);

    return result;
  }
}
