import 'package:equatable/equatable.dart';

/// Aggregato di sola lettura delle statistiche personali dell'utente
/// loggato — combina dati già presenti in altre feature (profilo,
/// achievement, territorio, classifica, car spotting, statistiche di
/// guida per-viaggio): vedi `statistics_provider.dart` per come viene
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

  // Aggregati da 0030_persist_trip_motion_stats.sql su tutti i viaggi
  // completati (0032_trip_motion_stats_totals.sql) — stesse metriche già
  // mostrate per singolo viaggio in TripDetailScreen, qui sommate/record
  // personale. `bestZeroToHundredSeconds` null se nessun viaggio ha mai
  // registrato uno scatto 0-100 valido (mai 0, che sarebbe un record
  // impossibile e andrebbe confuso con "nessun dato").
  final double elevationGainTotalM;
  final double maxAltitudeM;
  final double peakGForce;
  final double maxAccelerationMs2;
  final double maxDecelerationMs2;
  final double? bestZeroToHundredSeconds;
  final double maxCorneringSpeedKmh;
  final int turnsTotal;
  final int laneChangesTotal;
  final int brakingEventsTotal;
  final int totalStopsTotal;
  final int stoppedSecondsTotal;

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
    this.elevationGainTotalM = 0,
    this.maxAltitudeM = 0,
    this.peakGForce = 0,
    this.maxAccelerationMs2 = 0,
    this.maxDecelerationMs2 = 0,
    this.bestZeroToHundredSeconds,
    this.maxCorneringSpeedKmh = 0,
    this.turnsTotal = 0,
    this.laneChangesTotal = 0,
    this.brakingEventsTotal = 0,
    this.totalStopsTotal = 0,
    this.stoppedSecondsTotal = 0,
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
        elevationGainTotalM,
        maxAltitudeM,
        peakGForce,
        maxAccelerationMs2,
        maxDecelerationMs2,
        bestZeroToHundredSeconds,
        maxCorneringSpeedKmh,
        turnsTotal,
        laneChangesTotal,
        brakingEventsTotal,
        totalStopsTotal,
        stoppedSecondsTotal,
      ];
}
