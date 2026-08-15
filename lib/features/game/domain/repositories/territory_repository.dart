import '../entities/territory_cell.dart';
import '../entities/territory_claim_result.dart';
import '../entities/territory_standing.dart';
import '../hex_grid.dart';

abstract class TerritoryRepository {
  /// Rivendica [cells] per l'utente autenticato (libere, decadute o
  /// altrui). [driveScore] è il punteggio di guida del viaggio appena
  /// completato durante il quale sono state attraversate — `null` se il
  /// viaggio era troppo corto per un punteggio onesto (può comunque
  /// rivendicare celle libere/decadute, mai rubarne una attiva). Va
  /// chiamata solo a fine guida (vedi TripLiveController.finishTrip):
  /// l'acquisizione territorio non è più ambientale/indipendente.
  Future<TerritoryClaimResult> claimCells(List<HexCoord> cells,
      {int? driveScore});

  /// Celle possedute in una finestra rettangolare (in celle) attorno a
  /// [focus] — per disegnare la mappa.
  Future<List<TerritoryCell>> cellsNear({
    required HexCoord focus,
    required int cols,
    required int rows,
  });

  Future<List<TerritoryStanding>> standings({int periodDays = 30});

  /// Totale celle possedute da [profileId] — può eccedere quelle
  /// visibili nella finestra corrente di [cellsNear].
  Future<int> myCellCount(String profileId);

  /// Tutte le celle possedute dall'utente autenticato, ordinate dalla più
  /// vicina a scadere — per la schermata "I miei territori".
  Future<List<TerritoryCell>> myTerritories(String profileId);

  /// Nome da mostrare per [profileId] — usato al tap su una cella colorata
  /// sulla mappa, dove [cellsNear] restituisce solo l'id proprietario e non
  /// tutti gli owner sono per forza in classifica (limitata ai top player).
  /// `null` se il profilo non esiste più.
  Future<String?> profileDisplayName(String profileId);

  /// Segnale "qualcosa è cambiato" su territory_cells altrove (furto/claim
  /// di un altro giocatore) — non porta i dati, solo il trigger a rifare
  /// [cellsNear] per la finestra corrente. Così la mappa riflette i furti
  /// altrui senza aspettare che l'utente si sposti di cella.
  Stream<void> watchCellChanges();
}
