// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friends_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$friendsRemoteDatasourceHash() =>
    r'0bcf62aab92b3d05400aae6992b31cfdf3b826d4';

/// See also [friendsRemoteDatasource].
@ProviderFor(friendsRemoteDatasource)
final friendsRemoteDatasourceProvider =
    AutoDisposeProvider<FriendsRemoteDatasource>.internal(
  friendsRemoteDatasource,
  name: r'friendsRemoteDatasourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$friendsRemoteDatasourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FriendsRemoteDatasourceRef
    = AutoDisposeProviderRef<FriendsRemoteDatasource>;
String _$friendsRepositoryHash() => r'b38c93d9327bfb8f9066dafaa88109386b680b6c';

/// See also [friendsRepository].
@ProviderFor(friendsRepository)
final friendsRepositoryProvider =
    AutoDisposeProvider<FriendsRepository>.internal(
  friendsRepository,
  name: r'friendsRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$friendsRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FriendsRepositoryRef = AutoDisposeProviderRef<FriendsRepository>;
String _$myFriendsHash() => r'ea7bd287a98ce8007e26c951f146b24e840a3662';

/// See also [myFriends].
@ProviderFor(myFriends)
final myFriendsProvider =
    AutoDisposeFutureProvider<List<FriendProfile>>.internal(
  myFriends,
  name: r'myFriendsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$myFriendsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyFriendsRef = AutoDisposeFutureProviderRef<List<FriendProfile>>;
String _$pendingFriendRequestsHash() =>
    r'515301536d968c85b20f792bec828410056e3cb9';

/// See also [pendingFriendRequests].
@ProviderFor(pendingFriendRequests)
final pendingFriendRequestsProvider =
    AutoDisposeFutureProvider<List<FriendRequest>>.internal(
  pendingFriendRequests,
  name: r'pendingFriendRequestsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pendingFriendRequestsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PendingFriendRequestsRef
    = AutoDisposeFutureProviderRef<List<FriendRequest>>;
String _$friendsSearchControllerHash() =>
    r'7dc7eef67dacc011fc923c752f17a2b90cf984a1';

/// Ricerca profili (debounced) + azioni invio/risposta/rimozione amicizia.
/// Le liste "di lettura" (myFriendsProvider/pendingFriendRequestsProvider)
/// restano provider separati e vengono invalidate da qui dopo ogni
/// mutazione, invece di essere duplicate in questo stato.
///
/// Copied from [FriendsSearchController].
@ProviderFor(FriendsSearchController)
final friendsSearchControllerProvider = AutoDisposeNotifierProvider<
    FriendsSearchController, FriendsSearchState>.internal(
  FriendsSearchController.new,
  name: r'friendsSearchControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$friendsSearchControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$FriendsSearchController = AutoDisposeNotifier<FriendsSearchState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
