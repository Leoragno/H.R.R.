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
String _$crewReportsRemoteDatasourceHash() =>
    r'22ae5d5262818d282dff99b1e66aaeb567162e3a';

/// See also [crewReportsRemoteDatasource].
@ProviderFor(crewReportsRemoteDatasource)
final crewReportsRemoteDatasourceProvider =
    AutoDisposeProvider<CrewReportsRemoteDatasource>.internal(
  crewReportsRemoteDatasource,
  name: r'crewReportsRemoteDatasourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$crewReportsRemoteDatasourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CrewReportsRemoteDatasourceRef
    = AutoDisposeProviderRef<CrewReportsRemoteDatasource>;
String _$radarRepositoryHash() => r'ba8e4323011d77793edd1963198abfdd976796bf';

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
String _$crewVeloxReportsHash() => r'615d7acb996ccab4aa69ad52708c7bd70523e365';

/// See also [crewVeloxReports].
@ProviderFor(crewVeloxReports)
final crewVeloxReportsProvider = AutoDisposeProvider<List<RadarEvent>>.internal(
  crewVeloxReports,
  name: r'crewVeloxReportsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$crewVeloxReportsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CrewVeloxReportsRef = AutoDisposeProviderRef<List<RadarEvent>>;
String _$crewPattugliaReportsHash() =>
    r'69568909e4cb50eafca8d2b2701ff07f7068225f';

/// See also [crewPattugliaReports].
@ProviderFor(crewPattugliaReports)
final crewPattugliaReportsProvider =
    AutoDisposeProvider<List<RadarEvent>>.internal(
  crewPattugliaReports,
  name: r'crewPattugliaReportsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$crewPattugliaReportsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CrewPattugliaReportsRef = AutoDisposeProviderRef<List<RadarEvent>>;
String _$homeMapMarkersHash() => r'9120bbc254169d316e499d21f1b9f815d6131abb';

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
/// segnalazioni di crew e avviso di prossimità durante DRIVE dipendono
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
String _$crewReportsControllerHash() =>
    r'76d8a3f9a238bfc3fb345ef1953069847a0cff8f';

/// Segnalazioni Velox+Pattuglia della crew dell'utente, aggiornate in
/// realtime via Supabase e già private delle voci scadute (90 minuti,
/// vedi [RadarEvent.isExpired]) — sia ad ogni nuovo evento dal DB, sia
/// periodicamente per chi scade "a riposo" senza che nel frattempo
/// arrivi un nuovo insert altrui (stesso principio dello staleness timer
/// di CrewLiveMapController).
///
/// Copied from [CrewReportsController].
@ProviderFor(CrewReportsController)
final crewReportsControllerProvider = AutoDisposeNotifierProvider<
    CrewReportsController, List<RadarEvent>>.internal(
  CrewReportsController.new,
  name: r'crewReportsControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$crewReportsControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CrewReportsController = AutoDisposeNotifier<List<RadarEvent>>;
String _$radarActionsControllerHash() =>
    r'a1d63b5f6e1f123e4a97f3a986d59dbb3b8608c8';

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
