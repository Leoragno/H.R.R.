// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'leaderboard_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$leaderboardRemoteDatasourceHash() =>
    r'b891180af7b8bd95ab58254a07b67240b4d0392c';

/// See also [leaderboardRemoteDatasource].
@ProviderFor(leaderboardRemoteDatasource)
final leaderboardRemoteDatasourceProvider =
    AutoDisposeProvider<LeaderboardRemoteDatasource>.internal(
  leaderboardRemoteDatasource,
  name: r'leaderboardRemoteDatasourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$leaderboardRemoteDatasourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LeaderboardRemoteDatasourceRef
    = AutoDisposeProviderRef<LeaderboardRemoteDatasource>;
String _$leaderboardRepositoryHash() =>
    r'e86ada5f80767872a2c80d1bb8f8e1607eb70941';

/// See also [leaderboardRepository].
@ProviderFor(leaderboardRepository)
final leaderboardRepositoryProvider =
    AutoDisposeProvider<LeaderboardRepository>.internal(
  leaderboardRepository,
  name: r'leaderboardRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$leaderboardRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LeaderboardRepositoryRef
    = AutoDisposeProviderRef<LeaderboardRepository>;
String _$leaderboardHash() => r'129e451b259d7b2050fd75f53e01042f41a74659';

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

/// Classifica per metrica + periodo + scope (family sui tre filtri della
/// schermata). La metrica determina anche l'ordinamento lato server:
/// cambiarla rifà sempre la chiamata (niente riordino lato client).
/// scope=crew usa la crew dell'utente corrente ([myProfileProvider]): se
/// non ha una crew la lista è vuota, mai un errore.
///
/// Copied from [leaderboard].
@ProviderFor(leaderboard)
const leaderboardProvider = LeaderboardFamily();

/// Classifica per metrica + periodo + scope (family sui tre filtri della
/// schermata). La metrica determina anche l'ordinamento lato server:
/// cambiarla rifà sempre la chiamata (niente riordino lato client).
/// scope=crew usa la crew dell'utente corrente ([myProfileProvider]): se
/// non ha una crew la lista è vuota, mai un errore.
///
/// Copied from [leaderboard].
class LeaderboardFamily extends Family<AsyncValue<List<LeaderboardEntry>>> {
  /// Classifica per metrica + periodo + scope (family sui tre filtri della
  /// schermata). La metrica determina anche l'ordinamento lato server:
  /// cambiarla rifà sempre la chiamata (niente riordino lato client).
  /// scope=crew usa la crew dell'utente corrente ([myProfileProvider]): se
  /// non ha una crew la lista è vuota, mai un errore.
  ///
  /// Copied from [leaderboard].
  const LeaderboardFamily();

  /// Classifica per metrica + periodo + scope (family sui tre filtri della
  /// schermata). La metrica determina anche l'ordinamento lato server:
  /// cambiarla rifà sempre la chiamata (niente riordino lato client).
  /// scope=crew usa la crew dell'utente corrente ([myProfileProvider]): se
  /// non ha una crew la lista è vuota, mai un errore.
  ///
  /// Copied from [leaderboard].
  LeaderboardProvider call(
    LeaderboardMetric metric,
    LeaderboardPeriod period,
    LeaderboardScope scope,
  ) {
    return LeaderboardProvider(
      metric,
      period,
      scope,
    );
  }

  @override
  LeaderboardProvider getProviderOverride(
    covariant LeaderboardProvider provider,
  ) {
    return call(
      provider.metric,
      provider.period,
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
  String? get name => r'leaderboardProvider';
}

/// Classifica per metrica + periodo + scope (family sui tre filtri della
/// schermata). La metrica determina anche l'ordinamento lato server:
/// cambiarla rifà sempre la chiamata (niente riordino lato client).
/// scope=crew usa la crew dell'utente corrente ([myProfileProvider]): se
/// non ha una crew la lista è vuota, mai un errore.
///
/// Copied from [leaderboard].
class LeaderboardProvider
    extends AutoDisposeFutureProvider<List<LeaderboardEntry>> {
  /// Classifica per metrica + periodo + scope (family sui tre filtri della
  /// schermata). La metrica determina anche l'ordinamento lato server:
  /// cambiarla rifà sempre la chiamata (niente riordino lato client).
  /// scope=crew usa la crew dell'utente corrente ([myProfileProvider]): se
  /// non ha una crew la lista è vuota, mai un errore.
  ///
  /// Copied from [leaderboard].
  LeaderboardProvider(
    LeaderboardMetric metric,
    LeaderboardPeriod period,
    LeaderboardScope scope,
  ) : this._internal(
          (ref) => leaderboard(
            ref as LeaderboardRef,
            metric,
            period,
            scope,
          ),
          from: leaderboardProvider,
          name: r'leaderboardProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$leaderboardHash,
          dependencies: LeaderboardFamily._dependencies,
          allTransitiveDependencies:
              LeaderboardFamily._allTransitiveDependencies,
          metric: metric,
          period: period,
          scope: scope,
        );

  LeaderboardProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.metric,
    required this.period,
    required this.scope,
  }) : super.internal();

  final LeaderboardMetric metric;
  final LeaderboardPeriod period;
  final LeaderboardScope scope;

  @override
  Override overrideWith(
    FutureOr<List<LeaderboardEntry>> Function(LeaderboardRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LeaderboardProvider._internal(
        (ref) => create(ref as LeaderboardRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        metric: metric,
        period: period,
        scope: scope,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<LeaderboardEntry>> createElement() {
    return _LeaderboardProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LeaderboardProvider &&
        other.metric == metric &&
        other.period == period &&
        other.scope == scope;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, metric.hashCode);
    hash = _SystemHash.combine(hash, period.hashCode);
    hash = _SystemHash.combine(hash, scope.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LeaderboardRef on AutoDisposeFutureProviderRef<List<LeaderboardEntry>> {
  /// The parameter `metric` of this provider.
  LeaderboardMetric get metric;

  /// The parameter `period` of this provider.
  LeaderboardPeriod get period;

  /// The parameter `scope` of this provider.
  LeaderboardScope get scope;
}

class _LeaderboardProviderElement
    extends AutoDisposeFutureProviderElement<List<LeaderboardEntry>>
    with LeaderboardRef {
  _LeaderboardProviderElement(super.provider);

  @override
  LeaderboardMetric get metric => (origin as LeaderboardProvider).metric;
  @override
  LeaderboardPeriod get period => (origin as LeaderboardProvider).period;
  @override
  LeaderboardScope get scope => (origin as LeaderboardProvider).scope;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
