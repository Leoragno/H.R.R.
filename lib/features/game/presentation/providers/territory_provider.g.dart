// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'territory_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$territoryRemoteDatasourceHash() =>
    r'e19b659d99d9818860aa4f1b62aad507bff2bc94';

/// See also [territoryRemoteDatasource].
@ProviderFor(territoryRemoteDatasource)
final territoryRemoteDatasourceProvider =
    AutoDisposeProvider<TerritoryRemoteDatasource>.internal(
  territoryRemoteDatasource,
  name: r'territoryRemoteDatasourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$territoryRemoteDatasourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TerritoryRemoteDatasourceRef
    = AutoDisposeProviderRef<TerritoryRemoteDatasource>;
String _$territoryRepositoryHash() =>
    r'dee25bc772e94e1f6d6b19e46c14f2ec6189308f';

/// See also [territoryRepository].
@ProviderFor(territoryRepository)
final territoryRepositoryProvider =
    AutoDisposeProvider<TerritoryRepository>.internal(
  territoryRepository,
  name: r'territoryRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$territoryRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TerritoryRepositoryRef = AutoDisposeProviderRef<TerritoryRepository>;
String _$territoryStandingsHash() =>
    r'69fb5ad421975cf676610885d6a734c8fda1117a';

/// Classifica territorio globale. La metrica selezionata nei 4 tab del
/// pannello (GENERALE/TOP LADRI/...) riordina la stessa lista lato client —
/// la RPC restituisce già tutti e 4 gli aggregati per riga, non serve
/// rifare la chiamata per cambiare ordinamento.
///
/// Copied from [territoryStandings].
@ProviderFor(territoryStandings)
final territoryStandingsProvider =
    AutoDisposeFutureProvider<List<TerritoryStanding>>.internal(
  territoryStandings,
  name: r'territoryStandingsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$territoryStandingsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TerritoryStandingsRef
    = AutoDisposeFutureProviderRef<List<TerritoryStanding>>;
String _$myTerritoriesHash() => r'0e93920540278b3a4bfea3af0c735353bd90e2b5';

/// Tutte le celle possedute dall'utente corrente, dalla più vicina a
/// scadere — per la schermata "I miei territori" (brief, punto 1).
///
/// Copied from [myTerritories].
@ProviderFor(myTerritories)
final myTerritoriesProvider =
    AutoDisposeFutureProvider<List<TerritoryCell>>.internal(
  myTerritories,
  name: r'myTerritoriesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$myTerritoriesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyTerritoriesRef = AutoDisposeFutureProviderRef<List<TerritoryCell>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
