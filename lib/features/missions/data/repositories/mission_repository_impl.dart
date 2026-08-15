import 'package:uuid/uuid.dart';

import '../../../../core/events/mission_event.dart';
import '../../domain/entities/mission.dart';
import '../../domain/entities/mission_claim.dart';
import '../../domain/entities/mission_progress.dart';
import '../../domain/entities/season.dart';
import '../../domain/repositories/mission_repository.dart';
import '../datasources/mission_remote_datasource.dart';

class MissionRepositoryImpl implements MissionRepository {
  final MissionRemoteDatasource _remote;
  final String Function() _currentProfileId;

  MissionRepositoryImpl(this._remote, this._currentProfileId);

  @override
  Future<List<Mission>> activeMissions({MissionType? type}) async {
    final missions = await _remote.activeMissions(type: type?.name);
    return missions.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<MissionProgress>> myProgress() async {
    final progress = await _remote.myProgress(_currentProfileId());
    return progress.map((p) => p.toEntity()).toList();
  }

  @override
  Future<List<String>> myClaimedMissionIds() =>
      _remote.myClaimedMissionIds(_currentProfileId());

  @override
  Stream<List<MissionProgress>> watchMyProgress() {
    return _remote
        .watchMyProgress(_currentProfileId())
        .map((rows) => rows.map((p) => p.toEntity()).toList());
  }

  @override
  Future<void> recordEvent(MissionEvent event) => recordRawEvent(
        eventType: event.type,
        payload: event.toPayload(),
        idempotencyKey: event.idempotencyKey,
      );

  @override
  Future<void> recordRawEvent({
    required String eventType,
    required Map<String, dynamic> payload,
    required String idempotencyKey,
  }) {
    return _remote.recordEvent(
        eventType: eventType, payload: payload, idempotencyKey: idempotencyKey);
  }

  @override
  Future<MissionClaim> claimMission(String missionId) async {
    final claim = await _remote.claimMission(
        missionId: missionId, idempotencyKey: _newIdempotencyKey());
    return claim.toEntity();
  }

  @override
  Future<int> secretMissionSlotCount() => _remote.secretMissionSlotCount();

  @override
  Future<Season?> activeSeason() async {
    final season = await _remote.activeSeason();
    return season?.toEntity();
  }

  static const _uuid = Uuid();
  String _newIdempotencyKey() => _uuid.v4();
}
