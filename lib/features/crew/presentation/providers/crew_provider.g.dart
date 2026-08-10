// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'crew_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$crewRemoteDatasourceHash() =>
    r'2b03ea368e10a3d3cd52592841ac5a2ee8ba7d4f';

/// See also [crewRemoteDatasource].
@ProviderFor(crewRemoteDatasource)
final crewRemoteDatasourceProvider =
    AutoDisposeProvider<CrewRemoteDatasource>.internal(
  crewRemoteDatasource,
  name: r'crewRemoteDatasourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$crewRemoteDatasourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CrewRemoteDatasourceRef = AutoDisposeProviderRef<CrewRemoteDatasource>;
String _$crewRepositoryHash() => r'0abc6e7db72f12e4ae8f84e986accf39fe543d3b';

/// See also [crewRepository].
@ProviderFor(crewRepository)
final crewRepositoryProvider = AutoDisposeProvider<CrewRepository>.internal(
  crewRepository,
  name: r'crewRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$crewRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CrewRepositoryRef = AutoDisposeProviderRef<CrewRepository>;
String _$myCrewHash() => r'24bf3a405cf1e6ef06e17ea06f84861ee13c9b12';

/// Crew dell'utente corrente, derivata da `profiles.crew_id` (già
/// realtime via [myProfileProvider]): null se non fa parte di nessuna
/// crew. Non serve invalidarla manualmente dopo join/leave/create — lo
/// stream del profilo emette da solo il nuovo `crew_id`.
///
/// Copied from [myCrew].
@ProviderFor(myCrew)
final myCrewProvider = AutoDisposeFutureProvider<Crew?>.internal(
  myCrew,
  name: r'myCrewProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$myCrewHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyCrewRef = AutoDisposeFutureProviderRef<Crew?>;
String _$crewMembersHash() => r'7eec8b418d4e77090c661fb95f377314d2a1208f';

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

/// See also [crewMembers].
@ProviderFor(crewMembers)
const crewMembersProvider = CrewMembersFamily();

/// See also [crewMembers].
class CrewMembersFamily extends Family<AsyncValue<List<CrewMember>>> {
  /// See also [crewMembers].
  const CrewMembersFamily();

  /// See also [crewMembers].
  CrewMembersProvider call(
    String crewId,
  ) {
    return CrewMembersProvider(
      crewId,
    );
  }

  @override
  CrewMembersProvider getProviderOverride(
    covariant CrewMembersProvider provider,
  ) {
    return call(
      provider.crewId,
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
  String? get name => r'crewMembersProvider';
}

/// See also [crewMembers].
class CrewMembersProvider extends AutoDisposeFutureProvider<List<CrewMember>> {
  /// See also [crewMembers].
  CrewMembersProvider(
    String crewId,
  ) : this._internal(
          (ref) => crewMembers(
            ref as CrewMembersRef,
            crewId,
          ),
          from: crewMembersProvider,
          name: r'crewMembersProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$crewMembersHash,
          dependencies: CrewMembersFamily._dependencies,
          allTransitiveDependencies:
              CrewMembersFamily._allTransitiveDependencies,
          crewId: crewId,
        );

  CrewMembersProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.crewId,
  }) : super.internal();

  final String crewId;

  @override
  Override overrideWith(
    FutureOr<List<CrewMember>> Function(CrewMembersRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CrewMembersProvider._internal(
        (ref) => create(ref as CrewMembersRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        crewId: crewId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<CrewMember>> createElement() {
    return _CrewMembersProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CrewMembersProvider && other.crewId == crewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, crewId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CrewMembersRef on AutoDisposeFutureProviderRef<List<CrewMember>> {
  /// The parameter `crewId` of this provider.
  String get crewId;
}

class _CrewMembersProviderElement
    extends AutoDisposeFutureProviderElement<List<CrewMember>>
    with CrewMembersRef {
  _CrewMembersProviderElement(super.provider);

  @override
  String get crewId => (origin as CrewMembersProvider).crewId;
}

String _$crewMemberCountHash() => r'43e8f5af3b98ef6907f9910b129efdda36a07c55';

/// See also [crewMemberCount].
@ProviderFor(crewMemberCount)
const crewMemberCountProvider = CrewMemberCountFamily();

/// See also [crewMemberCount].
class CrewMemberCountFamily extends Family<AsyncValue<int>> {
  /// See also [crewMemberCount].
  const CrewMemberCountFamily();

  /// See also [crewMemberCount].
  CrewMemberCountProvider call(
    String crewId,
  ) {
    return CrewMemberCountProvider(
      crewId,
    );
  }

  @override
  CrewMemberCountProvider getProviderOverride(
    covariant CrewMemberCountProvider provider,
  ) {
    return call(
      provider.crewId,
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
  String? get name => r'crewMemberCountProvider';
}

/// See also [crewMemberCount].
class CrewMemberCountProvider extends AutoDisposeFutureProvider<int> {
  /// See also [crewMemberCount].
  CrewMemberCountProvider(
    String crewId,
  ) : this._internal(
          (ref) => crewMemberCount(
            ref as CrewMemberCountRef,
            crewId,
          ),
          from: crewMemberCountProvider,
          name: r'crewMemberCountProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$crewMemberCountHash,
          dependencies: CrewMemberCountFamily._dependencies,
          allTransitiveDependencies:
              CrewMemberCountFamily._allTransitiveDependencies,
          crewId: crewId,
        );

  CrewMemberCountProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.crewId,
  }) : super.internal();

  final String crewId;

  @override
  Override overrideWith(
    FutureOr<int> Function(CrewMemberCountRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CrewMemberCountProvider._internal(
        (ref) => create(ref as CrewMemberCountRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        crewId: crewId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<int> createElement() {
    return _CrewMemberCountProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CrewMemberCountProvider && other.crewId == crewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, crewId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CrewMemberCountRef on AutoDisposeFutureProviderRef<int> {
  /// The parameter `crewId` of this provider.
  String get crewId;
}

class _CrewMemberCountProviderElement
    extends AutoDisposeFutureProviderElement<int> with CrewMemberCountRef {
  _CrewMemberCountProviderElement(super.provider);

  @override
  String get crewId => (origin as CrewMemberCountProvider).crewId;
}

String _$browseCrewsHash() => r'b88f0dfffacc5648880af41ec793356aada8b9ff';

/// See also [browseCrews].
@ProviderFor(browseCrews)
final browseCrewsProvider = AutoDisposeFutureProvider<List<Crew>>.internal(
  browseCrews,
  name: r'browseCrewsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$browseCrewsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BrowseCrewsRef = AutoDisposeFutureProviderRef<List<Crew>>;
String _$crewDisbandVotersHash() => r'9ebbd535789e13be1d062f6e28d05e872562311d';

/// Profili che hanno votato per sciogliere [crewId] — lista vuota =
/// nessuna votazione attiva.
///
/// Copied from [crewDisbandVoters].
@ProviderFor(crewDisbandVoters)
const crewDisbandVotersProvider = CrewDisbandVotersFamily();

/// Profili che hanno votato per sciogliere [crewId] — lista vuota =
/// nessuna votazione attiva.
///
/// Copied from [crewDisbandVoters].
class CrewDisbandVotersFamily extends Family<AsyncValue<List<String>>> {
  /// Profili che hanno votato per sciogliere [crewId] — lista vuota =
  /// nessuna votazione attiva.
  ///
  /// Copied from [crewDisbandVoters].
  const CrewDisbandVotersFamily();

  /// Profili che hanno votato per sciogliere [crewId] — lista vuota =
  /// nessuna votazione attiva.
  ///
  /// Copied from [crewDisbandVoters].
  CrewDisbandVotersProvider call(
    String crewId,
  ) {
    return CrewDisbandVotersProvider(
      crewId,
    );
  }

  @override
  CrewDisbandVotersProvider getProviderOverride(
    covariant CrewDisbandVotersProvider provider,
  ) {
    return call(
      provider.crewId,
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
  String? get name => r'crewDisbandVotersProvider';
}

/// Profili che hanno votato per sciogliere [crewId] — lista vuota =
/// nessuna votazione attiva.
///
/// Copied from [crewDisbandVoters].
class CrewDisbandVotersProvider
    extends AutoDisposeFutureProvider<List<String>> {
  /// Profili che hanno votato per sciogliere [crewId] — lista vuota =
  /// nessuna votazione attiva.
  ///
  /// Copied from [crewDisbandVoters].
  CrewDisbandVotersProvider(
    String crewId,
  ) : this._internal(
          (ref) => crewDisbandVoters(
            ref as CrewDisbandVotersRef,
            crewId,
          ),
          from: crewDisbandVotersProvider,
          name: r'crewDisbandVotersProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$crewDisbandVotersHash,
          dependencies: CrewDisbandVotersFamily._dependencies,
          allTransitiveDependencies:
              CrewDisbandVotersFamily._allTransitiveDependencies,
          crewId: crewId,
        );

  CrewDisbandVotersProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.crewId,
  }) : super.internal();

  final String crewId;

  @override
  Override overrideWith(
    FutureOr<List<String>> Function(CrewDisbandVotersRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CrewDisbandVotersProvider._internal(
        (ref) => create(ref as CrewDisbandVotersRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        crewId: crewId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<String>> createElement() {
    return _CrewDisbandVotersProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CrewDisbandVotersProvider && other.crewId == crewId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, crewId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CrewDisbandVotersRef on AutoDisposeFutureProviderRef<List<String>> {
  /// The parameter `crewId` of this provider.
  String get crewId;
}

class _CrewDisbandVotersProviderElement
    extends AutoDisposeFutureProviderElement<List<String>>
    with CrewDisbandVotersRef {
  _CrewDisbandVotersProviderElement(super.provider);

  @override
  String get crewId => (origin as CrewDisbandVotersProvider).crewId;
}

String _$crewActionsControllerHash() =>
    r'83dea35c9fd667fb0554f2496a6cc3ba336fd113';

/// Stato di loading/errore delle azioni (crea/entra/lascia/gestisci
/// membri) indipendente dai provider di lettura sopra — la UI lo usa
/// solo per disabilitare i pulsanti durante una richiesta in corso.
///
/// Copied from [CrewActionsController].
@ProviderFor(CrewActionsController)
final crewActionsControllerProvider =
    AutoDisposeAsyncNotifierProvider<CrewActionsController, void>.internal(
  CrewActionsController.new,
  name: r'crewActionsControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$crewActionsControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CrewActionsController = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
