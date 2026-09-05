import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/radar_bounds.dart';
import '../../domain/entities/radar_event.dart';

class _GatsoPoint {
  final double lat;
  final double lon;
  const _GatsoPoint(this.lat, this.lon);
}

/// Seconda fonte velox indipendente da Overpass/OSM, usata da
/// `VeloxSourceMerger` per marcare come "verificati" solo i punti
/// confermati da più fonti — vedi il commento su [RadarEvent.verified].
///
/// A differenza di Overpass qui non c'è un endpoint interrogabile per
/// bounding box: Open-GATSO-POI (github.com/1e1/Open-GATSO-POI, MIT)
/// pubblica un unico ZIP con l'intero set EU (aggiornato circa
/// giornalmente), `GATSO_ALL.csv` dentro. Lo scarichiamo una volta sola
/// (è un file pesante, ~9MB) e lo teniamo in cache — memoria e disco,
/// 24h — poi filtriamo per bounding box lato client come per Overpass.
class OpenGatsoPoiRemoteDatasource {
  final Dio _dio;
  OpenGatsoPoiRemoteDatasource(this._dio);

  static const _cacheTtl = Duration(hours: 24);
  static const _cacheFileName = 'open_gatso_poi_cache.csv';

  // Il dump GATSO_ALL.csv mischia velox veri ("max @NN"/"average @NN",
  // quest'ultimi i tutor/tratti a velocità media) con altri ostacoli non
  // di velocità ("stop" = incroci ferroviari/semafori, "tunnel") — righe
  // sempre `lon,lat,"tipo","descrizione"`, mai un header.
  static final _rowPattern =
      RegExp(r'^(-?\d+\.?\d*),(-?\d+\.?\d*),"([^"]*)","([^"]*)"$');

  List<_GatsoPoint>? _points;
  DateTime? _loadedAt;
  Future<List<_GatsoPoint>>? _loading;

  Future<List<RadarEvent>> veloxCameras(RadarBounds bounds) async {
    final url = dotenv.env['OPEN_GATSO_POI_URL'];
    if (url == null || url.isEmpty) return const [];

    final List<_GatsoPoint> points;
    try {
      points = await _ensureLoaded(url);
    } catch (_) {
      // Dump non scaricabile/parsabile: nessun dato da questa fonte,
      // Overpass da solo resta comunque valido (mai un'eccezione fino
      // alla UI, stesso contratto degli altri datasource radar).
      return const [];
    }

    final events = <RadarEvent>[];
    for (final p in points) {
      if (p.lat < bounds.south || p.lat > bounds.north) continue;
      if (p.lon < bounds.west || p.lon > bounds.east) continue;
      events.add(RadarEvent(
        id: 'gatso-${p.lat},${p.lon}',
        category: RadarCategory.velox,
        source: RadarSource.api,
        lat: p.lat,
        lon: p.lon,
      ));
    }
    return events;
  }

  Future<List<_GatsoPoint>> _ensureLoaded(String url) {
    final cached = _points;
    final loadedAt = _loadedAt;
    if (cached != null &&
        loadedAt != null &&
        DateTime.now().difference(loadedAt) < _cacheTtl) {
      return Future.value(cached);
    }
    // Richieste concorrenti (più bounding box in rapida successione)
    // condividono lo stesso download invece di scaricare 9MB più volte.
    return _loading ??= _load(url).whenComplete(() => _loading = null);
  }

  Future<List<_GatsoPoint>> _load(String url) async {
    final fromDisk = await _readDiskCache();
    if (fromDisk != null) {
      _points = fromDisk;
      _loadedAt = DateTime.now();
      return fromDisk;
    }

    final response = await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'User-Agent': 'H.R.R-App/1.0'},
      ),
    );
    final points = _parseZip(response.data!);
    _points = points;
    _loadedAt = DateTime.now();
    unawaited(_writeDiskCache(points));
    return points;
  }

  List<_GatsoPoint> _parseZip(List<int> zipBytes) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final csvFile = archive.files.firstWhere(
      (f) => f.isFile && f.name.endsWith('GATSO_ALL.csv'),
      orElse: () => throw StateError('GATSO_ALL.csv non trovato nello zip'),
    );
    return _parseCsv(utf8.decode(csvFile.content));
  }

  List<_GatsoPoint> _parseCsv(String content) {
    final points = <_GatsoPoint>[];
    for (final line in const LineSplitter().convert(content)) {
      if (line.isEmpty) continue;
      final match = _rowPattern.firstMatch(line);
      if (match == null) continue;
      final type = match.group(3)!;
      if (!type.startsWith('max') && !type.startsWith('average')) continue;
      final lon = double.tryParse(match.group(1)!);
      final lat = double.tryParse(match.group(2)!);
      if (lat == null || lon == null) continue;
      points.add(_GatsoPoint(lat, lon));
    }
    return points;
  }

  Future<List<_GatsoPoint>?> _readDiskCache() async {
    if (kIsWeb) return null; // niente filesystem persistente sul target web
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return null;
      final stat = await file.stat();
      if (DateTime.now().difference(stat.modified) >= _cacheTtl) return null;

      final points = <_GatsoPoint>[];
      await for (final line in file
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final parts = line.split(',');
        if (parts.length != 2) continue;
        final lat = double.tryParse(parts[0]);
        final lon = double.tryParse(parts[1]);
        if (lat == null || lon == null) continue;
        points.add(_GatsoPoint(lat, lon));
      }
      return points.isEmpty ? null : points;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDiskCache(List<_GatsoPoint> points) async {
    if (kIsWeb) return;
    try {
      final file = await _cacheFile();
      final buffer = StringBuffer();
      for (final p in points) {
        buffer.writeln('${p.lat},${p.lon}');
      }
      await file.writeAsString(buffer.toString(), flush: true);
    } catch (_) {
      // Cache su disco è solo un'ottimizzazione (evita 9MB ad ogni
      // avvio app): se fallisce (spazio, permessi) resta comunque
      // valida la cache in memoria per la sessione corrente.
    }
  }

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_cacheFileName');
  }
}
