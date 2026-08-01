import '../entities/mission_claim.dart';
import '../repositories/mission_repository.dart';

/// Riscatta una missione completata. Orchestrazione multi-step reale (a
/// differenza di [GetActiveMissionsUseCase]): il controller Riverpod che
/// lo chiama invalida `activeMissionsProvider`/progress dopo il claim e
/// passa il [MissionClaim] risultante all'overlay di celebrazione.
class ClaimMissionUseCase {
  final MissionRepository _repository;
  const ClaimMissionUseCase(this._repository);

  Future<MissionClaim> call(String missionId) =>
      _repository.claimMission(missionId);
}
