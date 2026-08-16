import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/supabase_provider.dart';
import '../../../achievements/presentation/providers/achievement_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../game/domain/entities/territory_standing.dart';
import '../../../game/domain/hex_grid.dart';
import '../../../game/presentation/providers/territory_provider.dart';
import '../../../leaderboard/domain/entities/leaderboard_entry.dart';
import '../../../leaderboard/presentation/providers/leaderboard_provider.dart';
import '../../data/datasources/statistics_remote_datasource.dart';
import '../../domain/entities/user_statistics.dart';

part 'statistics_provider.g.dart';

// ---- DI wiring ----------------------------------------------------------

@riverpod
StatisticsRemoteDatasource statisticsRemoteDatasource(
    StatisticsRemoteDatasourceRef ref) {
  return StatisticsRemoteDatasource(ref.watch(supabaseClientProvider));
}

// ---- Stato ------------------------------------------------------------

/// Combina dati già presenti in altre feature — nessuna nuova tabella/RPC
/// (a parte il conteggio spot e l'aggregato statistiche di guida, vedi
/// [StatisticsRemoteDatasource]). La velocità massima non è ovunque
/// esposta: si prende dalla classifica
/// "velocità" (limite alto per non perdere la propria riga se non si è
/// nei primi 50) filtrata sulla propria; se non compare (mai guidato, o
/// oltre il limite) resta 0 — stesso comportamento già accettato altrove
/// in app (leaderboard_screen.dart "fuori classifica").
@riverpod
Future<UserStatistics> myStatistics(MyStatisticsRef ref) async {
  final profile = await ref.watch(myProfileProvider.future);
  if (profile == null) {
    return const UserStatistics(
      level: 0,
      xp: 0,
      rep: 0,
      drivingScore: 0,
      totalKm: 0,
      totalTrips: 0,
      topSpeedKmh: 0,
      achievementsEarned: 0,
      achievementsTotal: 0,
      territoryCellCount: 0,
      territoryAreaKm2: 0,
      territoryStolen: 0,
      territoryGrowth: 0,
      territoryDecline: 0,
      spotsCount: 0,
    );
  }

  final achievementsFuture =
      ref.watch(achievementRepositoryProvider).myAchievements();
  final myCellsFuture =
      ref.watch(territoryRepositoryProvider).myTerritories(profile.id);
  final standingsFuture = ref.watch(territoryRepositoryProvider).standings();
  final speedBoardFuture = ref.watch(leaderboardRepositoryProvider).global(
      metric: LeaderboardMetric.speed,
      period: LeaderboardPeriod.all,
      limit: 500);
  final spotsCountFuture =
      ref.watch(statisticsRemoteDatasourceProvider).mySpotCount(profile.id);
  final motionTotalsFuture =
      ref.watch(statisticsRemoteDatasourceProvider).tripMotionTotals();

  final achievements = await achievementsFuture;
  final myCells = await myCellsFuture;
  final standings = await standingsFuture;
  final speedBoard = await speedBoardFuture;
  final spotsCount = await spotsCountFuture;
  final motionTotals = await motionTotalsFuture;

  TerritoryStanding? myStanding;
  for (final s in standings) {
    if (s.profileId == profile.id) {
      myStanding = s;
      break;
    }
  }
  LeaderboardEntry? mySpeedEntry;
  for (final e in speedBoard) {
    if (e.profileId == profile.id) {
      mySpeedEntry = e;
      break;
    }
  }

  return UserStatistics(
    level: profile.level,
    xp: profile.xp,
    rep: profile.rep,
    drivingScore: profile.drivingScore,
    totalKm: profile.totalKm,
    totalTrips: profile.totalTrips,
    topSpeedKmh: mySpeedEntry?.topSpeedKmh ?? 0,
    achievementsEarned: achievements.where((a) => a.isEarned).length,
    achievementsTotal: achievements.length,
    territoryCellCount: myCells.length,
    territoryAreaKm2: myCells.length * HexGrid.cellAreaKm2(),
    territoryStolen: myStanding?.stolen ?? 0,
    territoryGrowth: myStanding?.growth ?? 0,
    territoryDecline: myStanding?.decline ?? 0,
    spotsCount: spotsCount,
    elevationGainTotalM:
        (motionTotals['elevation_gain_total_m'] as num?)?.toDouble() ?? 0,
    maxAltitudeM: (motionTotals['max_altitude_m'] as num?)?.toDouble() ?? 0,
    peakGForce: (motionTotals['peak_g_force'] as num?)?.toDouble() ?? 0,
    maxAccelerationMs2:
        (motionTotals['max_acceleration_ms2'] as num?)?.toDouble() ?? 0,
    maxDecelerationMs2:
        (motionTotals['max_deceleration_ms2'] as num?)?.toDouble() ?? 0,
    bestZeroToHundredSeconds:
        (motionTotals['best_zero_to_hundred_seconds'] as num?)?.toDouble(),
    maxCorneringSpeedKmh:
        (motionTotals['max_cornering_speed_kmh'] as num?)?.toDouble() ?? 0,
    turnsTotal: (motionTotals['turns_total'] as num?)?.toInt() ?? 0,
    laneChangesTotal:
        (motionTotals['lane_changes_total'] as num?)?.toInt() ?? 0,
    brakingEventsTotal:
        (motionTotals['braking_events_total'] as num?)?.toInt() ?? 0,
    totalStopsTotal: (motionTotals['total_stops_total'] as num?)?.toInt() ?? 0,
    stoppedSecondsTotal:
        (motionTotals['stopped_seconds_total'] as num?)?.toInt() ?? 0,
  );
}
