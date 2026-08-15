import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/leaderboard_entry.dart';
import '../models/leaderboard_entry_model.dart';

/// Unico punto della feature Leaderboard che importa supabase_flutter.
class LeaderboardRemoteDatasource {
  final SupabaseClient _client;

  LeaderboardRemoteDatasource(this._client);

  Future<List<LeaderboardEntryModel>> global({
    required LeaderboardMetric metric,
    required LeaderboardPeriod period,
    int limit = 50,
  }) async {
    final rows = await _client.rpc('leaderboard_global', params: {
      'p_metric': metric.apiValue,
      'p_period': period.apiValue,
      'p_limit': limit,
    });
    return (rows as List)
        .map((r) => LeaderboardEntryModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
