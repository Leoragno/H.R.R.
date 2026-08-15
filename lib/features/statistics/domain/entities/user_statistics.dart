import 'package:equatable/equatable.dart';

/// Aggregato di sola lettura delle statistiche personali dell'utente
/// loggato — combina dati già presenti in altre feature (profilo,
/// achievement, territorio, classifica, missioni, car spotting), nessuna
/// tabella/RPC propria: vedi `statistics_provider.dart` per come viene
/// composto.
class UserStatistics extends Equatable {
  final int level;
  final int xp;
  final int rep;
  final double drivingScore;
  final double totalKm;
  final int totalTrips;
  final double topSpeedKmh;
  final int achievementsEarned;
  final int achievementsTotal;
  final int territoryCellCount;
  final double territoryAreaKm2;
  final int territoryStolen;
  final int territoryGrowth;
  final int territoryDecline;
  final int spotsCount;
  final int missionsCompleted;

  const UserStatistics({
    required this.level,
    required this.xp,
    required this.rep,
    required this.drivingScore,
    required this.totalKm,
    required this.totalTrips,
    required this.topSpeedKmh,
    required this.achievementsEarned,
    required this.achievementsTotal,
    required this.territoryCellCount,
    required this.territoryAreaKm2,
    required this.territoryStolen,
    required this.territoryGrowth,
    required this.territoryDecline,
    required this.spotsCount,
    required this.missionsCompleted,
  });

  @override
  List<Object?> get props => [
        level,
        xp,
        rep,
        drivingScore,
        totalKm,
        totalTrips,
        topSpeedKmh,
        achievementsEarned,
        achievementsTotal,
        territoryCellCount,
        territoryAreaKm2,
        territoryStolen,
        territoryGrowth,
        territoryDecline,
        spotsCount,
        missionsCompleted,
      ];
}
