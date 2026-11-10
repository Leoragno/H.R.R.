import 'package:supabase_flutter/supabase_flutter.dart';

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
    final nowIso = DateTime.now().toUtc().toIso8601String();
    var query = _client.from('missions').select();
    if (type != null) {
      query = query.eq('type', type);
    }
    // Esclude istanze daily/weekly/seasonal di un periodo già chiuso: senza
    // questo filtro un'istanza di ieri (starts_at/ends_at nel passato)
    // resta in lista per sempre accanto a quella di oggi, congelata (
    // record_mission_event non fa più progredire mission_progress fuori
    // dalla finestra). Le secret/permanenti (ends_at null) non sono mai
    // escluse da questi filtri.
    final rows = await query
        .or('starts_at.is.null,starts_at.lte.$nowIso')
        .or('ends_at.is.null,ends_at.gte.$nowIso')
        .order('created_at', ascending: false);
    final swaps = await mySwaps();
    final swappedOut = {for (final s in swaps) s.oldId};
    final swappedIn = {for (final s in swaps) s.newId};
    return (rows as List)
        .cast<Map<String, dynamic>>()
        // Cambio missione (0041): la giornaliera sostituita sparisce, quelle
        // del pool compaiono solo a chi le ha pescate.
        .where((r) =>
            !swappedOut.contains(r['id']) &&
            (r['pool'] != true || swappedIn.contains(r['id'])))
        .map(MissionModel.fromJson)
        .toList();
  }

  /// Cambi missione dell'utente (tabella mission_swaps, 0041). Vuoto se la
  /// migrazione non c'è ancora.
  Future<List<({String oldId, String newId, DateTime day})>> mySwaps() async {
    try {
      final rows = await _client
          .from('mission_swaps')
          .select('old_mission_id, new_mission_id, day');
      return [
        for (final r in (rows as List).cast<Map<String, dynamic>>())
          (
            oldId: r['old_mission_id'] as String,
            newId: r['new_mission_id'] as String,
            day: DateTime.parse(r['day'] as String),
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> rerollDailyMission(String missionId) =>
      _client.rpc('reroll_daily_mission', params: {'p_mission_id': missionId});

  /// Forzieri già aperti: "kind:period" (es. "daily:20261110").
  Future<Set<String>> myChests() async {
    try {
      final rows = await _client.from('mission_chests').select('kind, period');
      return {
        for (final r in (rows as List).cast<Map<String, dynamic>>())
          '${r['kind']}:${r['period']}',
      };
    } catch (_) {
      return const {};
    }
  }

  Future<int> claimMissionChest(String kind) async {
    final res =
        await _client.rpc('claim_mission_chest', params: {'p_kind': kind});
    return (res as num).toInt();
  }

  Future<Map<String, dynamic>?> myPass() async {
    final res = await _client.rpc('my_pass');
    final list = res is List ? res : [res];
    if (list.isEmpty || list.first == null) return null;
    return Map<String, dynamic>.from(list.first as Map);
  }

  /// Riscuote un tier o, con [tier] null, tutti quelli pronti. Restituisce
  /// i premi assegnati ({tier, kind, item, xp}).
  Future<List<Map<String, dynamic>>> claimPass({int? tier}) async {
    final res = await _client.rpc('claim_pass', params: {'p_tier': tier});
    return [
      for (final r in (res as List? ?? const []))
        Map<String, dynamic>.from(r as Map),
    ];
  }

  Future<Set<String>> myUnlocks(String profileId) async {
    try {
      final rows = await _client
          .from('profile_unlocks')
          .select('item')
          .eq('profile_id', profileId);
      return {
        for (final r in (rows as List).cast<Map<String, dynamic>>())
          r['item'] as String,
      };
    } catch (_) {
      return const {};
    }
  }

  /// Richiama i tre generatori idempotenti (0003_mission_engine.sql):
  /// niente scheduling server-side, quindi qualcuno deve invocarli quando
  /// il periodo corrente cambia — vedi MissionRepository.
  /// generate_seasonal_missions() solleva un'eccezione se nessuna riga
  /// `season` copre `now()` (nessuna stagione attiva pianificata): non è
  /// un errore da propagare, la season semplicemente non genera missioni
  /// finché non ne viene creata una nuova.
  Future<void> ensureCurrentPeriodMissions() async {
    try {
      await _client.rpc('generate_daily_missions');
    } catch (_) {}
    try {
      await _client.rpc('generate_weekly_missions');
    } catch (_) {}
    try {
      await _client.rpc('generate_seasonal_missions');
    } catch (_) {}
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
