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
  Future<TerritoryClaimResult> claimCells(List<HexCoord> cells,
      {int? driveScore}) {
    if (cells.isEmpty) return Future.value(TerritoryClaimResult.zero);
    return _remote.claimCells(cells, driveScore: driveScore);
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
  Future<List<TerritoryStanding>> standings({int periodDays = 30}) async {
    final rows = await _remote.standings(periodDays: periodDays);
    return rows.map((r) => r.toEntity()).toList();
  }

  @override
  Future<int> myCellCount(String profileId) => _remote.myCellCount(profileId);

  @override
  Future<List<TerritoryCell>> myTerritories(String profileId) async {
    final cells = await _remote.myTerritories(profileId);
    return cells.map((c) => c.toEntity()).toList();
  }

  @override
  Future<String?> profileDisplayName(String profileId) =>
      _remote.profileDisplayName(profileId);

  @override
  Stream<void> watchCellChanges() => _remote.watchCellChanges();
}
