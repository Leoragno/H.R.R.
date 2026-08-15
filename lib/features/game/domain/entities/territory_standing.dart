import 'package:equatable/equatable.dart';

/// Riga di classifica territorio — aggregato calcolato server-side dalla
/// RPC `territory_standings`, mai ricalcolato lato client (stesso
/// principio di `LeaderboardEntry`).
class TerritoryStanding extends Equatable {
  final String profileId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final int cellCount;
  final double areaKm2;
  final int stolen;
  final int growth;
  final int decline;

  const TerritoryStanding({
    required this.profileId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.cellCount,
    required this.areaKm2,
    required this.stolen,
    required this.growth,
    required this.decline,
  });

  @override
  List<Object?> get props => [
        profileId,
        username,
        displayName,
        avatarUrl,
        cellCount,
        areaKm2,
        stolen,
        growth,
        decline,
      ];
}

/// Corrisponde alla metrica selezionata nei 4 tab del pannello (mockup:
/// GENERALE / TOP LADRI / TOP IN CRESCITA / TOP IN CALO).
enum TerritoryMetric {
  general,
  topThieves,
  topGrowth,
  topDecline;

  String get label => switch (this) {
        TerritoryMetric.general => 'GENERALE',
        TerritoryMetric.topThieves => 'TOP LADRI',
        TerritoryMetric.topGrowth => 'TOP IN CRESCITA',
        TerritoryMetric.topDecline => 'TOP IN CALO',
      };
}
