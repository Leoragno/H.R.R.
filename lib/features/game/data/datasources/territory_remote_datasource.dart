import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/territory_claim_result.dart';
import '../../domain/hex_grid.dart';
import '../../domain/territory_attack.dart';
import '../models/territory_cell_model.dart';
import '../models/territory_standing_model.dart';

/// Unico punto della feature Gioca che importa supabase_flutter.
class TerritoryRemoteDatasource {
  final SupabaseClient _client;

  TerritoryRemoteDatasource(this._client);

  Future<TerritoryClaimResult> claimCells(
    List<HexCoord> cells,
  ) async {
    final row = await _client.rpc('claim_territory_cells', params: {
      'p_cells': [
        for (final c in cells) {'q': c.q, 'r': c.r}
      ],
    }).single();
    return TerritoryClaimResult(
      freshCount: (row['fresh_count'] as num).toInt(),
      stolenCount: (row['stolen_count'] as num).toInt(),
    );
  }

  Future<List<TerritoryCellModel>> cellsNear({
    required HexCoord focus,
    required int cols,
    required int rows,
  }) async {
    final result = await _client.rpc('territory_cells_near', params: {
      'p_q': focus.q,
      'p_r': focus.r,
      'p_cols': cols,
      'p_rows': rows,
    });
    return (result as List)
        .map((r) => TerritoryCellModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<TerritoryStandingModel>> standings({
    int periodDays = 30,
    int limit = 50,
  }) async {
    final result = await _client.rpc('territory_standings', params: {
      'p_period_days': periodDays,
      'p_limit': limit,
    });
    return (result as List)
        .map((r) => TerritoryStandingModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Tutte le celle possedute dal chiamante, ordinate dalla più vicina a
  /// scadere — per la schermata "I miei territori". `owner_id` non è nel
  /// resultset di `my_territories` (sempre il chiamante stesso): lo
  /// aggiungiamo qui per riusare [TerritoryCellModel.fromJson].
  Future<List<TerritoryCellModel>> myTerritories(String profileId) async {
    final result = await _client.rpc('my_territories');
    return (result as List).map((r) {
      final row = Map<String, dynamic>.from(r as Map);
      row['owner_id'] = profileId;
      return TerritoryCellModel.fromJson(row);
    }).toList();
  }

  Future<int> myCellCount(String profileId) async {
    final count = await _client.rpc('territory_cell_count', params: {
      'p_profile_id': profileId,
    });
    return (count as num).toInt();
  }

  /// Esagoni rubati a [profileId] nelle ultime [within] e ancora in mano
  /// al ladro (card "SOTTO ATTACCO" di Gioca).
  Future<({List<LostCell> lost, Map<String, String> names})> recentLosses(
    String profileId, {
    Duration within = const Duration(hours: 24),
  }) async {
    final since = DateTime.now().toUtc().subtract(within).toIso8601String();
    final log = await _client
        .from('territory_claim_log')
        .select('q, r, claimant_id, claimed_at')
        .eq('previous_owner_id', profileId)
        .gte('claimed_at', since)
        .order('claimed_at', ascending: false)
        .limit(60);
    final rows = (log as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) {
      return (lost: const <LostCell>[], names: const <String, String>{});
    }

    final pairs = {for (final r in rows) '${r['q']}:${r['r']}': r};
    final cells = await _client
        .from('territory_cells')
        .select('q, r, owner_id, drive_score')
        .or(pairs.values
            .map((r) => 'and(q.eq.${r['q']},r.eq.${r['r']})')
            .join(','));
    final owner = {
      for (final c in (cells as List).cast<Map<String, dynamic>>())
        '${c['q']}:${c['r']}': c,
    };
    final lost = <LostCell>[
      for (final r in rows)
        if (owner['${r['q']}:${r['r']}'] case final c?
            when c['owner_id'] == r['claimant_id'])
          LostCell(
            cell: HexCoord((r['q'] as num).toInt(), (r['r'] as num).toInt()),
            thiefId: r['claimant_id'] as String,
            at: DateTime.parse(r['claimed_at'] as String),
            thiefScore: (c['drive_score'] as num?)?.toInt(),
          ),
    ];
    final ids = {for (final l in lost) l.thiefId};
    final names = <String, String>{};
    if (ids.isNotEmpty) {
      final profiles = await _client
          .from('profiles')
          .select('id, username')
          .inFilter('id', ids.toList());
      for (final p in (profiles as List).cast<Map<String, dynamic>>()) {
        names[p['id'] as String] = (p['username'] as String?) ?? 'qualcuno';
      }
    }
    return (lost: lost, names: names);
  }

  Future<String?> profileDisplayName(String profileId) async {
    final row = await _client
        .from('profiles')
        .select('display_name, username')
        .eq('id', profileId)
        .maybeSingle();
    if (row == null) return null;
    return (row['display_name'] as String?) ?? row['username'] as String?;
  }

  /// Segnale "qualcosa è cambiato" su `territory_cells` (tabella aggiunta
  /// alla pubblicazione realtime in 0008_territory_game.sql) — non i dati
  /// stessi: lo stream grezzo non è filtrabile su una finestra
  /// rettangolare. Il chiamante rifà `cellsNear` per la finestra corrente
  /// a ogni evento, invece di tentare di ricostruire lo stato dai payload.
  Stream<void> watchCellChanges() =>
      _client.from('territory_cells').stream(primaryKey: ['q', 'r']).map(
        (_) {},
      );
}
