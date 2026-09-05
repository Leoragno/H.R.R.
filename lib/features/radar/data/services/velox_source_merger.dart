import 'dart:math' as math;

import '../../domain/entities/radar_event.dart';

/// Combina i velox di più fonti API indipendenti in un'unica lista senza
/// trattarne nessuna come verità assoluta: un punto presente in più fonti
/// (entro [_matchThresholdMeters]) diventa `verified: true`, uno visto da
/// una sola fonte resta `verified: false` — mostrato comunque (non
/// scartato), solo con opacità diversa in mappa (vedi
/// HomeMapBackground._syncSymbols e RadarEvent.verified).
class VeloxSourceMerger {
  VeloxSourceMerger._();

  // ~120m: assorbe la differenza di posizionamento tipica tra fonti (nodo
  // OSM sul palo vs punto di rilevamento Open-GATSO-POI), restando
  // abbastanza stretto da non confondere due velox distinti ravvicinati
  // (es. i due sensi di marcia di una stessa strada).
  static const _matchThresholdMeters = 120.0;

  static List<RadarEvent> merge(
    List<RadarEvent> primary,
    List<RadarEvent> secondary,
  ) {
    if (secondary.isEmpty) {
      return [for (final e in primary) _withVerified(e, false)];
    }

    final matched = List<bool>.filled(secondary.length, false);
    final merged = <RadarEvent>[];

    for (final p in primary) {
      var isVerified = false;
      for (var i = 0; i < secondary.length; i++) {
        if (matched[i]) continue;
        if (_distanceMeters(p.lat, p.lon, secondary[i].lat, secondary[i].lon) <=
            _matchThresholdMeters) {
          matched[i] = true;
          isVerified = true;
          break;
        }
      }
      merged.add(_withVerified(p, isVerified));
    }

    for (var i = 0; i < secondary.length; i++) {
      if (matched[i]) continue;
      merged.add(_withVerified(secondary[i], false));
    }

    return merged;
  }

  static RadarEvent _withVerified(RadarEvent e, bool verified) => RadarEvent(
        id: e.id,
        category: e.category,
        source: e.source,
        lat: e.lat,
        lon: e.lon,
        reportedAt: e.reportedAt,
        verified: verified,
      );

  static double _distanceMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _degToRad(double deg) => deg * math.pi / 180;
}
