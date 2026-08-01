import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/crew_mission_model.dart';
import '../models/mission_claim_model.dart';
import '../models/mission_model.dart';
import '../models/mission_progress_model.dart';
import '../models/mission_reward_model.dart';
import '../models/season_model.dart';

/// Unico punto della feature Missions che importa supabase_flutter.
class MissionRemoteDatasource {
  final SupabaseClient _client;

  MissionRemoteDatasource(this._client);

  Future<List<MissionModel>> activeMissions({String? type}) async {
    var query = _client.from('missions').select();
    if (type != null) {
      query = query.eq('type', type);
    }
    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((r) => MissionModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<MissionProgressModel>> myProgress(String profileId) async {
    final rows = await _client
        .from('mission_progress')
        .select()
        .eq('profile_id', profileId);
    return (rows as List)
        .map((r) => MissionProgressModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> myClaimedMissionIds(String profileId) async {
    final rows = await _client
        .from('mission_claims')
        .select('mission_id')
        .eq('profile_id', profileId);
    return (rows as List)
        .map((r) => (r as Map<String, dynamic>)['mission_id'] as String)
        .toList();
  }

  Stream<List<MissionProgressModel>> watchMyProgress(String profileId) {
    return _client
        .from('mission_progress')
        .stream(primaryKey: ['profile_id', 'mission_id'])
        .eq('profile_id', profileId)
        .map((rows) => rows.map(MissionProgressModel.fromJson).toList());
  }

  Future<void> recordEvent({
    required String eventType,
    required Map<String, dynamic> payload,
    required String idempotencyKey,
  }) async {
    await _client.rpc('record_mission_event', params: {
      'p_event_type': eventType,
      'p_event_payload': payload,
      'p_idempotency_key': idempotencyKey,
    });
  }

  Future<MissionClaimModel> claimMission(
      {required String missionId, required String idempotencyKey}) async {
    final res = await _client.rpc('claim_mission', params: {
      'p_mission_id': missionId,
      'p_idempotency_key': idempotencyKey,
    });

    final Map<String, dynamic> claimRow = res is List
        ? Map<String, dynamic>.from(res.first as Map)
        : Map<String, dynamic>.from(res as Map);

    final rewardRows = await _client
        .from('mission_rewards')
        .select()
        .eq('claim_id', claimRow['id'] as String);
    final rewards = (rewardRows as List)
        .map((r) => MissionRewardModel.fromJson(r as Map<String, dynamic>))
        .toList();

    return MissionClaimModel.fromJson(claimRow, rewards: rewards);
  }

  Future<int> secretMissionSlotCount() async {
    final res = await _client.rpc('get_secret_mission_slot_count');
    return res is int ? res : int.parse(res.toString());
  }

  Future<List<CrewMissionModel>> crewMissions(String crewId) async {
    final rows = await _client
        .from('crew_missions')
        .select('*, missions(title, description, rep_reward, xp_reward)')
        .eq('crew_id', crewId);
    return (rows as List)
        .map((r) => CrewMissionModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<SeasonModel?> activeSeason() async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final rows = await _client
        .from('season')
        .select()
        .lte('starts_at', nowIso)
        .gte('ends_at', nowIso)
        .order('starts_at', ascending: false)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return SeasonModel.fromJson(list.first as Map<String, dynamic>);
  }
}
