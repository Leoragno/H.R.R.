import '../../domain/entities/territory_cell.dart';
import '../../domain/hex_grid.dart';

class TerritoryCellModel {
  final int q;
  final int r;
  final String ownerId;
  final String? crewId;

  const TerritoryCellModel({
    required this.q,
    required this.r,
    required this.ownerId,
    this.crewId,
  });

  factory TerritoryCellModel.fromJson(Map<String, dynamic> json) {
    return TerritoryCellModel(
      q: json['q'] as int,
      r: json['r'] as int,
      ownerId: json['owner_id'] as String,
      crewId: json['crew_id'] as String?,
    );
  }

  TerritoryCell toEntity() => TerritoryCell(
        coord: HexCoord(q, r),
        ownerId: ownerId,
        ownerCrewId: crewId,
      );
}
