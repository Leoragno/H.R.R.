// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_map_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$liveMapControllerHash() => r'b24fc731fb4f27ad4c68e9916bdb3161b5bdfc59';

/// Espone tutti gli utenti che stanno guidando ora, con posizione e
/// percorso live, per il layer "altri driver" sulla mappa della sezione
/// guida — l'app è privata e chiusa, tutti gli utenti sono già
/// "connessi" tra loro, quindi un solo canale condiviso invece di uno per
/// crew o uno per amico. Si iscrive in sola lettura allo stesso canale su
/// cui [TripLiveController] pubblica quando l'utente stesso guida.
///
/// Copied from [LiveMapController].
@ProviderFor(LiveMapController)
final liveMapControllerProvider = AutoDisposeNotifierProvider<LiveMapController,
    Map<String, LiveDriver>>.internal(
  LiveMapController.new,
  name: r'liveMapControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$liveMapControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$LiveMapController = AutoDisposeNotifier<Map<String, LiveDriver>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
