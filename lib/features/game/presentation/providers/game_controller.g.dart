// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$gameControllerHash() => r'3e6c53437cd187eed362e1d34a1040940980021d';

/// Stato di sola lettura della mappa territorio: mostra le celle
/// possedute e la propria posizione, ma non rivendica più nulla in
/// autonomia. L'acquisizione delle celle avviene esclusivamente durante
/// una guida registrata (vedi TripLiveController.finishTrip, che chiama
/// claimCells col punteggio di guida finale — 0026_territory_decay_
/// counterattack.sql) — nessun tracking GPS ambientale/di fondo qui, solo
/// un fix quando la schermata Gioca è aperta (niente più foreground
/// service "sta tracciando la tua conquista territorio": non c'è più
/// nulla da tracciare in background).
///
/// Copied from [GameController].
@ProviderFor(GameController)
final gameControllerProvider =
    AutoDisposeNotifierProvider<GameController, GameState>.internal(
  GameController.new,
  name: r'gameControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$gameControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GameController = AutoDisposeNotifier<GameState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
