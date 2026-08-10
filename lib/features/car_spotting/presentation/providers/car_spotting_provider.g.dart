// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'car_spotting_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$carSpottingRemoteDatasourceHash() =>
    r'fa4cc94868473bad66c8f19429740df4fee34c91';

/// See also [carSpottingRemoteDatasource].
@ProviderFor(carSpottingRemoteDatasource)
final carSpottingRemoteDatasourceProvider =
    AutoDisposeProvider<CarSpottingRemoteDatasource>.internal(
  carSpottingRemoteDatasource,
  name: r'carSpottingRemoteDatasourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$carSpottingRemoteDatasourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CarSpottingRemoteDatasourceRef
    = AutoDisposeProviderRef<CarSpottingRemoteDatasource>;
String _$carSpottingRepositoryHash() =>
    r'0c72913ccdce0eb01a81677ef7b073c981e47946';

/// See also [carSpottingRepository].
@ProviderFor(carSpottingRepository)
final carSpottingRepositoryProvider =
    AutoDisposeProvider<CarSpottingRepository>.internal(
  carSpottingRepository,
  name: r'carSpottingRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$carSpottingRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CarSpottingRepositoryRef
    = AutoDisposeProviderRef<CarSpottingRepository>;
String _$spotsFeedHash() => r'5d0e11307c03a39420a3d55ede045cbbf5b5d369';

/// Feed pubblico, più recenti prima.
///
/// Copied from [spotsFeed].
@ProviderFor(spotsFeed)
final spotsFeedProvider = AutoDisposeFutureProvider<List<Spot>>.internal(
  spotsFeed,
  name: r'spotsFeedProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$spotsFeedHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SpotsFeedRef = AutoDisposeFutureProviderRef<List<Spot>>;
String _$spotByIdHash() => r'1d5e58e3e3ae66ea911e6b44395d5b5daa9159b2';

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

/// See also [spotById].
@ProviderFor(spotById)
const spotByIdProvider = SpotByIdFamily();

/// See also [spotById].
class SpotByIdFamily extends Family<AsyncValue<Spot>> {
  /// See also [spotById].
  const SpotByIdFamily();

  /// See also [spotById].
  SpotByIdProvider call(
    String spotId,
  ) {
    return SpotByIdProvider(
      spotId,
    );
  }

  @override
  SpotByIdProvider getProviderOverride(
    covariant SpotByIdProvider provider,
  ) {
    return call(
      provider.spotId,
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
  String? get name => r'spotByIdProvider';
}

/// See also [spotById].
class SpotByIdProvider extends AutoDisposeFutureProvider<Spot> {
  /// See also [spotById].
  SpotByIdProvider(
    String spotId,
  ) : this._internal(
          (ref) => spotById(
            ref as SpotByIdRef,
            spotId,
          ),
          from: spotByIdProvider,
          name: r'spotByIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$spotByIdHash,
          dependencies: SpotByIdFamily._dependencies,
          allTransitiveDependencies: SpotByIdFamily._allTransitiveDependencies,
          spotId: spotId,
        );

  SpotByIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.spotId,
  }) : super.internal();

  final String spotId;

  @override
  Override overrideWith(
    FutureOr<Spot> Function(SpotByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SpotByIdProvider._internal(
        (ref) => create(ref as SpotByIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        spotId: spotId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Spot> createElement() {
    return _SpotByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SpotByIdProvider && other.spotId == spotId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, spotId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SpotByIdRef on AutoDisposeFutureProviderRef<Spot> {
  /// The parameter `spotId` of this provider.
  String get spotId;
}

class _SpotByIdProviderElement extends AutoDisposeFutureProviderElement<Spot>
    with SpotByIdRef {
  _SpotByIdProviderElement(super.provider);

  @override
  String get spotId => (origin as SpotByIdProvider).spotId;
}

String _$topRatedSpotsHash() => r'c2a5f1aaa027d80c95412cc5191b84693256ad82';

/// Top auto della community — nessuna soglia minima di voti, ordinate
/// solo per media stelle.
///
/// Copied from [topRatedSpots].
@ProviderFor(topRatedSpots)
final topRatedSpotsProvider = AutoDisposeFutureProvider<List<Spot>>.internal(
  topRatedSpots,
  name: r'topRatedSpotsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$topRatedSpotsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TopRatedSpotsRef = AutoDisposeFutureProviderRef<List<Spot>>;
String _$myRatingForSpotHash() => r'44635dd5f2db60151ce1739783177dfb603ed060';

/// Il proprio voto per uno spot (null se non ancora votato). Mai il voto
/// di qualcun altro — RLS lo impedirebbe comunque.
///
/// Copied from [myRatingForSpot].
@ProviderFor(myRatingForSpot)
const myRatingForSpotProvider = MyRatingForSpotFamily();

/// Il proprio voto per uno spot (null se non ancora votato). Mai il voto
/// di qualcun altro — RLS lo impedirebbe comunque.
///
/// Copied from [myRatingForSpot].
class MyRatingForSpotFamily extends Family<AsyncValue<SpotRating?>> {
  /// Il proprio voto per uno spot (null se non ancora votato). Mai il voto
  /// di qualcun altro — RLS lo impedirebbe comunque.
  ///
  /// Copied from [myRatingForSpot].
  const MyRatingForSpotFamily();

  /// Il proprio voto per uno spot (null se non ancora votato). Mai il voto
  /// di qualcun altro — RLS lo impedirebbe comunque.
  ///
  /// Copied from [myRatingForSpot].
  MyRatingForSpotProvider call(
    String spotId,
  ) {
    return MyRatingForSpotProvider(
      spotId,
    );
  }

  @override
  MyRatingForSpotProvider getProviderOverride(
    covariant MyRatingForSpotProvider provider,
  ) {
    return call(
      provider.spotId,
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
  String? get name => r'myRatingForSpotProvider';
}

/// Il proprio voto per uno spot (null se non ancora votato). Mai il voto
/// di qualcun altro — RLS lo impedirebbe comunque.
///
/// Copied from [myRatingForSpot].
class MyRatingForSpotProvider extends AutoDisposeFutureProvider<SpotRating?> {
  /// Il proprio voto per uno spot (null se non ancora votato). Mai il voto
  /// di qualcun altro — RLS lo impedirebbe comunque.
  ///
  /// Copied from [myRatingForSpot].
  MyRatingForSpotProvider(
    String spotId,
  ) : this._internal(
          (ref) => myRatingForSpot(
            ref as MyRatingForSpotRef,
            spotId,
          ),
          from: myRatingForSpotProvider,
          name: r'myRatingForSpotProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$myRatingForSpotHash,
          dependencies: MyRatingForSpotFamily._dependencies,
          allTransitiveDependencies:
              MyRatingForSpotFamily._allTransitiveDependencies,
          spotId: spotId,
        );

  MyRatingForSpotProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.spotId,
  }) : super.internal();

  final String spotId;

  @override
  Override overrideWith(
    FutureOr<SpotRating?> Function(MyRatingForSpotRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MyRatingForSpotProvider._internal(
        (ref) => create(ref as MyRatingForSpotRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        spotId: spotId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<SpotRating?> createElement() {
    return _MyRatingForSpotProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MyRatingForSpotProvider && other.spotId == spotId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, spotId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MyRatingForSpotRef on AutoDisposeFutureProviderRef<SpotRating?> {
  /// The parameter `spotId` of this provider.
  String get spotId;
}

class _MyRatingForSpotProviderElement
    extends AutoDisposeFutureProviderElement<SpotRating?>
    with MyRatingForSpotRef {
  _MyRatingForSpotProviderElement(super.provider);

  @override
  String get spotId => (origin as MyRatingForSpotProvider).spotId;
}

String _$spotCommentsHash() => r'63c87dc25fb43f7ffd4fe3fcd096e83700774077';

/// See also [spotComments].
@ProviderFor(spotComments)
const spotCommentsProvider = SpotCommentsFamily();

/// See also [spotComments].
class SpotCommentsFamily extends Family<AsyncValue<List<SpotComment>>> {
  /// See also [spotComments].
  const SpotCommentsFamily();

  /// See also [spotComments].
  SpotCommentsProvider call(
    String spotId,
  ) {
    return SpotCommentsProvider(
      spotId,
    );
  }

  @override
  SpotCommentsProvider getProviderOverride(
    covariant SpotCommentsProvider provider,
  ) {
    return call(
      provider.spotId,
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
  String? get name => r'spotCommentsProvider';
}

/// See also [spotComments].
class SpotCommentsProvider
    extends AutoDisposeFutureProvider<List<SpotComment>> {
  /// See also [spotComments].
  SpotCommentsProvider(
    String spotId,
  ) : this._internal(
          (ref) => spotComments(
            ref as SpotCommentsRef,
            spotId,
          ),
          from: spotCommentsProvider,
          name: r'spotCommentsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$spotCommentsHash,
          dependencies: SpotCommentsFamily._dependencies,
          allTransitiveDependencies:
              SpotCommentsFamily._allTransitiveDependencies,
          spotId: spotId,
        );

  SpotCommentsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.spotId,
  }) : super.internal();

  final String spotId;

  @override
  Override overrideWith(
    FutureOr<List<SpotComment>> Function(SpotCommentsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SpotCommentsProvider._internal(
        (ref) => create(ref as SpotCommentsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        spotId: spotId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<SpotComment>> createElement() {
    return _SpotCommentsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SpotCommentsProvider && other.spotId == spotId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, spotId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SpotCommentsRef on AutoDisposeFutureProviderRef<List<SpotComment>> {
  /// The parameter `spotId` of this provider.
  String get spotId;
}

class _SpotCommentsProviderElement
    extends AutoDisposeFutureProviderElement<List<SpotComment>>
    with SpotCommentsRef {
  _SpotCommentsProviderElement(super.provider);

  @override
  String get spotId => (origin as SpotCommentsProvider).spotId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
