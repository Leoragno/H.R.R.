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
String _$leaderboardHash() => r'f0fa25391f67a04353447095ca0a1cca32fe262f';

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

/// Classifica globale per metrica + periodo (family sui due filtri della
/// schermata). La metrica determina anche l'ordinamento lato server:
/// cambiarla rifà sempre la chiamata (niente riordino lato client).
///
/// Copied from [leaderboard].
@ProviderFor(leaderboard)
const leaderboardProvider = LeaderboardFamily();

/// Classifica globale per metrica + periodo (family sui due filtri della
/// schermata). La metrica determina anche l'ordinamento lato server:
/// cambiarla rifà sempre la chiamata (niente riordino lato client).
///
/// Copied from [leaderboard].
class LeaderboardFamily extends Family<AsyncValue<List<LeaderboardEntry>>> {
  /// Classifica globale per metrica + periodo (family sui due filtri della
  /// schermata). La metrica determina anche l'ordinamento lato server:
  /// cambiarla rifà sempre la chiamata (niente riordino lato client).
  ///
  /// Copied from [leaderboard].
  const LeaderboardFamily();

  /// Classifica globale per metrica + periodo (family sui due filtri della
  /// schermata). La metrica determina anche l'ordinamento lato server:
  /// cambiarla rifà sempre la chiamata (niente riordino lato client).
  ///
  /// Copied from [leaderboard].
  LeaderboardProvider call(
    LeaderboardMetric metric,
    LeaderboardPeriod period,
  ) {
    return LeaderboardProvider(
      metric,
      period,
    );
  }

  @override
  LeaderboardProvider getProviderOverride(
    covariant LeaderboardProvider provider,
  ) {
    return call(
      provider.metric,
      provider.period,
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

/// Classifica globale per metrica + periodo (family sui due filtri della
/// schermata). La metrica determina anche l'ordinamento lato server:
/// cambiarla rifà sempre la chiamata (niente riordino lato client).
///
/// Copied from [leaderboard].
class LeaderboardProvider
    extends AutoDisposeFutureProvider<List<LeaderboardEntry>> {
  /// Classifica globale per metrica + periodo (family sui due filtri della
  /// schermata). La metrica determina anche l'ordinamento lato server:
  /// cambiarla rifà sempre la chiamata (niente riordino lato client).
  ///
  /// Copied from [leaderboard].
  LeaderboardProvider(
    LeaderboardMetric metric,
    LeaderboardPeriod period,
  ) : this._internal(
          (ref) => leaderboard(
            ref as LeaderboardRef,
            metric,
            period,
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
  }) : super.internal();

  final LeaderboardMetric metric;
  final LeaderboardPeriod period;

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
        other.period == period;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, metric.hashCode);
    hash = _SystemHash.combine(hash, period.hashCode);

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
}

class _LeaderboardProviderElement
    extends AutoDisposeFutureProviderElement<List<LeaderboardEntry>>
    with LeaderboardRef {
  _LeaderboardProviderElement(super.provider);

  @override
  LeaderboardMetric get metric => (origin as LeaderboardProvider).metric;
  @override
  LeaderboardPeriod get period => (origin as LeaderboardProvider).period;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
