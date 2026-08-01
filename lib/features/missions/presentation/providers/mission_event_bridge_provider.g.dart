// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mission_event_bridge_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$missionEventBridgeHash() =>
    r'4c28a8882c7c7e2163833212e68b5f27ee76f1ae';

/// Ascolta il bus condiviso (core/events) e lo collega al Mission Engine:
/// ogni evento viene prima accodato localmente, poi si tenta subito
/// l'invio — un solo percorso sia online che offline, la coda garantisce
/// che un fallimento di rete non perda l'evento (viene ritentato alla
/// riconnessione). Nessuna feature deve mai chiamare
/// record_mission_event/il repository direttamente: pubblica sul bus,
/// questo provider è l'unico consumatore.
///
/// Va tenuto vivo per tutta la sessione app — instanziato una volta da
/// [HrrApp] (vedi main.dart) leggendolo con `ref.watch` cosi Riverpod non
/// lo scarta per mancanza di ascoltatori.
///
/// Copied from [MissionEventBridge].
@ProviderFor(MissionEventBridge)
final missionEventBridgeProvider =
    NotifierProvider<MissionEventBridge, void>.internal(
  MissionEventBridge.new,
  name: r'missionEventBridgeProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$missionEventBridgeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MissionEventBridge = Notifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
