import '../../domain/entities/territory_cell.dart';
import '../../domain/entities/territory_claim_result.dart';
import '../../domain/entities/territory_standing.dart';
import '../../domain/hex_grid.dart';
import '../../domain/repositories/territory_repository.dart';
import '../datasources/territory_remote_datasource.dart';

class TerritoryRepositoryImpl implements TerritoryRepository {
  final TerritoryRemoteDatasource _remote;

  TerritoryRepositoryImpl(this._remote);

  @override
  Future<TerritoryClaimResult> claimCells(List<HexCoord> cells) {
    if (cells.isEmpty) return Future.value(TerritoryClaimResult.zero);
    return _remote.claimCells(cells);
  }

  @override
  Future<List<TerritoryCell>> cellsNear({
    required HexCoord focus,
    required int cols,
    required int rows,
  }) async {
    final cells = await _remote.cellsNear(focus: focus, cols: cols, rows: rows);
    return cells.map((c) => c.toEntity()).toList();
  }

  @override
  Future<List<TerritoryStanding>> standings({
    required TerritoryScope scope,
    String? crewId,
    int periodDays = 30,
  }) async {
    final rows = await _remote.standings(
      scope: scope,
      crewId: crewId,
      periodDays: periodDays,
    );
    return rows.map((r) => r.toEntity()).toList();
  }

  @override
  Future<int> myCellCount(String profileId) => _remote.myCellCount(profileId);
}
