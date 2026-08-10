import '../entities/leaderboard_entry.dart';

abstract class LeaderboardRepository {
  Future<List<LeaderboardEntry>> global({
    required LeaderboardMetric metric,
    required LeaderboardPeriod period,
    int limit = 50,
    String? crewId,
  });
}
