import '../../domain/entities/territory_standing.dart';
import '../../domain/hex_grid.dart';

class TerritoryStandingModel {
  final String profileId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final int cellCount;
  final int stolen;
  final int growth;
  final int decline;

  const TerritoryStandingModel({
    required this.profileId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.cellCount,
    required this.stolen,
    required this.growth,
    required this.decline,
  });

  factory TerritoryStandingModel.fromJson(Map<String, dynamic> json) {
    return TerritoryStandingModel(
      profileId: json['profile_id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      cellCount: (json['cell_count'] as num).toInt(),
      stolen: (json['stolen'] as num).toInt(),
      growth: (json['growth'] as num).toInt(),
      decline: (json['decline'] as num).toInt(),
    );
  }

  TerritoryStanding toEntity() => TerritoryStanding(
        profileId: profileId,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        cellCount: cellCount,
        areaKm2: cellCount * HexGrid.cellAreaKm2(),
        stolen: stolen,
        growth: growth,
        decline: decline,
      );
}
