import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/mission_remote_datasource.dart';
import '../../data/repositories/mission_repository_impl.dart';
import '../../domain/entities/mission.dart';
import '../../domain/entities/mission_progress.dart';
import '../../domain/entities/season.dart';
import '../../domain/repositories/mission_repository.dart';
import '../../domain/usecases/get_active_missions_usecase.dart';

part 'mission_provider.g.dart';

// ---- DI wiring ----------------------------------------------------------

@riverpod
MissionRemoteDatasource missionRemoteDatasource(
    MissionRemoteDatasourceRef ref) {
  return MissionRemoteDatasource(ref.watch(supabaseClientProvider));
}

@riverpod
MissionRepository missionRepository(MissionRepositoryRef ref) {
  return MissionRepositoryImpl(
    ref.watch(missionRemoteDatasourceProvider),
    () => ref.read(authStateProvider).valueOrNull!.id,
  );
}

// ---- Stato -----------------------------------------------------------------

/// Genera (se serve) le istanze daily/weekly/seasonal del periodo
/// corrente prima di leggerle — vedi MissionRepository.ensureCurrentPeriodMissions.
/// Nessun `family`: un solo provider condiviso da tutti i tab, quindi la
/// generazione parte una volta sola per apertura schermata (Riverpod
/// cacha il Future), non una volta per tab osservato.
@riverpod
Future<void> ensureMissionPeriods(EnsureMissionPeriodsRef ref) {
  return ref.watch(missionRepositoryProvider).ensureCurrentPeriodMissions();
}

/// Missioni attive visibili al chiamante (le secret non completate sono
/// già escluse lato RLS). `type` filtra il tab Daily/Weekly/Season/Secret.
@riverpod
Future<List<Mission>> activeMissions(ActiveMissionsRef ref,
    {MissionType? type}) async {
  // Aspetta che le missioni del periodo corrente esistano prima di
  // leggerle, altrimenti il tab Daily/Weekly resta vuoto (o fermo a ieri)
  // finché nessun altro apre l'app dopo il cambio di giorno/settimana.
  await ref.watch(ensureMissionPeriodsProvider.future);
  final useCase =
      GetActiveMissionsUseCase(ref.watch(missionRepositoryProvider));
  return useCase(type: type);
}

/// Progresso live dell'utente corrente — realtime via Supabase (richiede
/// `mission_progress` nella pubblicazione, aggiunta in 0003_mission_engine.sql).
@riverpod
Stream<List<MissionProgress>> myMissionProgress(MyMissionProgressRef ref) {
  final userId = ref.watch(authStateProvider).valueOrNull?.id;
  if (userId == null) return Stream.value(const []);
  return ref.watch(missionRepositoryProvider).watchMyProgress();
}

/// Id delle missioni già riscattate dal chiamante (distingue "pronta" da
/// "già riscattata" nella UI — mission_progress non lo sa da sola).
@riverpod
Future<List<String>> myClaimedMissionIds(MyClaimedMissionIdsRef ref) {
  final userId = ref.watch(authStateProvider).valueOrNull?.id;
  if (userId == null) return Future.value(const []);
  return ref.watch(missionRepositoryProvider).myClaimedMissionIds();
}

/// Numero di slot missione segreta nel pool, per i placeholder "???" del
/// tab Secret — mai il contenuto delle missioni stesse.
@riverpod
Future<int> secretMissionSlotCount(SecretMissionSlotCountRef ref) {
  return ref.watch(missionRepositoryProvider).secretMissionSlotCount();
}

@riverpod
Future<Season?> activeSeason(ActiveSeasonRef ref) {
  return ref.watch(missionRepositoryProvider).activeSeason();
}
