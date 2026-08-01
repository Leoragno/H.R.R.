// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$tripRemoteDatasourceHash() =>
    r'648f25a4561a2fceff26daed052f64f5e9c0a6ea';

/// See also [tripRemoteDatasource].
@ProviderFor(tripRemoteDatasource)
final tripRemoteDatasourceProvider =
    AutoDisposeProvider<TripRemoteDatasource>.internal(
  tripRemoteDatasource,
  name: r'tripRemoteDatasourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$tripRemoteDatasourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TripRemoteDatasourceRef = AutoDisposeProviderRef<TripRemoteDatasource>;
String _$tripRepositoryHash() => r'bbf9f8df45c8e8f7ece64a1f90a3bddf476244f9';

/// See also [tripRepository].
@ProviderFor(tripRepository)
final tripRepositoryProvider = AutoDisposeProvider<TripRepository>.internal(
  tripRepository,
  name: r'tripRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$tripRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TripRepositoryRef = AutoDisposeProviderRef<TripRepository>;
String _$recentTripsHash() => r'30ba34fab2b6758c1aa721b1eebbcaf7e790be0e';

/// Ultimi viaggi completati dell'utente corrente (storico), usato dal
/// profilo per la cronologia viaggi.
///
/// Copied from [recentTrips].
@ProviderFor(recentTrips)
final recentTripsProvider = AutoDisposeFutureProvider<List<Trip>>.internal(
  recentTrips,
  name: r'recentTripsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$recentTripsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RecentTripsRef = AutoDisposeFutureProviderRef<List<Trip>>;
String _$tripByIdHash() => r'd784b72c55b8fdbf1889a3bc1980e312e86a688d';

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

/// See also [tripById].
@ProviderFor(tripById)
const tripByIdProvider = TripByIdFamily();

/// See also [tripById].
class TripByIdFamily extends Family<AsyncValue<Trip>> {
  /// See also [tripById].
  const TripByIdFamily();

  /// See also [tripById].
  TripByIdProvider call(
    String tripId,
  ) {
    return TripByIdProvider(
      tripId,
    );
  }

  @override
  TripByIdProvider getProviderOverride(
    covariant TripByIdProvider provider,
  ) {
    return call(
      provider.tripId,
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
  String? get name => r'tripByIdProvider';
}

/// See also [tripById].
class TripByIdProvider extends AutoDisposeFutureProvider<Trip> {
  /// See also [tripById].
  TripByIdProvider(
    String tripId,
  ) : this._internal(
          (ref) => tripById(
            ref as TripByIdRef,
            tripId,
          ),
          from: tripByIdProvider,
          name: r'tripByIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$tripByIdHash,
          dependencies: TripByIdFamily._dependencies,
          allTransitiveDependencies: TripByIdFamily._allTransitiveDependencies,
          tripId: tripId,
        );

  TripByIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.tripId,
  }) : super.internal();

  final String tripId;

  @override
  Override overrideWith(
    FutureOr<Trip> Function(TripByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TripByIdProvider._internal(
        (ref) => create(ref as TripByIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        tripId: tripId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Trip> createElement() {
    return _TripByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TripByIdProvider && other.tripId == tripId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, tripId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TripByIdRef on AutoDisposeFutureProviderRef<Trip> {
  /// The parameter `tripId` of this provider.
  String get tripId;
}

class _TripByIdProviderElement extends AutoDisposeFutureProviderElement<Trip>
    with TripByIdRef {
  _TripByIdProviderElement(super.provider);

  @override
  String get tripId => (origin as TripByIdProvider).tripId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
