import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/achievement_remote_datasource.dart';
import '../../data/repositories/achievement_repository_impl.dart';
import '../../domain/entities/achievement.dart';
import '../../domain/repositories/achievement_repository.dart';

part 'achievement_provider.g.dart';

// ---- DI wiring ----------------------------------------------------------

@riverpod
AchievementRemoteDatasource achievementRemoteDatasource(
    AchievementRemoteDatasourceRef ref) {
  return AchievementRemoteDatasource(ref.watch(supabaseClientProvider));
}

@riverpod
AchievementRepository achievementRepository(AchievementRepositoryRef ref) {
  return AchievementRepositoryImpl(
    ref.watch(achievementRemoteDatasourceProvider),
    () => ref.read(authStateProvider).valueOrNull!.id,
  );
}

// ---- Stato -----------------------------------------------------------------

/// Achievement del profilo corrente — ottenuti e non, unificati (vedi
/// AchievementRemoteDatasource.myAchievements). Nessun claim manuale: gli
/// achievement ottenuti sono già assegnati lato server.
@riverpod
Future<List<Achievement>> myAchievements(MyAchievementsRef ref) {
  final userId = ref.watch(authStateProvider).valueOrNull?.id;
  if (userId == null) return Future.value(const []);
  return ref.watch(achievementRepositoryProvider).myAchievements();
}
