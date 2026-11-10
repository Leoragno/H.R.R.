import 'hex_grid.dart';

/// Esagono rubato all'utente (territory_claim_log) e ancora in mano al
/// ladro (territory_cells.owner_id == claimant).
class LostCell {
  const LostCell({
    required this.cell,
    required this.thiefId,
    required this.at,
    this.thiefScore,
  });
  final HexCoord cell;
  final String thiefId;
  final DateTime at;

  /// Punteggio di guida con cui il ladro tiene la cella: per riprenderla
  /// serve un FLOW più alto (claim_territory_cells, 0026).
  final int? thiefScore;
}

/// Card "SOTTO ATTACCO" di Gioca: il ladro più recente delle ultime 24 ore,
/// quanti esagoni tiene ancora e il FLOW che serve per riprenderli.
class TerritoryAttack {
  const TerritoryAttack({
    required this.thiefId,
    required this.thiefName,
    required this.cells,
    required this.lastAt,
    this.flowToBeat,
  });
  final String thiefId;
  final String thiefName;
  final List<HexCoord> cells;
  final DateTime lastAt;
  final int? flowToBeat;

  int get count => cells.length;

  /// Raggruppa per ladro e tiene il più recente. Null se non c'è nulla.
  static TerritoryAttack? latest(
    Iterable<LostCell> lost,
    String Function(String id) nameOf,
  ) {
    if (lost.isEmpty) return null;
    final newest = lost.reduce((a, b) => b.at.isAfter(a.at) ? b : a);
    final mine = [
      for (final l in lost)
        if (l.thiefId == newest.thiefId) l,
    ];
    final seen = <HexCoord>{};
    final cells = [
      for (final l in mine)
        if (seen.add(l.cell)) l.cell,
    ];
    final scores = [
      for (final l in mine)
        if (l.thiefScore != null) l.thiefScore!,
    ];
    return TerritoryAttack(
      thiefId: newest.thiefId,
      thiefName: nameOf(newest.thiefId),
      cells: cells,
      lastAt: newest.at,
      flowToBeat:
          scores.isEmpty ? null : scores.reduce((a, b) => a > b ? a : b),
    );
  }
}

/// "da 3 min" / "da 2 h" / "da ieri".
String attackAgo(DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.inMinutes < 1) return 'adesso';
  if (d.inMinutes < 60) return 'da ${d.inMinutes} min';
  if (d.inHours < 24) return 'da ${d.inHours} h';
  return 'da ieri';
}
