// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_notifications_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$localNotificationsServiceHash() =>
    r'9459ae8d0ad813fbefea1919cbeecece927850e8';

/// Notifiche locali Android: servono SOLO per il caso "app in foreground",
/// dove FCM (a differenza di background/terminata) non mostra da sé una
/// system notification — vedi il commento sul listener onMessage in
/// push_notification_service.dart. Nessun ruolo nel flusso
/// background/terminata (lì la mostra il sistema operativo da solo dal
/// payload `notification` + `android.notification.channel_id`) né nelle
/// notifiche in-app via Supabase Realtime (notification_toast_overlay.dart),
/// che restano un canale completamente separato e non tocco.
///
/// Copied from [LocalNotificationsService].
@ProviderFor(LocalNotificationsService)
final localNotificationsServiceProvider =
    NotifierProvider<LocalNotificationsService, void>.internal(
  LocalNotificationsService.new,
  name: r'localNotificationsServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$localNotificationsServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$LocalNotificationsService = Notifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
