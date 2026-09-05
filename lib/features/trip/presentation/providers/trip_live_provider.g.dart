// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip_live_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$pendingTripRecoveryHash() =>
    r'0c37ea42c587290b0776fe453bf0c28e382885af';

/// Letto una volta all'avvio (Home): se il processo è stato ucciso mentre
/// una guida era in corso, espone lo stato salvato così la UI può offrire
/// di riprenderla o chiuderla, invece di lasciarla bloccata per sempre.
/// Verifica anche lato server che il viaggio sia ancora 'active' — se nel
/// frattempo è stato chiuso da un altro device, non riproponiamo nulla.
///
/// Copied from [pendingTripRecovery].
@ProviderFor(pendingTripRecovery)
final pendingTripRecoveryProvider =
    AutoDisposeFutureProvider<PersistedTripState?>.internal(
  pendingTripRecovery,
  name: r'pendingTripRecoveryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pendingTripRecoveryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PendingTripRecoveryRef
    = AutoDisposeFutureProviderRef<PersistedTripState?>;
String _$lastTripSummaryControllerHash() =>
    r'74a38ace73d6fe931f1cd302416f650d5e0c79bc';

/// Tiene il TripSummary appena prodotto da finishTrip() finché
/// TripSummaryScreen non lo consuma. Prima veniva passato via `extra` di
/// GoRouter, ma `extra` non sopravvive a un refresh del router — e
/// completare un viaggio aggiorna `profiles` via realtime (XP/REP),
/// facendo scattare `refreshListenable` sul router, che ricostruisce la
/// route con `extra` nullo e mandava in crash TripSummaryScreen (o, prima
/// del fix del router, resettava la navigazione allo splash). Uno stato
/// Riverpod è immune a questo perché non passa per il router — ma deve
/// essere keepAlive: fra `set()` in finishTrip() e il primo `ref.watch`
/// di TripSummaryScreen non c'è nessun listener attivo, e un provider
/// autoDispose (default) viene smaltito in quella finestra, tornando a
/// null prima ancora che la schermata lo legga (l'utente vede la
/// schermata di riepilogo saltare dritta alla Home, come se il router
/// si fosse resettato di nuovo — stesso sintomo, causa diversa).
///
/// Copied from [LastTripSummaryController].
@ProviderFor(LastTripSummaryController)
final lastTripSummaryControllerProvider =
    NotifierProvider<LastTripSummaryController, TripSummary?>.internal(
  LastTripSummaryController.new,
  name: r'lastTripSummaryControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$lastTripSummaryControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$LastTripSummaryController = Notifier<TripSummary?>;
String _$tripLiveControllerHash() =>
    r'0d0eedf22b47eee719279054f4e27a2ce42cc01f';

/// See also [TripLiveController].
@ProviderFor(TripLiveController)
final tripLiveControllerProvider =
    AutoDisposeNotifierProvider<TripLiveController, TripLiveState>.internal(
  TripLiveController.new,
  name: r'tripLiveControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$tripLiveControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TripLiveController = AutoDisposeNotifier<TripLiveState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
