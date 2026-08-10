// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_token_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$pushTokenRemoteDatasourceHash() =>
    r'de6609af170e3b38429624676215cf3caaaf5386';

/// DI di `push_tokens` isolata dal proprio file (invece di vivere dentro
/// push_notification_service.dart): serve anche ad [AuthController] per
/// liberare il token del device al logout, che altrimenti importerebbe
/// push_notification_service.dart — che a sua volta importa già
/// auth_provider.dart per [authStateProvider] — creando un ciclo.
///
/// Copied from [pushTokenRemoteDatasource].
@ProviderFor(pushTokenRemoteDatasource)
final pushTokenRemoteDatasourceProvider =
    AutoDisposeProvider<PushTokenRemoteDatasource>.internal(
  pushTokenRemoteDatasource,
  name: r'pushTokenRemoteDatasourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pushTokenRemoteDatasourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PushTokenRemoteDatasourceRef
    = AutoDisposeProviderRef<PushTokenRemoteDatasource>;
String _$pushTokenRepositoryHash() =>
    r'7e5a30e2f0e29feb5e5611ab71ab21cccc1f2425';

/// See also [pushTokenRepository].
@ProviderFor(pushTokenRepository)
final pushTokenRepositoryProvider =
    AutoDisposeProvider<PushTokenRepository>.internal(
  pushTokenRepository,
  name: r'pushTokenRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pushTokenRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PushTokenRepositoryRef = AutoDisposeProviderRef<PushTokenRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
