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
  final double avgSpeedKmh;
  final double longestTripKm;

  /// Miglior 0-100 in secondi; null = mai misurato.
  final double? bestZeroToHundred;
  final String? mascotId;

  /// Codice ISO (IT, CH, …) per la bandiera della riga.
  final String? country;

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
    this.avgSpeedKmh = 0,
    this.longestTripKm = 0,
    this.bestZeroToHundred,
    this.mascotId,
    this.country,
  });

  /// Valore della [metric] per questa riga.
  num valueFor(LeaderboardMetric metric) => switch (metric) {
        LeaderboardMetric.xp => periodXp,
        LeaderboardMetric.rep => periodRep,
        LeaderboardMetric.km => totalKm,
        LeaderboardMetric.speed => topSpeedKmh,
        LeaderboardMetric.avg => avgSpeedKmh,
        LeaderboardMetric.long => longestTripKm,
        LeaderboardMetric.zero => bestZeroToHundred ?? 0,
      };

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
        avgSpeedKmh,
        longestTripKm,
        bestZeroToHundred,
        mascotId,
        country,
      ];
}

/// Corrisponde a `p_metric` della RPC `leaderboard_global`: determina sia
/// il valore mostrato sia l'ordinamento/rank della classifica (la RPC
/// riordina lato server, cambiare metrica rifà sempre la chiamata).
enum LeaderboardMetric {
  xp,
  rep,
  km,
  speed,
  avg,
  long,
  zero;

  String get apiValue => name;

  String get label => switch (this) {
        LeaderboardMetric.xp => 'XP',
        LeaderboardMetric.rep => 'REPUTAZIONE',
        LeaderboardMetric.km => 'DISTANZA TOTALE',
        LeaderboardMetric.speed => 'TOP SPEED',
        LeaderboardMetric.avg => 'VELOCITÀ MEDIA',
        LeaderboardMetric.long => 'GUIDA PIÙ LUNGA',
        LeaderboardMetric.zero => '0-100 KM/H',
      };

  /// Unità mostrata accanto al valore.
  String get unit => switch (this) {
        LeaderboardMetric.xp => ' XP',
        LeaderboardMetric.rep => ' REP',
        LeaderboardMetric.km || LeaderboardMetric.long => ' km',
        LeaderboardMetric.speed || LeaderboardMetric.avg => ' km/h',
        LeaderboardMetric.zero => ' s',
      };

  /// Per lo 0-100 vince il valore più basso.
  bool get lowerIsBetter => this == LeaderboardMetric.zero;
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
