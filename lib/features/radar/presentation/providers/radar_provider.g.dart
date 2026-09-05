// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'radar_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$overpassRemoteDatasourceHash() =>
    r'e253d2fd51b03a090d0f84336bef30985a134f99';

/// See also [overpassRemoteDatasource].
@ProviderFor(overpassRemoteDatasource)
final overpassRemoteDatasourceProvider =
    AutoDisposeProvider<OverpassRemoteDatasource>.internal(
  overpassRemoteDatasource,
  name: r'overpassRemoteDatasourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$overpassRemoteDatasourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OverpassRemoteDatasourceRef
    = AutoDisposeProviderRef<OverpassRemoteDatasource>;
String _$openGatsoPoiRemoteDatasourceHash() =>
    r'45f57f32e1164718cea4d0f4687b3d63d5b42854';

/// See also [openGatsoPoiRemoteDatasource].
@ProviderFor(openGatsoPoiRemoteDatasource)
final openGatsoPoiRemoteDatasourceProvider =
    Provider<OpenGatsoPoiRemoteDatasource>.internal(
  openGatsoPoiRemoteDatasource,
  name: r'openGatsoPoiRemoteDatasourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$openGatsoPoiRemoteDatasourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OpenGatsoPoiRemoteDatasourceRef
    = ProviderRef<OpenGatsoPoiRemoteDatasource>;
String _$wazeRemoteDatasourceHash() =>
    r'79876cab15874a72b5d5ea000971e4d0fb1ae9ce';

/// See also [wazeRemoteDatasource].
@ProviderFor(wazeRemoteDatasource)
final wazeRemoteDatasourceProvider =
    AutoDisposeProvider<WazeRemoteDatasource>.internal(
  wazeRemoteDatasource,
  name: r'wazeRemoteDatasourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$wazeRemoteDatasourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WazeRemoteDatasourceRef = AutoDisposeProviderRef<WazeRemoteDatasource>;
String _$communityReportsRemoteDatasourceHash() =>
    r'ba83cc1372e5e7b37f1c109638640cdd433e6f75';

/// See also [communityReportsRemoteDatasource].
@ProviderFor(communityReportsRemoteDatasource)
final communityReportsRemoteDatasourceProvider =
    AutoDisposeProvider<CommunityReportsRemoteDatasource>.internal(
  communityReportsRemoteDatasource,
  name: r'communityReportsRemoteDatasourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$communityReportsRemoteDatasourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CommunityReportsRemoteDatasourceRef
    = AutoDisposeProviderRef<CommunityReportsRemoteDatasource>;
String _$radarRepositoryHash() => r'e28e4286515745c56a708262af42bacd8e65a2c8';

/// See also [radarRepository].
@ProviderFor(radarRepository)
final radarRepositoryProvider = AutoDisposeProvider<RadarRepository>.internal(
  radarRepository,
  name: r'radarRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$radarRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RadarRepositoryRef = AutoDisposeProviderRef<RadarRepository>;
String _$veloxApiEventsHash() => r'0caaa849eaf740f1c318650774ae596b9c0e0beb';

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

/// See also [veloxApiEvents].
@ProviderFor(veloxApiEvents)
const veloxApiEventsProvider = VeloxApiEventsFamily();

/// See also [veloxApiEvents].
class VeloxApiEventsFamily extends Family<AsyncValue<List<RadarEvent>>> {
  /// See also [veloxApiEvents].
  const VeloxApiEventsFamily();

  /// See also [veloxApiEvents].
  VeloxApiEventsProvider call(
    RadarBounds bounds,
  ) {
    return VeloxApiEventsProvider(
      bounds,
    );
  }

  @override
  VeloxApiEventsProvider getProviderOverride(
    covariant VeloxApiEventsProvider provider,
  ) {
    return call(
      provider.bounds,
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
  String? get name => r'veloxApiEventsProvider';
}

/// See also [veloxApiEvents].
class VeloxApiEventsProvider
    extends AutoDisposeFutureProvider<List<RadarEvent>> {
  /// See also [veloxApiEvents].
  VeloxApiEventsProvider(
    RadarBounds bounds,
  ) : this._internal(
          (ref) => veloxApiEvents(
            ref as VeloxApiEventsRef,
            bounds,
          ),
          from: veloxApiEventsProvider,
          name: r'veloxApiEventsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$veloxApiEventsHash,
          dependencies: VeloxApiEventsFamily._dependencies,
          allTransitiveDependencies:
              VeloxApiEventsFamily._allTransitiveDependencies,
          bounds: bounds,
        );

  VeloxApiEventsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.bounds,
  }) : super.internal();

  final RadarBounds bounds;

  @override
  Override overrideWith(
    FutureOr<List<RadarEvent>> Function(VeloxApiEventsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: VeloxApiEventsProvider._internal(
        (ref) => create(ref as VeloxApiEventsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        bounds: bounds,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<RadarEvent>> createElement() {
    return _VeloxApiEventsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is VeloxApiEventsProvider && other.bounds == bounds;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, bounds.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin VeloxApiEventsRef on AutoDisposeFutureProviderRef<List<RadarEvent>> {
  /// The parameter `bounds` of this provider.
  RadarBounds get bounds;
}

class _VeloxApiEventsProviderElement
    extends AutoDisposeFutureProviderElement<List<RadarEvent>>
    with VeloxApiEventsRef {
  _VeloxApiEventsProviderElement(super.provider);

  @override
  RadarBounds get bounds => (origin as VeloxApiEventsProvider).bounds;
}

String _$pattugliaApiEventsHash() =>
    r'97ab6ba3db77353b976dd4d5eed2faede857d561';

/// See also [pattugliaApiEvents].
@ProviderFor(pattugliaApiEvents)
const pattugliaApiEventsProvider = PattugliaApiEventsFamily();

/// See also [pattugliaApiEvents].
class PattugliaApiEventsFamily extends Family<AsyncValue<List<RadarEvent>>> {
  /// See also [pattugliaApiEvents].
  const PattugliaApiEventsFamily();

  /// See also [pattugliaApiEvents].
  PattugliaApiEventsProvider call(
    RadarBounds bounds,
  ) {
    return PattugliaApiEventsProvider(
      bounds,
    );
  }

  @override
  PattugliaApiEventsProvider getProviderOverride(
    covariant PattugliaApiEventsProvider provider,
  ) {
    return call(
      provider.bounds,
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
  String? get name => r'pattugliaApiEventsProvider';
}

/// See also [pattugliaApiEvents].
class PattugliaApiEventsProvider
    extends AutoDisposeFutureProvider<List<RadarEvent>> {
  /// See also [pattugliaApiEvents].
  PattugliaApiEventsProvider(
    RadarBounds bounds,
  ) : this._internal(
          (ref) => pattugliaApiEvents(
            ref as PattugliaApiEventsRef,
            bounds,
          ),
          from: pattugliaApiEventsProvider,
          name: r'pattugliaApiEventsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$pattugliaApiEventsHash,
          dependencies: PattugliaApiEventsFamily._dependencies,
          allTransitiveDependencies:
              PattugliaApiEventsFamily._allTransitiveDependencies,
          bounds: bounds,
        );

  PattugliaApiEventsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.bounds,
  }) : super.internal();

  final RadarBounds bounds;

  @override
  Override overrideWith(
    FutureOr<List<RadarEvent>> Function(PattugliaApiEventsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PattugliaApiEventsProvider._internal(
        (ref) => create(ref as PattugliaApiEventsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        bounds: bounds,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<RadarEvent>> createElement() {
    return _PattugliaApiEventsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PattugliaApiEventsProvider && other.bounds == bounds;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, bounds.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PattugliaApiEventsRef on AutoDisposeFutureProviderRef<List<RadarEvent>> {
  /// The parameter `bounds` of this provider.
  RadarBounds get bounds;
}

class _PattugliaApiEventsProviderElement
    extends AutoDisposeFutureProviderElement<List<RadarEvent>>
    with PattugliaApiEventsRef {
  _PattugliaApiEventsProviderElement(super.provider);

  @override
  RadarBounds get bounds => (origin as PattugliaApiEventsProvider).bounds;
}

String _$currentVeloxApiEventsHash() =>
    r'ae84bab3b7b4741ac46415f89552ed30ed20c45a';

/// Comodo per la UI (card monitoraggio, mappa Guida): stessa lista di
/// [veloxApiEvents] ma già agganciata alla bounding box corrente, senza
/// che il chiamante debba conoscere/propagare [RadarBounds].
///
/// Copied from [currentVeloxApiEvents].
@ProviderFor(currentVeloxApiEvents)
final currentVeloxApiEventsProvider =
    AutoDisposeFutureProvider<List<RadarEvent>>.internal(
  currentVeloxApiEvents,
  name: r'currentVeloxApiEventsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentVeloxApiEventsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentVeloxApiEventsRef
    = AutoDisposeFutureProviderRef<List<RadarEvent>>;
String _$currentPattugliaApiEventsHash() =>
    r'd45991e3417e72ac8321669700f63d8f4e4d6277';

/// See also [currentPattugliaApiEvents].
@ProviderFor(currentPattugliaApiEvents)
final currentPattugliaApiEventsProvider =
    AutoDisposeFutureProvider<List<RadarEvent>>.internal(
  currentPattugliaApiEvents,
  name: r'currentPattugliaApiEventsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentPattugliaApiEventsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentPattugliaApiEventsRef
    = AutoDisposeFutureProviderRef<List<RadarEvent>>;
String _$communityVeloxReportsHash() =>
    r'38a9d905084e04d11cb3c42cfbcde13eb637fae9';

/// See also [communityVeloxReports].
@ProviderFor(communityVeloxReports)
final communityVeloxReportsProvider =
    AutoDisposeProvider<List<RadarEvent>>.internal(
  communityVeloxReports,
  name: r'communityVeloxReportsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$communityVeloxReportsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CommunityVeloxReportsRef = AutoDisposeProviderRef<List<RadarEvent>>;
String _$communityPattugliaReportsHash() =>
    r'2089a958ed5b9b8c009dc5db2bc26de8fb0d8da6';

/// See also [communityPattugliaReports].
@ProviderFor(communityPattugliaReports)
final communityPattugliaReportsProvider =
    AutoDisposeProvider<List<RadarEvent>>.internal(
  communityPattugliaReports,
  name: r'communityPattugliaReportsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$communityPattugliaReportsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CommunityPattugliaReportsRef = AutoDisposeProviderRef<List<RadarEvent>>;
String _$homeMapMarkersHash() => r'0b53cc73c69a264932a9ce6b0cb975bd00a918bd';

/// Tutti gli eventi da disegnare sulla mappa Guida (le 4 categorie
/// insieme) per la bounding box corrente — unico provider osservato da
/// [HomeMapBackground] per sincronizzare i marker nativi.
///
/// Copied from [homeMapMarkers].
@ProviderFor(homeMapMarkers)
final homeMapMarkersProvider =
    AutoDisposeFutureProvider<List<RadarEvent>>.internal(
  homeMapMarkers,
  name: r'homeMapMarkersProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$homeMapMarkersHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HomeMapMarkersRef = AutoDisposeFutureProviderRef<List<RadarEvent>>;
String _$radarModeControllerHash() =>
    r'ebe108d392fbd21b7ef556e63060008b53b2e6d1';

/// On/off dell'intera modalità: mappa (marker), card di monitoraggio,
/// segnalazioni community e avviso di prossimità durante DRIVE dipendono
/// tutti da questo interruttore, persistito così resta impostato fra un
/// riavvio e l'altro. Da spento, nessuno dei provider sotto fa richieste
/// (rete o realtime) — non è solo un "nascondi la UI".
///
/// Copied from [RadarModeController].
@ProviderFor(RadarModeController)
final radarModeControllerProvider =
    NotifierProvider<RadarModeController, bool>.internal(
  RadarModeController.new,
  name: r'radarModeControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$radarModeControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$RadarModeController = Notifier<bool>;
String _$mapBoundsControllerHash() =>
    r'c52d8294a8f9e5913a8000f830225d0d0f48a342';

/// Ultima bounding box visibile della mappa Guida, aggiornata da
/// [HomeMapBackground] su `onCameraIdle` (già debounced lì). `keepAlive`
/// perché deve restare disponibile anche quando la mappa non è a schermo
/// (es. durante DRIVE, se si vuole comunque il conteggio dell'ultima
/// zona vista) invece di azzerarsi al primo dispose.
///
/// Copied from [MapBoundsController].
@ProviderFor(MapBoundsController)
final mapBoundsControllerProvider =
    NotifierProvider<MapBoundsController, RadarBounds?>.internal(
  MapBoundsController.new,
  name: r'mapBoundsControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$mapBoundsControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MapBoundsController = Notifier<RadarBounds?>;
String _$communityReportsControllerHash() =>
    r'349caa17e97cf9138cc92a7e43dee63c54111d70';

/// Segnalazioni Velox+Pattuglia di tutti gli utenti, aggiornate in realtime
/// via Supabase e già private delle voci scadute (90 minuti, vedi
/// [RadarEvent.isExpired]) — sia ad ogni nuovo evento dal DB, sia
/// periodicamente per chi scade "a riposo" senza che nel frattempo arrivi
/// un nuovo insert altrui (stesso principio dello staleness timer di
/// LiveMapController).
///
/// Copied from [CommunityReportsController].
@ProviderFor(CommunityReportsController)
final communityReportsControllerProvider = AutoDisposeNotifierProvider<
    CommunityReportsController, List<RadarEvent>>.internal(
  CommunityReportsController.new,
  name: r'communityReportsControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$communityReportsControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CommunityReportsController = AutoDisposeNotifier<List<RadarEvent>>;
String _$radarActionsControllerHash() =>
    r'dca974d6ba2a33b78a04187483b47d159441e928';

/// See also [RadarActionsController].
@ProviderFor(RadarActionsController)
final radarActionsControllerProvider =
    AutoDisposeAsyncNotifierProvider<RadarActionsController, void>.internal(
  RadarActionsController.new,
  name: r'radarActionsControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$radarActionsControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$RadarActionsController = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
