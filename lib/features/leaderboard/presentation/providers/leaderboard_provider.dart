import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/supabase_provider.dart';
import '../../data/datasources/leaderboard_remote_datasource.dart';
import '../../data/repositories/leaderboard_repository_impl.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';

part 'leaderboard_provider.g.dart';

// ---- DI wiring ----------------------------------------------------------

@riverpod
LeaderboardRemoteDatasource leaderboardRemoteDatasource(
    LeaderboardRemoteDatasourceRef ref) {
  return LeaderboardRemoteDatasource(ref.watch(supabaseClientProvider));
}

@riverpod
LeaderboardRepository leaderboardRepository(LeaderboardRepositoryRef ref) {
  return LeaderboardRepositoryImpl(
      ref.watch(leaderboardRemoteDatasourceProvider));
}

// ---- Stato ----------------------------------------------------------------

/// Classifica globale per metrica + periodo (family sui due filtri della
/// schermata). La metrica determina anche l'ordinamento lato server:
/// cambiarla rifà sempre la chiamata (niente riordino lato client).
@riverpod
Future<List<LeaderboardEntry>> leaderboard(
  LeaderboardRef ref,
  LeaderboardMetric metric,
  LeaderboardPeriod period,
) {
  return ref
      .watch(leaderboardRepositoryProvider)
      .global(metric: metric, period: period);
}
