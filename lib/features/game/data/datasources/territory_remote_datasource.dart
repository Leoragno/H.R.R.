import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/territory_claim_result.dart';
import '../../domain/entities/territory_standing.dart';
import '../../domain/hex_grid.dart';
import '../models/territory_cell_model.dart';
import '../models/territory_standing_model.dart';

/// Unico punto della feature Gioca che importa supabase_flutter.
class TerritoryRemoteDatasource {
  final SupabaseClient _client;

  TerritoryRemoteDatasource(this._client);

  Future<TerritoryClaimResult> claimCells(List<HexCoord> cells) async {
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
    required TerritoryScope scope,
    String? crewId,
    int periodDays = 30,
    int limit = 50,
  }) async {
    final result = await _client.rpc('territory_standings', params: {
      'p_scope': scope.apiValue,
      'p_crew_id': crewId,
      'p_period_days': periodDays,
      'p_limit': limit,
    });
    return (result as List)
        .map((r) => TerritoryStandingModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<int> myCellCount(String profileId) async {
    final count = await _client.rpc('territory_cell_count', params: {
      'p_profile_id': profileId,
    });
    return (count as num).toInt();
  }
}
