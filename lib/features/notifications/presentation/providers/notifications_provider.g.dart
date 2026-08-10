// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifications_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$notificationsRemoteDatasourceHash() =>
    r'9af51c8a124bc7da3bb38823a9156fd91468c173';

/// See also [notificationsRemoteDatasource].
@ProviderFor(notificationsRemoteDatasource)
final notificationsRemoteDatasourceProvider =
    AutoDisposeProvider<NotificationsRemoteDatasource>.internal(
  notificationsRemoteDatasource,
  name: r'notificationsRemoteDatasourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$notificationsRemoteDatasourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NotificationsRemoteDatasourceRef
    = AutoDisposeProviderRef<NotificationsRemoteDatasource>;
String _$notificationRepositoryHash() =>
    r'a49bef4a50f6929737c9be9ab5cfda370127a642';

/// See also [notificationRepository].
@ProviderFor(notificationRepository)
final notificationRepositoryProvider =
    AutoDisposeProvider<NotificationRepository>.internal(
  notificationRepository,
  name: r'notificationRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$notificationRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NotificationRepositoryRef
    = AutoDisposeProviderRef<NotificationRepository>;
String _$unreadNotificationsCountHash() =>
    r'84aa8d721537aa61bf74bf9f5fe6e97fcfea5680';

/// See also [unreadNotificationsCount].
@ProviderFor(unreadNotificationsCount)
final unreadNotificationsCountProvider = AutoDisposeProvider<int>.internal(
  unreadNotificationsCount,
  name: r'unreadNotificationsCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$unreadNotificationsCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UnreadNotificationsCountRef = AutoDisposeProviderRef<int>;
String _$notificationToastControllerHash() =>
    r'bb5102329c1f7eeff737e756805b903876fb3301';

/// Pulsa con l'ultima notifica arrivata mentre l'app era già aperta (mai
/// per il backlog scaricato all'avvio) — ConsumerWidget in giro per l'app
/// (vedi MainShell) ci fa `ref.listen` per mostrare un toast un po'
/// simpatico. Stato semplice, lo aggiorna solo [NotificationsController].
///
/// Copied from [NotificationToastController].
@ProviderFor(NotificationToastController)
final notificationToastControllerProvider = AutoDisposeNotifierProvider<
    NotificationToastController, AppNotification?>.internal(
  NotificationToastController.new,
  name: r'notificationToastControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$notificationToastControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$NotificationToastController = AutoDisposeNotifier<AppNotification?>;
String _$notificationsControllerHash() =>
    r'3028c662a3ea74751673ec59fd86b5b04131fb65';

/// Tutte le notifiche dell'utente corrente, più recenti prima — lo stream
/// Supabase riconsegna l'intero snapshot ad ogni cambio (non un diff):
/// la prima consegna è il backlog (nessun toast), quelle successive sono
/// confrontate con lo stato precedente per capire quali righe sono
/// davvero nuove e meritano un toast.
///
/// Copied from [NotificationsController].
@ProviderFor(NotificationsController)
final notificationsControllerProvider = AutoDisposeNotifierProvider<
    NotificationsController, List<AppNotification>>.internal(
  NotificationsController.new,
  name: r'notificationsControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$notificationsControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$NotificationsController = AutoDisposeNotifier<List<AppNotification>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
