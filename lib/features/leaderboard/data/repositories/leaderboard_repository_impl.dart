import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../datasources/leaderboard_remote_datasource.dart';

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  final LeaderboardRemoteDatasource _remote;

  LeaderboardRepositoryImpl(this._remote);

  @override
  Future<List<LeaderboardEntry>> global({
    required LeaderboardMetric metric,
    required LeaderboardPeriod period,
    int limit = 50,
  }) async {
    final rows = await _remote.global(metric: metric, period: period, limit: limit);
    return rows.map((r) => r.toEntity()).toList();
  }
}
