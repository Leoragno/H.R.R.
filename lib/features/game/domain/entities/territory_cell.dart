import 'package:equatable/equatable.dart';

import '../hex_grid.dart';

/// Una cella esagonale posseduta. Le celle libere non hanno entità: il
/// client le disegna implicitamente (nessuna riga lato server).
class TerritoryCell extends Equatable {
  final HexCoord coord;
  final String ownerId;
  final DateTime claimedAt;
  final int? driveScore;

  const TerritoryCell({
    required this.coord,
    required this.ownerId,
    required this.claimedAt,
    this.driveScore,
  });

  @override
  List<Object?> get props => [coord, ownerId, claimedAt, driveScore];
}
