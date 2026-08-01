// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mission_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$missionControllerHash() => r'2eeee0aa7bb6ac32229e774e41fbed2ccab379de';

/// Riscatto missione. Orchestrazione: chiama la RPC via [ClaimMissionUseCase],
/// poi invalida progresso/lista missioni cosi la UI riflette subito
/// l'esito (claim consumato, reward assegnati) senza aspettare il giro
/// realtime.
///
/// Copied from [MissionController].
@ProviderFor(MissionController)
final missionControllerProvider =
    AutoDisposeAsyncNotifierProvider<MissionController, void>.internal(
  MissionController.new,
  name: r'missionControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$missionControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MissionController = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
