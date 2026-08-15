import 'package:equatable/equatable.dart';

/// Riga di classifica — aggregato calcolato server-side (RPC
/// `leaderboard_global`), mai ricalcolato lato client.
class LeaderboardEntry extends Equatable {
  final int rank;
  final String profileId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final int level;
  final int periodXp;
  final int periodRep;
  final double totalKm;
  final double topSpeedKmh;

  const LeaderboardEntry({
    required this.rank,
    required this.profileId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.level,
    required this.periodXp,
    required this.periodRep,
    required this.totalKm,
    required this.topSpeedKmh,
  });

  @override
  List<Object?> get props => [
        rank,
        profileId,
        username,
        displayName,
        avatarUrl,
        level,
        periodXp,
        periodRep,
        totalKm,
        topSpeedKmh,
      ];
}

/// Corrisponde a `p_metric` della RPC `leaderboard_global`: determina sia
/// il valore mostrato sia l'ordinamento/rank della classifica (la RPC
/// riordina lato server, cambiare metrica rifà sempre la chiamata).
enum LeaderboardMetric {
  xp,
  rep,
  km,
  speed;

  String get apiValue => switch (this) {
        LeaderboardMetric.xp => 'xp',
        LeaderboardMetric.rep => 'rep',
        LeaderboardMetric.km => 'km',
        LeaderboardMetric.speed => 'speed',
      };

  String get label => switch (this) {
        LeaderboardMetric.xp => 'XP guadagnati',
        LeaderboardMetric.rep => 'Reputazione',
        LeaderboardMetric.km => 'Km totali',
        LeaderboardMetric.speed => 'Velocità massima',
      };
}

/// Corrisponde a `p_period` della RPC `leaderboard_global`.
enum LeaderboardPeriod {
  day,
  week,
  month,
  all;

  String get apiValue => switch (this) {
        LeaderboardPeriod.day => 'day',
        LeaderboardPeriod.week => 'week',
        LeaderboardPeriod.month => 'month',
        LeaderboardPeriod.all => 'all',
      };

  String get label => switch (this) {
        LeaderboardPeriod.day => 'OGGI',
        LeaderboardPeriod.week => 'SETTIMANA',
        LeaderboardPeriod.month => 'MESE',
        LeaderboardPeriod.all => 'SEMPRE',
      };
}
