// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'radar_proximity_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$radarProximityControllerHash() =>
    r'0da8a7911237e7f8dc80f5ff5b00de379f9567ee';

/// Durante DRIVE, riusa il GPS già live in [tripLiveControllerProvider]
/// (nessun nuovo stream di posizione) per capire se l'utente si sta
/// avvicinando a un Velox/Pattuglia (API o community) e restituisce
/// l'evento da segnalare — un impulso, non uno stato persistente: [Timer]/durata
/// di visualizzazione dell'avviso restano a carico della UI (vedi
/// RadarAlertBanner), qui c'è solo "quale evento, se c'è, va segnalato ora".
///
/// Copied from [RadarProximityController].
@ProviderFor(RadarProximityController)
final radarProximityControllerProvider = AutoDisposeAsyncNotifierProvider<
    RadarProximityController, RadarEvent?>.internal(
  RadarProximityController.new,
  name: r'radarProximityControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$radarProximityControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$RadarProximityController = AutoDisposeAsyncNotifier<RadarEvent?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
