import '../../domain/entities/territory_cell.dart';
import '../../domain/hex_grid.dart';

class TerritoryCellModel {
  final int q;
  final int r;
  final String ownerId;
  final DateTime claimedAt;
  final int? driveScore;

  const TerritoryCellModel({
    required this.q,
    required this.r,
    required this.ownerId,
    required this.claimedAt,
    this.driveScore,
  });

  factory TerritoryCellModel.fromJson(Map<String, dynamic> json) {
    return TerritoryCellModel(
      q: json['q'] as int,
      r: json['r'] as int,
      ownerId: json['owner_id'] as String,
      claimedAt: DateTime.parse(json['claimed_at'] as String),
      driveScore: json['drive_score'] as int?,
    );
  }

  TerritoryCell toEntity() => TerritoryCell(
        coord: HexCoord(q, r),
        ownerId: ownerId,
        claimedAt: claimedAt,
        driveScore: driveScore,
      );
}
