// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_notification_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$pushNotificationServiceHash() =>
    r'2cea41cc266c9da8d9a0283501e15ddc42e9ed6c';

/// Notifiche push (FCM), fuori dall'app — completano le notifiche in-app
/// (Supabase Realtime, sempre attive a prescindere da questo servizio e
/// dallo stato di Firebase). Su piattaforme/config senza Messaging
/// funzionante (web senza VAPID key, desktop, o un progetto Firebase non
/// ancora impostato) ogni chiamata sotto fallisce silenziosamente — l'app
/// resta comunque completamente utilizzabile.
///
/// Va tenuto vivo per tutta la sessione: instanziato una volta da
/// [HrrApp] (vedi main.dart) leggendolo con `ref.watch`, stesso principio
/// di MissionEventBridge. Il logout libera il token lato server — vedi
/// `AuthController.signOut` in auth_provider.dart — non qui, perché a
/// quel punto la sessione Supabase è già chiusa e la RPC non avrebbe più
/// un `auth.uid()` valido per farlo.
///
/// Copied from [PushNotificationService].
@ProviderFor(PushNotificationService)
final pushNotificationServiceProvider =
    NotifierProvider<PushNotificationService, void>.internal(
  PushNotificationService.new,
  name: r'pushNotificationServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pushNotificationServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$PushNotificationService = Notifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
