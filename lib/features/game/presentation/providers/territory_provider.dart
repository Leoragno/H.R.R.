import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/territory_remote_datasource.dart';
import '../../data/repositories/territory_repository_impl.dart';
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

/// Classifica territorio per scope (family sul tab Globale/La mia crew).
/// La metrica selezionata nei 4 tab del pannello (GENERALE/TOP LADRI/...)
/// riordina la stessa lista lato client — la RPC restituisce già tutti e
/// 4 gli aggregati per riga, non serve rifare la chiamata per cambiare
/// ordinamento (stesso principio di `standings()` nel mockup).
/// scope=crew usa la crew dell'utente corrente ([myProfileProvider]): se
/// non ha una crew la lista è vuota, mai un errore.
@riverpod
Future<List<TerritoryStanding>> territoryStandings(
  TerritoryStandingsRef ref,
  TerritoryScope scope,
) async {
  String? crewId;
  if (scope == TerritoryScope.crew) {
    crewId = (await ref.watch(myProfileProvider.future))?.crewId;
    if (crewId == null) return const [];
  }
  return ref
      .watch(territoryRepositoryProvider)
      .standings(scope: scope, crewId: crewId);
}
