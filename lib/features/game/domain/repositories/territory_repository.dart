import '../entities/territory_cell.dart';
import '../entities/territory_claim_result.dart';
import '../entities/territory_standing.dart';
import '../hex_grid.dart';

abstract class TerritoryRepository {
  /// Rivendica [cells] per l'utente autenticato (libere o altrui).
  Future<TerritoryClaimResult> claimCells(List<HexCoord> cells);

  /// Celle possedute in una finestra rettangolare (in celle) attorno a
  /// [focus] — per disegnare la mappa.
  Future<List<TerritoryCell>> cellsNear({
    required HexCoord focus,
    required int cols,
    required int rows,
  });

  Future<List<TerritoryStanding>> standings({
    required TerritoryScope scope,
    String? crewId,
    int periodDays = 30,
  });

  /// Totale celle possedute da [profileId] — può eccedere quelle
  /// visibili nella finestra corrente di [cellsNear].
  Future<int> myCellCount(String profileId);
}
