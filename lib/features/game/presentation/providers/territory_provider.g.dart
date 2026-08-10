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
    r'a0e96391161e27925acd04eac12a4417351944d0';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Classifica territorio per scope (family sul tab Globale/La mia crew).
/// La metrica selezionata nei 4 tab del pannello (GENERALE/TOP LADRI/...)
/// riordina la stessa lista lato client — la RPC restituisce già tutti e
/// 4 gli aggregati per riga, non serve rifare la chiamata per cambiare
/// ordinamento (stesso principio di `standings()` nel mockup).
/// scope=crew usa la crew dell'utente corrente ([myProfileProvider]): se
/// non ha una crew la lista è vuota, mai un errore.
///
/// Copied from [territoryStandings].
@ProviderFor(territoryStandings)
const territoryStandingsProvider = TerritoryStandingsFamily();

/// Classifica territorio per scope (family sul tab Globale/La mia crew).
/// La metrica selezionata nei 4 tab del pannello (GENERALE/TOP LADRI/...)
/// riordina la stessa lista lato client — la RPC restituisce già tutti e
/// 4 gli aggregati per riga, non serve rifare la chiamata per cambiare
/// ordinamento (stesso principio di `standings()` nel mockup).
/// scope=crew usa la crew dell'utente corrente ([myProfileProvider]): se
/// non ha una crew la lista è vuota, mai un errore.
///
/// Copied from [territoryStandings].
class TerritoryStandingsFamily
    extends Family<AsyncValue<List<TerritoryStanding>>> {
  /// Classifica territorio per scope (family sul tab Globale/La mia crew).
  /// La metrica selezionata nei 4 tab del pannello (GENERALE/TOP LADRI/...)
  /// riordina la stessa lista lato client — la RPC restituisce già tutti e
  /// 4 gli aggregati per riga, non serve rifare la chiamata per cambiare
  /// ordinamento (stesso principio di `standings()` nel mockup).
  /// scope=crew usa la crew dell'utente corrente ([myProfileProvider]): se
  /// non ha una crew la lista è vuota, mai un errore.
  ///
  /// Copied from [territoryStandings].
  const TerritoryStandingsFamily();

  /// Classifica territorio per scope (family sul tab Globale/La mia crew).
  /// La metrica selezionata nei 4 tab del pannello (GENERALE/TOP LADRI/...)
  /// riordina la stessa lista lato client — la RPC restituisce già tutti e
  /// 4 gli aggregati per riga, non serve rifare la chiamata per cambiare
  /// ordinamento (stesso principio di `standings()` nel mockup).
  /// scope=crew usa la crew dell'utente corrente ([myProfileProvider]): se
  /// non ha una crew la lista è vuota, mai un errore.
  ///
  /// Copied from [territoryStandings].
  TerritoryStandingsProvider call(
    TerritoryScope scope,
  ) {
    return TerritoryStandingsProvider(
      scope,
    );
  }

  @override
  TerritoryStandingsProvider getProviderOverride(
    covariant TerritoryStandingsProvider provider,
  ) {
    return call(
      provider.scope,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'territoryStandingsProvider';
}

/// Classifica territorio per scope (family sul tab Globale/La mia crew).
/// La metrica selezionata nei 4 tab del pannello (GENERALE/TOP LADRI/...)
/// riordina la stessa lista lato client — la RPC restituisce già tutti e
/// 4 gli aggregati per riga, non serve rifare la chiamata per cambiare
/// ordinamento (stesso principio di `standings()` nel mockup).
/// scope=crew usa la crew dell'utente corrente ([myProfileProvider]): se
/// non ha una crew la lista è vuota, mai un errore.
///
/// Copied from [territoryStandings].
class TerritoryStandingsProvider
    extends AutoDisposeFutureProvider<List<TerritoryStanding>> {
  /// Classifica territorio per scope (family sul tab Globale/La mia crew).
  /// La metrica selezionata nei 4 tab del pannello (GENERALE/TOP LADRI/...)
  /// riordina la stessa lista lato client — la RPC restituisce già tutti e
  /// 4 gli aggregati per riga, non serve rifare la chiamata per cambiare
  /// ordinamento (stesso principio di `standings()` nel mockup).
  /// scope=crew usa la crew dell'utente corrente ([myProfileProvider]): se
  /// non ha una crew la lista è vuota, mai un errore.
  ///
  /// Copied from [territoryStandings].
  TerritoryStandingsProvider(
    TerritoryScope scope,
  ) : this._internal(
          (ref) => territoryStandings(
            ref as TerritoryStandingsRef,
            scope,
          ),
          from: territoryStandingsProvider,
          name: r'territoryStandingsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$territoryStandingsHash,
          dependencies: TerritoryStandingsFamily._dependencies,
          allTransitiveDependencies:
              TerritoryStandingsFamily._allTransitiveDependencies,
          scope: scope,
        );

  TerritoryStandingsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.scope,
  }) : super.internal();

  final TerritoryScope scope;

  @override
  Override overrideWith(
    FutureOr<List<TerritoryStanding>> Function(TerritoryStandingsRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TerritoryStandingsProvider._internal(
        (ref) => create(ref as TerritoryStandingsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        scope: scope,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<TerritoryStanding>> createElement() {
    return _TerritoryStandingsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TerritoryStandingsProvider && other.scope == scope;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, scope.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TerritoryStandingsRef
    on AutoDisposeFutureProviderRef<List<TerritoryStanding>> {
  /// The parameter `scope` of this provider.
  TerritoryScope get scope;
}

class _TerritoryStandingsProviderElement
    extends AutoDisposeFutureProviderElement<List<TerritoryStanding>>
    with TerritoryStandingsRef {
  _TerritoryStandingsProviderElement(super.provider);

  @override
  TerritoryScope get scope => (origin as TerritoryStandingsProvider).scope;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
