// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rival_controller_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$rivalControllerHash() => r'bcb0bf7983e70d58dc2606e83f81271ef1963a38';

/// Decide quando e cosa dice il Rival, ascoltando due fonti già esistenti
/// invece di reinventarle:
/// - `notificationToastControllerProvider` per missione completata/record
///   personale (la logica di confronto vive già lato server, vedi
///   0018_progress_record_notifications.sql — qui si reagisce e basta);
/// - il bus `MissionEvent` (core/events) solo per `TripCompleted`, usato
///   come timestamp di "ultima attività" per il check di inattività.
/// Streak e "nuovo giorno" sono invece calcolati qui, non esistono altrove
/// (vedi RivalLocalStore).
///
/// Va tenuto vivo per tutta la sessione — instanziato da [HrrApp] con
/// `ref.watch`, stesso pattern di MissionEventBridge.
///
/// Copied from [RivalController].
@ProviderFor(RivalController)
final rivalControllerProvider =
    NotifierProvider<RivalController, RivalPopup?>.internal(
  RivalController.new,
  name: r'rivalControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$rivalControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$RivalController = Notifier<RivalPopup?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
