import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../domain/entities/radar_bounds.dart';
import '../../domain/entities/radar_event.dart';

class _CacheEntry {
  final List<RadarEvent> events;
  final DateTime at;
  const _CacheEntry(this.events, this.at);
}

/// Pattuglie da segnalazioni pubbliche Waze (endpoint "live-map georss",
/// lo stesso usato dai wrapper open source tipo waze-traffic-api), filtrate
/// alla sola categoria `POLICE` — mai auto/incidenti/altro.
///
/// Endpoint non ufficiale e non documentato da Waze: può cambiare forma o
/// smettere di rispondere senza preavviso. Ogni errore/risposta
/// inattesa risolve a lista vuota, mai un'eccezione visibile in UI.
class WazeRemoteDatasource {
  final Dio _dio;
  WazeRemoteDatasource(this._dio);

  final Map<RadarBounds, _CacheEntry> _cache = {};
  // Le pattuglie si spostano: cache più corta di quella (statica) dei
  // Velox Overpass, ma comunque sufficiente a coprire pan/zoom ravvicinati.
  static const _cacheTtl = Duration(minutes: 3);

  Future<List<RadarEvent>> policeAlerts(RadarBounds bounds) async {
    final baseUrl = dotenv.env['WAZE_GEORSS_URL'];
    if (baseUrl == null || baseUrl.isEmpty) return const [];

    final cached = _cache[bounds];
    if (cached != null && DateTime.now().difference(cached.at) < _cacheTtl) {
      return cached.events;
    }

    try {
      final response = await _dio.get<dynamic>(
        baseUrl,
        queryParameters: {
          'top': bounds.north,
          'bottom': bounds.south,
          'left': bounds.west,
          'right': bounds.east,
          'env': 'row',
          'types': 'alerts',
        },
        options: Options(headers: {
          // L'endpoint non ufficiale risponde in modo inconsistente senza
          // uno User-Agent "da browser".
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        }),
      );
      final events = _parse(response.data);
      _cache[bounds] = _CacheEntry(events, DateTime.now());
      return events;
    } catch (_) {
      return cached?.events ?? const [];
    }
  }

  List<RadarEvent> _parse(dynamic data) {
    if (data is! Map) return const [];
    final alerts = data['alerts'];
    if (alerts is! List) return const [];

    final events = <RadarEvent>[];
    for (final raw in alerts) {
      if (raw is! Map || raw['type'] != 'POLICE') continue;
      final location = raw['location'];
      if (location is! Map) continue;
      final lat = (location['y'] as num?)?.toDouble();
      final lon = (location['x'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;
      final id = (raw['uuid'] ?? raw['id'] ?? '$lat,$lon').toString();
      events.add(RadarEvent(
        id: 'waze-$id',
        category: RadarCategory.pattuglia,
        source: RadarSource.api,
        lat: lat,
        lon: lon,
      ));
    }
    return events;
  }
}
