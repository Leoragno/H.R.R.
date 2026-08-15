// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mission_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$missionRemoteDatasourceHash() =>
    r'9e1f913e434f20e9829f94d21285241710e0a467';

/// See also [missionRemoteDatasource].
@ProviderFor(missionRemoteDatasource)
final missionRemoteDatasourceProvider =
    AutoDisposeProvider<MissionRemoteDatasource>.internal(
  missionRemoteDatasource,
  name: r'missionRemoteDatasourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$missionRemoteDatasourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MissionRemoteDatasourceRef
    = AutoDisposeProviderRef<MissionRemoteDatasource>;
String _$missionRepositoryHash() => r'9704b31a479d52a9904530052f85bad5a8fe38bb';

/// See also [missionRepository].
@ProviderFor(missionRepository)
final missionRepositoryProvider =
    AutoDisposeProvider<MissionRepository>.internal(
  missionRepository,
  name: r'missionRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$missionRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MissionRepositoryRef = AutoDisposeProviderRef<MissionRepository>;
String _$activeMissionsHash() => r'c80533866cb35599f4c57b299ff5c109c6758787';

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

/// Missioni attive visibili al chiamante (le secret non completate sono
/// già escluse lato RLS). `type` filtra il tab Daily/Weekly/Season/Secret.
///
/// Copied from [activeMissions].
@ProviderFor(activeMissions)
const activeMissionsProvider = ActiveMissionsFamily();

/// Missioni attive visibili al chiamante (le secret non completate sono
/// già escluse lato RLS). `type` filtra il tab Daily/Weekly/Season/Secret.
///
/// Copied from [activeMissions].
class ActiveMissionsFamily extends Family<AsyncValue<List<Mission>>> {
  /// Missioni attive visibili al chiamante (le secret non completate sono
  /// già escluse lato RLS). `type` filtra il tab Daily/Weekly/Season/Secret.
  ///
  /// Copied from [activeMissions].
  const ActiveMissionsFamily();

  /// Missioni attive visibili al chiamante (le secret non completate sono
  /// già escluse lato RLS). `type` filtra il tab Daily/Weekly/Season/Secret.
  ///
  /// Copied from [activeMissions].
  ActiveMissionsProvider call({
    MissionType? type,
  }) {
    return ActiveMissionsProvider(
      type: type,
    );
  }

  @override
  ActiveMissionsProvider getProviderOverride(
    covariant ActiveMissionsProvider provider,
  ) {
    return call(
      type: provider.type,
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
  String? get name => r'activeMissionsProvider';
}

/// Missioni attive visibili al chiamante (le secret non completate sono
/// già escluse lato RLS). `type` filtra il tab Daily/Weekly/Season/Secret.
///
/// Copied from [activeMissions].
class ActiveMissionsProvider extends AutoDisposeFutureProvider<List<Mission>> {
  /// Missioni attive visibili al chiamante (le secret non completate sono
  /// già escluse lato RLS). `type` filtra il tab Daily/Weekly/Season/Secret.
  ///
  /// Copied from [activeMissions].
  ActiveMissionsProvider({
    MissionType? type,
  }) : this._internal(
          (ref) => activeMissions(
            ref as ActiveMissionsRef,
            type: type,
          ),
          from: activeMissionsProvider,
          name: r'activeMissionsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$activeMissionsHash,
          dependencies: ActiveMissionsFamily._dependencies,
          allTransitiveDependencies:
              ActiveMissionsFamily._allTransitiveDependencies,
          type: type,
        );

  ActiveMissionsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.type,
  }) : super.internal();

  final MissionType? type;

  @override
  Override overrideWith(
    FutureOr<List<Mission>> Function(ActiveMissionsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ActiveMissionsProvider._internal(
        (ref) => create(ref as ActiveMissionsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        type: type,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Mission>> createElement() {
    return _ActiveMissionsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ActiveMissionsProvider && other.type == type;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, type.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ActiveMissionsRef on AutoDisposeFutureProviderRef<List<Mission>> {
  /// The parameter `type` of this provider.
  MissionType? get type;
}

class _ActiveMissionsProviderElement
    extends AutoDisposeFutureProviderElement<List<Mission>>
    with ActiveMissionsRef {
  _ActiveMissionsProviderElement(super.provider);

  @override
  MissionType? get type => (origin as ActiveMissionsProvider).type;
}

String _$myMissionProgressHash() => r'4ac74decaadaa4846b958ec94a31d3a1d185fe1f';

/// Progresso live dell'utente corrente — realtime via Supabase (richiede
/// `mission_progress` nella pubblicazione, aggiunta in 0003_mission_engine.sql).
///
/// Copied from [myMissionProgress].
@ProviderFor(myMissionProgress)
final myMissionProgressProvider =
    AutoDisposeStreamProvider<List<MissionProgress>>.internal(
  myMissionProgress,
  name: r'myMissionProgressProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$myMissionProgressHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyMissionProgressRef
    = AutoDisposeStreamProviderRef<List<MissionProgress>>;
String _$myClaimedMissionIdsHash() =>
    r'59673cb6b6d5aac6dae9aa117b9619eda2f06fa9';

/// Id delle missioni già riscattate dal chiamante (distingue "pronta" da
/// "già riscattata" nella UI — mission_progress non lo sa da sola).
///
/// Copied from [myClaimedMissionIds].
@ProviderFor(myClaimedMissionIds)
final myClaimedMissionIdsProvider =
    AutoDisposeFutureProvider<List<String>>.internal(
  myClaimedMissionIds,
  name: r'myClaimedMissionIdsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$myClaimedMissionIdsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyClaimedMissionIdsRef = AutoDisposeFutureProviderRef<List<String>>;
String _$secretMissionSlotCountHash() =>
    r'71a77022b7e0ea7e27cb5fafa6e0735a49b82920';

/// Numero di slot missione segreta nel pool, per i placeholder "???" del
/// tab Secret — mai il contenuto delle missioni stesse.
///
/// Copied from [secretMissionSlotCount].
@ProviderFor(secretMissionSlotCount)
final secretMissionSlotCountProvider = AutoDisposeFutureProvider<int>.internal(
  secretMissionSlotCount,
  name: r'secretMissionSlotCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$secretMissionSlotCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SecretMissionSlotCountRef = AutoDisposeFutureProviderRef<int>;
String _$activeSeasonHash() => r'98596aeec37a6bd165837ab95f87e146c37a7fbc';

/// See also [activeSeason].
@ProviderFor(activeSeason)
final activeSeasonProvider = AutoDisposeFutureProvider<Season?>.internal(
  activeSeason,
  name: r'activeSeasonProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$activeSeasonHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ActiveSeasonRef = AutoDisposeFutureProviderRef<Season?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
