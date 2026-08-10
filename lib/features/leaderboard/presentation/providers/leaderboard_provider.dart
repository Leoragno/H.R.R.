import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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

/// Classifica per metrica + periodo + scope (family sui tre filtri della
/// schermata). La metrica determina anche l'ordinamento lato server:
/// cambiarla rifà sempre la chiamata (niente riordino lato client).
/// scope=crew usa la crew dell'utente corrente ([myProfileProvider]): se
/// non ha una crew la lista è vuota, mai un errore.
@riverpod
Future<List<LeaderboardEntry>> leaderboard(
  LeaderboardRef ref,
  LeaderboardMetric metric,
  LeaderboardPeriod period,
  LeaderboardScope scope,
) async {
  String? crewId;
  if (scope == LeaderboardScope.crew) {
    crewId = (await ref.watch(myProfileProvider.future))?.crewId;
    if (crewId == null) return const [];
  }
  return ref
      .watch(leaderboardRepositoryProvider)
      .global(metric: metric, period: period, crewId: crewId);
}
