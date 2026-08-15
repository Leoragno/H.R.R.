import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/territory_remote_datasource.dart';
import '../../data/repositories/territory_repository_impl.dart';
import '../../domain/entities/territory_cell.dart';
import '../../domain/entities/territory_standing.dart';
import '../../domain/repositories/territory_repository.dart';

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
