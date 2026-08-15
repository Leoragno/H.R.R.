// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'statistics_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$statisticsRemoteDatasourceHash() =>
    r'74916af213137bca18c6566dd8833201044fc1e6';

/// See also [statisticsRemoteDatasource].
@ProviderFor(statisticsRemoteDatasource)
final statisticsRemoteDatasourceProvider =
    AutoDisposeProvider<StatisticsRemoteDatasource>.internal(
  statisticsRemoteDatasource,
  name: r'statisticsRemoteDatasourceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$statisticsRemoteDatasourceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StatisticsRemoteDatasourceRef
    = AutoDisposeProviderRef<StatisticsRemoteDatasource>;
String _$myStatisticsHash() => r'5ed06471e0c9a3a3806375c1e11746bd8c63c72b';

/// Combina dati già presenti in altre feature — nessuna nuova tabella/RPC
/// (a parte il conteggio spot, vedi [StatisticsRemoteDatasource]). La
/// velocità massima non è ovunque esposta: si prende dalla classifica
/// "velocità" (limite alto per non perdere la propria riga se non si è
/// nei primi 50) filtrata sulla propria; se non compare (mai guidato, o
/// oltre il limite) resta 0 — stesso comportamento già accettato altrove
/// in app (leaderboard_screen.dart "fuori classifica").
///
/// Copied from [myStatistics].
@ProviderFor(myStatistics)
final myStatisticsProvider = AutoDisposeFutureProvider<UserStatistics>.internal(
  myStatistics,
  name: r'myStatisticsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$myStatisticsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyStatisticsRef = AutoDisposeFutureProviderRef<UserStatistics>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
