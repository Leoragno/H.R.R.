import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/territory_remote_datasource.dart';
import '../../data/repositories/territory_repository_impl.dart';
import '../../domain/entities/territory_cell.dart';
import '../../domain/entities/territory_standing.dart';
import '../../domain/repositories/territory_repository.dart';
import '../../domain/territory_attack.dart';

part 'territory_provider.g.dart';

// ---- DI wiring ----------------------------------------------------------

@riverpod
TerritoryRemoteDatasource territoryRemoteDatasource(
    TerritoryRemoteDatasourceRef ref) {
  return TerritoryRemoteDatasource(ref.watch(supabaseClientProvider));
}

@riverpod
TerritoryRepository territoryRepository(TerritoryRepositoryRef ref) {
  return TerritoryRepositoryImpl(ref.watch(territoryRemoteDatasourceProvider));
}

// ---- Stato ----------------------------------------------------------------

/// Classifica territorio globale. La metrica selezionata nei 4 tab del
/// pannello (GENERALE/TOP LADRI/...) riordina la stessa lista lato client —
/// la RPC restituisce già tutti e 4 gli aggregati per riga, non serve
/// rifare la chiamata per cambiare ordinamento.
@riverpod
Future<List<TerritoryStanding>> territoryStandings(
  TerritoryStandingsRef ref,
) {
  return ref.watch(territoryRepositoryProvider).standings();
}

/// Tutte le celle possedute dall'utente corrente, dalla più vicina a
/// scadere — per la schermata "I miei territori" (brief, punto 1).
@riverpod
Future<List<TerritoryCell>> myTerritories(MyTerritoriesRef ref) async {
  final profile = await ref.watch(myProfileProvider.future);
  if (profile == null) return const [];
  return ref.watch(territoryRepositoryProvider).myTerritories(profile.id);
}

/// Card "SOTTO ATTACCO" di Gioca (provider a mano: build_runner è rotto).
/// Null se nelle ultime 24 ore nessuno ti ha rubato esagoni che tiene
/// ancora, o se la lettura fallisce.
final territoryAttackProvider =
    FutureProvider.autoDispose<TerritoryAttack?>((ref) async {
  final me = ref.watch(authStateProvider).valueOrNull?.id;
  if (me == null) return null;
  try {
    final r =
        await ref.watch(territoryRemoteDatasourceProvider).recentLosses(me);
    return TerritoryAttack.latest(r.lost, (id) => r.names[id] ?? 'qualcuno');
  } catch (_) {
    return null;
  }
});
