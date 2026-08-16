import 'package:equatable/equatable.dart';
import 'package:geocoding/geocoding.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/hex_grid.dart';
import 'territory_provider.dart';

part 'territory_location_provider.g.dart';

const _kUnknownLabel = 'Zona sconosciuta';

/// Paese/regione/stato del centro di una cella, per raggruppare "I miei
/// territori" (brief: dividerli anche per geografia, non solo elencarli
/// come coordinate esagonali). Un valore mancante dal geocoder (comune
/// per zone rurali o copertura scarsa del provider di piattaforma) resta
/// [_kUnknownLabel] invece di una stringa vuota, così la UI ha sempre
/// un'etichetta da raggruppare.
class TerritoryLocation extends Equatable {
  final String country;
  final String region;
  final String town;

  const TerritoryLocation({
    required this.country,
    required this.region,
    required this.town,
  });

  static const unknown = TerritoryLocation(
      country: _kUnknownLabel, region: _kUnknownLabel, town: _kUnknownLabel);

  @override
  List<Object?> get props => [country, region, town];
}

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
@riverpod
Future<Map<String, TerritoryLocation>> territoryCellLocations(
  TerritoryCellLocationsRef ref,
) async {
  final cells = await ref.watch(myTerritoriesProvider.future);
  if (cells.isEmpty) return const {};

  final bucketKeyByCellKey = <String, String>{};
  final coordByBucketKey = <String, (double, double)>{};
  for (final cell in cells) {
    final (lat, lon) = HexGrid.centerOf(cell.coord);
    final bucketLat = (lat * 1000).round() / 1000;
    final bucketLon = (lon * 1000).round() / 1000;
    final bucketKey = '$bucketLat,$bucketLon';
    bucketKeyByCellKey[cell.coord.key] = bucketKey;
    coordByBucketKey[bucketKey] = (bucketLat, bucketLon);
  }

  final locationByBucketKey = <String, TerritoryLocation>{};
  await Future.wait(coordByBucketKey.entries.map((entry) async {
    locationByBucketKey[entry.key] = await _resolve(entry.value.$1, entry.value.$2);
  }));

  return {
    for (final cell in cells)
      cell.coord.key: locationByBucketKey[bucketKeyByCellKey[cell.coord.key]]!,
  };
}

Future<TerritoryLocation> _resolve(double lat, double lon) async {
  try {
    final placemarks = await placemarkFromCoordinates(lat, lon);
    if (placemarks.isEmpty) return TerritoryLocation.unknown;
    final p = placemarks.first;
    final town = _nonEmpty(p.locality) ?? _nonEmpty(p.subAdministrativeArea);
    return TerritoryLocation(
      country: _nonEmpty(p.country) ?? _kUnknownLabel,
      region: _nonEmpty(p.administrativeArea) ?? _kUnknownLabel,
      town: town ?? _kUnknownLabel,
    );
  } catch (_) {
    return TerritoryLocation.unknown;
  }
}

String? _nonEmpty(String? s) => (s == null || s.trim().isEmpty) ? null : s;
