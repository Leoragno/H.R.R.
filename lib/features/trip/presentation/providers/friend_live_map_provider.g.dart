// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend_live_map_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$friendLiveMapControllerHash() =>
    r'484eae391d1f1420ae8bfb2a30a80820a16dcc7d';

/// Espone gli amici accettati dell'utente che stanno guidando ora, con
/// posizione live, per il layer "amici" sulla mappa della sezione guida —
/// stesso dato/scopo di [CrewLiveMapController] ma un canale Realtime PER
/// AMICO ("friend-live-<profileId>", vedi 0023_friends.sql) invece di un
/// canale unico condiviso da crew: ogni amico pubblica solo sul proprio
/// canale (vedi TripLiveController._joinFriendLiveChannel), qui ci si
/// iscrive in sola lettura a quello di ciascun amico accettato — la RLS
/// del canale (0023) è quella che impedisce a chiunque non sia amico
/// accettato di leggerlo, non un filtro qui lato client.
///
/// Copied from [FriendLiveMapController].
@ProviderFor(FriendLiveMapController)
final friendLiveMapControllerProvider = AutoDisposeNotifierProvider<
    FriendLiveMapController, Map<String, CrewLiveDriver>>.internal(
  FriendLiveMapController.new,
  name: r'friendLiveMapControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$friendLiveMapControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$FriendLiveMapController
    = AutoDisposeNotifier<Map<String, CrewLiveDriver>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
