// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'territory_location_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$territoryCellLocationsHash() =>
    r'f69bbcb6108d7af66708f595764298648a3182e7';

/// Paese/regione/stato per ogni cella posseduta, chiave `HexCoord.key`.
/// Il reverse geocoding è per-coordinata (nessuna API batch nel plugin
/// `geocoding`), quindi le celle vengono raggruppate per bucket di ~110m
/// (3 decimali) prima di interrogare il geocoder: celle adiacenti (46m di
/// lato) ricadono quasi sempre nella stessa località, una sola chiamata di
/// rete per bucket invece che una per cella. Un bucket il cui lookup fallisce
/// (rete assente, geocoder di piattaforma non disponibile — vedi
/// game_map_background.dart per lo stesso genere di gap fra piattaforme)
/// finisce in [TerritoryLocation.unknown], mai un'eccezione che vuota la
/// schermata.
///
/// Copied from [territoryCellLocations].
@ProviderFor(territoryCellLocations)
final territoryCellLocationsProvider =
    AutoDisposeFutureProvider<Map<String, TerritoryLocation>>.internal(
  territoryCellLocations,
  name: r'territoryCellLocationsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$territoryCellLocationsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TerritoryCellLocationsRef
    = AutoDisposeFutureProviderRef<Map<String, TerritoryLocation>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
