import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../domain/entities/radar_bounds.dart';
import '../../domain/entities/radar_event.dart';

class _CacheEntry {
  final List<RadarEvent> events;
  final DateTime at;
  const _CacheEntry(this.events, this.at);
}

/// Velox fisici da OpenStreetMap via Overpass API — tag standard
/// `highway=speed_camera`, pubblico e documentato (a differenza di
/// un endpoint "Speed Cameras" TomTom, che non esiste nelle API
/// sviluppatore comuni). Nessuna API key richiesta.
///
/// `OVERPASS_API_URL` resta configurabile da `.env`: se vuoto il
/// provider è "non configurato" e ritorna sempre lista vuota, mai un
/// errore (stesso contratto già rispettato per Waze/Pattuglia).
class OverpassRemoteDatasource {
  final Dio _dio;
  OverpassRemoteDatasource(this._dio);

  final Map<RadarBounds, _CacheEntry> _cache = {};
  // I velox fissi cambiano di rado: cache più lunga di quella (mobile)
  // delle pattuglie, ed è anche buona educazione verso un'istanza
  // Overpass pubblica e condivisa (niente richieste ripetute inutili).
  static const _cacheTtl = Duration(minutes: 15);

  Future<List<RadarEvent>> veloxCameras(RadarBounds bounds) async {
    final url = dotenv.env['OVERPASS_API_URL'];
    if (url == null || url.isEmpty) return const [];

    final cached = _cache[bounds];
    if (cached != null && DateTime.now().difference(cached.at) < _cacheTtl) {
      return cached.events;
    }

    final query = '[out:json][timeout:25];'
        'node["highway"="speed_camera"]'
        '(${bounds.south},${bounds.west},${bounds.north},${bounds.east});'
        'out body;';

    try {
      final response = await _dio.post<dynamic>(
        url,
        data: {'data': query},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final events = _parse(response.data);
      _cache[bounds] = _CacheEntry(events, DateTime.now());
      return events;
    } catch (_) {
      // Istanza pubblica temporaneamente sovraccarica/irraggiungibile o
      // risposta inattesa: nessun dato piuttosto che un crash — l'ultimo
      // risultato buono in cache (se c'è) resta comunque valido.
      return cached?.events ?? const [];
    }
  }

  List<RadarEvent> _parse(dynamic data) {
    if (data is! Map) return const [];
    final elements = data['elements'];
    if (elements is! List) return const [];

    final events = <RadarEvent>[];
    for (final raw in elements) {
      if (raw is! Map) continue;
      final lat = (raw['lat'] as num?)?.toDouble();
      final lon = (raw['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;
      final id = (raw['id'] ?? '$lat,$lon').toString();
      events.add(RadarEvent(
        id: 'osm-$id',
        category: RadarCategory.velox,
        source: RadarSource.api,
        lat: lat,
        lon: lon,
      ));
    }
    return events;
  }
}
