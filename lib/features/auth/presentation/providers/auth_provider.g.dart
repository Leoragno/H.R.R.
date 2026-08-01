// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$authRemoteDatasourceHash() =>
    r'058b3e3a293f9394b6116e52deda65a15926b17d';

/// See also [authRemoteDatasource].
@ProviderFor(authRemoteDatasource)
final authRemoteDatasourceProvider =
    AutoDisposeProvider<AuthRemoteDatasource>.internal(
  authRemoteDatasource,
  name: r'authRemoteDatasourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authRemoteDatasourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthRemoteDatasourceRef = AutoDisposeProviderRef<AuthRemoteDatasource>;
String _$authRepositoryHash() => r'b65d405a48830dc5d94464cadcfe5b3aeb6b9b4b';

/// See also [authRepository].
@ProviderFor(authRepository)
final authRepositoryProvider = AutoDisposeProvider<AuthRepository>.internal(
  authRepository,
  name: r'authRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthRepositoryRef = AutoDisposeProviderRef<AuthRepository>;
String _$authStateHash() => r'24440cba715f9677d48d7649af3ca4cdd1531476';

/// Stream of the current authenticated user (or null). The router watches
/// this to decide redirects between /login and the main app shell.
///
/// Copied from [authState].
@ProviderFor(authState)
final authStateProvider = AutoDisposeStreamProvider<AppUser?>.internal(
  authState,
  name: r'authStateProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthStateRef = AutoDisposeStreamProviderRef<AppUser?>;
String _$myProfileHash() => r'efdc67594b7d6d3fadea380e04c8ab58f2989440';

/// Profilo live dell'utente corrente: a differenza di [authStateProvider]
/// (che emette solo su login/logout), questo si aggiorna in tempo reale
/// quando xp/rep/level cambiano (es. subito dopo aver finito un viaggio),
/// quindi è la fonte giusta per qualsiasi HUD che mostri quei valori.
///
/// Copied from [myProfile].
@ProviderFor(myProfile)
final myProfileProvider = AutoDisposeStreamProvider<AppUser?>.internal(
  myProfile,
  name: r'myProfileProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$myProfileHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyProfileRef = AutoDisposeStreamProviderRef<AppUser?>;
String _$authControllerHash() => r'99471138acdbc30813d1e9f06c024edd1a498cfb';

/// Controller used by Login/Register screens to trigger actions and expose
/// a loading/error state independent from the auth stream itself.
///
/// Copied from [AuthController].
@ProviderFor(AuthController)
final authControllerProvider =
    AutoDisposeAsyncNotifierProvider<AuthController, void>.internal(
  AuthController.new,
  name: r'authControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AuthController = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
