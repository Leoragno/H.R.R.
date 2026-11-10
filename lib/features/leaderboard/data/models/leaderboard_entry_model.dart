import '../../domain/entities/leaderboard_entry.dart';

class LeaderboardEntryModel {
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
  final double? bestZeroToHundred;
  final String? mascotId;
  final String? country;

  const LeaderboardEntryModel({
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

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntryModel(
      rank: json['rank'] as int,
      profileId: json['profile_id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      level: json['level'] as int,
      periodXp: (json['period_xp'] as num).toInt(),
      periodRep: (json['period_rep'] as num?)?.toInt() ?? 0,
      totalKm: (json['total_km'] as num?)?.toDouble() ?? 0,
      topSpeedKmh: (json['top_speed_kmh'] as num?)?.toDouble() ?? 0,
      // Colonne aggiunte in 0038: assenti se la migrazione non è applicata.
      avgSpeedKmh: (json['avg_speed_kmh'] as num?)?.toDouble() ?? 0,
      longestTripKm: (json['longest_trip_km'] as num?)?.toDouble() ?? 0,
      bestZeroToHundred: (json['best_zero_to_hundred'] as num?)?.toDouble(),
      mascotId: json['mascot_id'] as String?,
      country: json['country'] as String?,
    );
  }

  LeaderboardEntry toEntity() => LeaderboardEntry(
        rank: rank,
        profileId: profileId,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        level: level,
        periodXp: periodXp,
        periodRep: periodRep,
        totalKm: totalKm,
        topSpeedKmh: topSpeedKmh,
        avgSpeedKmh: avgSpeedKmh,
        longestTripKm: longestTripKm,
        bestZeroToHundred: bestZeroToHundred,
        mascotId: mascotId,
        country: country,
      );
}
