// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'crew_live_map_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$crewLiveMapControllerHash() =>
    r'2de23e53b21611bfb9ebd1cbb2cfd5afaef4cd5e';

/// Espone i membri della crew dell'utente che stanno guidando ora, con
/// posizione e percorso live, per il layer "altri driver" sulla mappa
/// della sezione guida. Si iscrive in sola lettura allo stesso canale su
/// cui [TripLiveController] pubblica quando l'utente stesso guida.
///
/// Copied from [CrewLiveMapController].
@ProviderFor(CrewLiveMapController)
final crewLiveMapControllerProvider = AutoDisposeNotifierProvider<
    CrewLiveMapController, Map<String, CrewLiveDriver>>.internal(
  CrewLiveMapController.new,
  name: r'crewLiveMapControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$crewLiveMapControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CrewLiveMapController
    = AutoDisposeNotifier<Map<String, CrewLiveDriver>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
