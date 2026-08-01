// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'achievement_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$achievementRemoteDatasourceHash() =>
    r'd78a7deb0a223bad1349f3fda69fa87b1362a812';

/// See also [achievementRemoteDatasource].
@ProviderFor(achievementRemoteDatasource)
final achievementRemoteDatasourceProvider =
    AutoDisposeProvider<AchievementRemoteDatasource>.internal(
  achievementRemoteDatasource,
  name: r'achievementRemoteDatasourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$achievementRemoteDatasourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AchievementRemoteDatasourceRef
    = AutoDisposeProviderRef<AchievementRemoteDatasource>;
String _$achievementRepositoryHash() =>
    r'851b877b895592fc320070cf3b885f5f6d572b23';

/// See also [achievementRepository].
@ProviderFor(achievementRepository)
final achievementRepositoryProvider =
    AutoDisposeProvider<AchievementRepository>.internal(
  achievementRepository,
  name: r'achievementRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$achievementRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AchievementRepositoryRef
    = AutoDisposeProviderRef<AchievementRepository>;
String _$myAchievementsHash() => r'b47a44ad2657c6af05a46fdc8a5563abbb0fb61c';

/// Achievement del profilo corrente — ottenuti e non, unificati (vedi
/// AchievementRemoteDatasource.myAchievements). Nessun claim manuale: gli
/// achievement ottenuti sono già assegnati lato server.
///
/// Copied from [myAchievements].
@ProviderFor(myAchievements)
final myAchievementsProvider =
    AutoDisposeFutureProvider<List<Achievement>>.internal(
  myAchievements,
  name: r'myAchievementsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$myAchievementsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyAchievementsRef = AutoDisposeFutureProviderRef<List<Achievement>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
