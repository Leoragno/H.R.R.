import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/draggable_sheet_scaffold.dart';
import '../../../radar/domain/entities/radar_bounds.dart';
import '../../../radar/domain/entities/radar_event.dart';
import '../../../radar/presentation/providers/radar_provider.dart';
import '../../../radar/presentation/widgets/radar_icons.dart';
import '../../../radar/presentation/widgets/report_option_tile.dart';
import '../../../trip/presentation/providers/live_map_provider.dart';

/// Mappa reale (MapLibre GL + tile OpenFreeMap/OSM) dietro la sheet Guida,
/// al posto della griglia decorativa finta [StreetGridBackground]. Il
/// centro iniziale usa l'ultima posizione nota se disponibile, altrimenti
/// un centro neutro (Italia) — nessun prompt di permesso esplicito qui,
/// [MapLibreMap.myLocationEnabled] gestisce da sé il pallino posizione live.
///
/// Ospita anche i marker Velox/Pattuglia (API arancioni, community ciano —
/// vedi lib/features/radar/) e la posizione live di tutti gli utenti che
/// stanno guidando ora (vedi LiveMapController — stesso provider usato da
/// TripLiveScreen, qui riletto così sono visibili anche senza un proprio
/// viaggio attivo): stessa mappa, nessuna seconda view sovrapposta. I
/// marker sono Symbol nativi MapLibre (non widget Flutter overlay) per
/// restare fluidi durante pan/zoom anche con centinaia di punti.
class HomeMapBackground extends ConsumerStatefulWidget {
  final ValueChanged<MapLibreMapController>? onMapCreated;
  const HomeMapBackground({super.key, this.onMapCreated});

  static const _fallbackCenter = LatLng(41.9028, 12.4964); // Roma

  @override
  ConsumerState<HomeMapBackground> createState() => _HomeMapBackgroundState();
}

class _HomeMapBackgroundState extends ConsumerState<HomeMapBackground> {
  // Null finché non abbiamo un centro vero (fix GPS fresco o, in mancanza,
  // il fallback Italia dopo il fallimento/timeout) — la mappa non viene
  // montata prima (vedi build()). `initialCameraPosition` è letto da
  // MapLibreMap solo alla creazione della platform view: aggiornarlo dopo
  // (come faceva la vecchia `_initialCamera` via setState quando
  // Geolocator.getLastKnownPosition risolveva più tardi) non sposta più la
  // camera, quindi la mappa restava bloccata sul fallback Roma/zoom 5 per
  // (quasi) tutti — nessuna posizione nota in cache è comune al primo
  // avvio — che sembrava "non ci si può muovere" pur avendo pan/zoom
  // tecnicamente attivi. Stesso pattern già usato in TripLiveScreen/
  // GameMapBackground.
  LatLng? _cameraCenter;
  double _initialZoom = 5;

  MapLibreMapController? _controller;
  bool _iconsReady = false;
  Timer? _boundsDebounce;
  final Map<String, Symbol> _symbolsById = {};

  // Marker + percorso degli utenti che stanno guidando ora (vedi
  // LiveMapController), tenuti per profileId così un aggiornamento di
  // posizione fa update invece di add/remove ad ogni fix — stesso pattern
  // di trip_live_screen.dart.
  final Map<String, Symbol> _liveSymbolsById = {};
  final Map<String, Line> _liveLinesById = {};

  @override
  void initState() {
    super.initState();
    _resolveInitialCamera();
  }

  @override
  void dispose() {
    _boundsDebounce?.cancel();
    super.dispose();
  }

  Future<void> _resolveInitialCamera() async {
    try {
      // .timeout() Dart-side, non solo LocationSettings.timeLimit: su web
      // geolocator_web 4.1.4 passa Duration.inMicroseconds al posto di
      // inMilliseconds nell'opzione `timeout` del browser, quindi "10
      // secondi" diventa ~10000 secondi (~2h45) e non scatta mai in tempo
      // utile — senza questo la mappa restava bloccata sullo spinner per
      // ore invece di cadere sul fallback.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _cameraCenter = LatLng(position.latitude, position.longitude);
        _initialZoom = 14;
      });
    } catch (_) {
      // Permesso non concesso, servizio posizione assente o timeout: la
      // mappa resterebbe altrimenti bloccata sullo spinner per sempre —
      // meglio il centro di fallback, comunque liberamente esplorabile.
      if (!mounted) return;
      setState(() => _cameraCenter = HomeMapBackground._fallbackCenter);
    }
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final icons = await RadarIconSet.render();
      for (final entry in icons.entries) {
        await controller.addImage(entry.key, entry.value);
      }
      if (!mounted) return;
      setState(() => _iconsReady = true);
    } catch (_) {
      // Il supporto Symbol/addImage di maplibre_gl non è uniforme su
      // tutte le piattaforme (in particolare il target web): niente
      // marker piuttosto che un'eccezione che destabilizza il render
      // tree della mappa — il resto della Guida resta comunque usabile.
    }
    unawaited(_updateVisibleBounds());
    unawaited(_syncLiveDrivers(ref.read(liveMapControllerProvider)));
  }

  /// Allinea marker+percorso degli utenti allo stato del canale realtime:
  /// aggiunge chi ha appena iniziato a guidare, aggiorna posizione/percorso
  /// di chi è già sulla mappa, rimuove chi ha smesso — identico a
  /// _syncLiveDrivers in trip_live_screen.dart, qui però senza bisogno di
  /// un proprio viaggio attivo.
  Future<void> _syncLiveDrivers(Map<String, LiveDriver> drivers) async {
    final controller = _controller;
    if (controller == null) return;

    try {
      for (final profileId in _liveSymbolsById.keys.toList()) {
        if (!drivers.containsKey(profileId)) {
          await controller.removeSymbol(_liveSymbolsById.remove(profileId)!);
        }
      }
      for (final profileId in _liveLinesById.keys.toList()) {
        if (!drivers.containsKey(profileId)) {
          await controller.removeLine(_liveLinesById.remove(profileId)!);
        }
      }

      for (final driver in drivers.values) {
        final symbolOptions = SymbolOptions(
          geometry: LatLng(driver.lat, driver.lng),
          textField: driver.username,
          textColor: driver.accentColor,
          textHaloColor: '#000000',
          textHaloWidth: 1.2,
          textSize: 13,
          textOffset: const Offset(0, 1.4),
        );
        final symbol = _liveSymbolsById[driver.profileId];
        if (symbol == null) {
          _liveSymbolsById[driver.profileId] =
              await controller.addSymbol(symbolOptions);
        } else {
          await controller.updateSymbol(symbol, symbolOptions);
        }

        if (driver.routePoints.length < 2) continue;
        final geometry = [
          for (final p in driver.routePoints) LatLng(p.lat, p.lng)
        ];
        final lineOptions = LineOptions(
          geometry: geometry,
          lineColor: driver.accentColor,
          lineWidth: 3,
          lineOpacity: 0.75,
        );
        final line = _liveLinesById[driver.profileId];
        if (line == null) {
          _liveLinesById[driver.profileId] =
              await controller.addLine(lineOptions);
        } else {
          await controller.updateLine(line, lineOptions);
        }
      }
    } catch (_) {
      // Stesso motivo di _syncSymbols/_onStyleLoaded sopra: il supporto
      // Symbol/Line di maplibre_gl non è uniforme su tutte le piattaforme
      // (in particolare il target web) — mai lasciar risalire
      // un'eccezione della piattaforma mappa da qui, il resto della Guida
      // deve restare usabile anche senza i marker degli altri utenti.
    }
  }

  // Debounce (500ms): onCameraIdle può firmare più volte in rapida
  // successione durante un pinch-zoom continuo — aspettiamo che il
  // riquadro si stabilizzi prima di chiedere a Overpass/Waze (che a loro
  // volta cachano per bounding box, vedi overpass/waze_remote_datasource).
  void _onCameraIdle() {
    _boundsDebounce?.cancel();
    _boundsDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_updateVisibleBounds());
    });
  }

  // Raggio fisso attorno al centro mappa, non più proporzionale al
  // riquadro visibile: a zoom stretto (es. appena centrati sul GPS) lo
  // schermo da solo copre un'area minuscola — quasi mai un velox dentro
  // anche se ce ne sono nei dintorni, dato quanto sono sparsi i dati OSM
  // (~1 ogni 15km² in zone dense, verificato). L'utente si aspetta "i
  // velox della zona", non solo quelli esattamente in vista.
  static const _queryRadiusKm = 20.0;
  static const _kmPerDegLat = 111.0;

  Future<void> _updateVisibleBounds() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final region = await controller.getVisibleRegion();
      final centerLat =
          (region.northeast.latitude + region.southwest.latitude) / 2;
      final centerLon =
          (region.northeast.longitude + region.southwest.longitude) / 2;
      const latDelta = _queryRadiusKm / _kmPerDegLat;
      final kmPerDegLon =
          _kmPerDegLat * math.cos(centerLat * math.pi / 180).abs();
      final lonDelta = _queryRadiusKm / kmPerDegLon.clamp(1.0, _kmPerDegLat);
      final bounds = RadarBounds.quantized(
        south: centerLat - latDelta,
        west: centerLon - lonDelta,
        north: centerLat + latDelta,
        east: centerLon + lonDelta,
      );
      if (!mounted) return;
      ref.read(mapBoundsControllerProvider.notifier).update(bounds);
    } catch (_) {
      // Mappa non ancora pronta a rispondere: il prossimo onCameraIdle
      // riprova da solo, nessuna azione da segnalare qui.
    }
  }

  Future<void> _syncSymbols(List<RadarEvent> events) async {
    final controller = _controller;
    if (controller == null || !_iconsReady) return;

    try {
      final incomingIds = events.map((e) => e.id).toSet();
      final staleIds =
          _symbolsById.keys.where((id) => !incomingIds.contains(id)).toList();
      if (staleIds.isNotEmpty) {
        final staleSymbols = staleIds.map((id) => _symbolsById.remove(id)!);
        await controller.removeSymbols(staleSymbols);
      }

      final newEvents =
          events.where((e) => !_symbolsById.containsKey(e.id)).toList();
      if (newEvents.isEmpty) return;

      final options = [
        for (final e in newEvents)
          SymbolOptions(
            geometry: LatLng(e.lat, e.lon),
            iconImage: RadarIconSet.imageIdFor(
              e.category == RadarCategory.velox,
              e.source == RadarSource.community,
            ),
            iconSize: 0.42,
            // Stessa icona, mai un colore in più (vedi DESIGN.md): un
            // velox confermato da più fonti (RadarEvent.verified) resta
            // pieno, uno da fonte singola non incrociata si attenua.
            iconOpacity: e.verified ? 1.0 : 0.55,
          ),
      ];
      final symbols = await controller.addSymbols(options);
      for (var i = 0; i < newEvents.length; i++) {
        _symbolsById[newEvents[i].id] = symbols[i];
      }
    } catch (_) {
      // Stesso motivo di _onStyleLoaded sopra: mai lasciar risalire
      // un'eccezione della piattaforma mappa da qui.
    }
  }

  Future<void> _onMapLongPress(math.Point<double> point, LatLng coords) async {
    if (!ref.read(radarModeControllerProvider)) return;
    if (!mounted) return;

    final category = await DraggableSheetScaffold.show<RadarCategory>(
      context,
      title: 'Segnala qui',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReportOptionTile(
            icon: Icons.videocam_rounded,
            label: 'Velox',
            onTap: () => Navigator.of(ctx).pop(RadarCategory.velox),
          ),
          const SizedBox(height: AppSpace.sm),
          ReportOptionTile(
            icon: Icons.shield_rounded,
            label: 'Pattuglia',
            onTap: () => Navigator.of(ctx).pop(RadarCategory.pattuglia),
          ),
        ],
      ),
    );
    if (category == null) return;
    await ref.read(radarActionsControllerProvider.notifier).submitReport(
          category: category,
          lat: coords.latitude,
          lon: coords.longitude,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<RadarEvent>>>(homeMapMarkersProvider,
        (previous, next) {
      final events = next.valueOrNull;
      if (events != null) unawaited(_syncSymbols(events));
    });
    ref.listen<Map<String, LiveDriver>>(liveMapControllerProvider,
        (previous, next) => unawaited(_syncLiveDrivers(next)));

    final center = _cameraCenter;
    if (center == null) {
      return const ColoredBox(
        color: AppColor.void_,
        child: Center(
          child: CircularProgressIndicator(color: AppColor.cyan),
        ),
      );
    }

    return ColoredBox(
      color: AppColor.void_,
      child: MapLibreMap(
        styleString: dotenv.env['MAP_STYLE_URL'] ?? MapLibreStyles.demo,
        initialCameraPosition:
            CameraPosition(target: center, zoom: _initialZoom),
        myLocationEnabled: true,
        myLocationRenderMode: MyLocationRenderMode.compass,
        // .none, non .tracking: qui (a differenza di TripLiveScreen durante
        // una guida attiva) l'utente deve poter esplorare liberamente la
        // mappa senza che ogni fix GPS gli riporti la camera addosso alla
        // propria posizione — il pallino "io sono qui" resta comunque
        // visibile (myLocationEnabled), il recenter è un'azione esplicita
        // (vedi HomeScreen._RecenterButton via onMapCreated).
        myLocationTrackingMode: MyLocationTrackingMode.none,
        onMapCreated: (c) {
          _controller = c;
          widget.onMapCreated?.call(c);
        },
        onStyleLoadedCallback: _onStyleLoaded,
        onCameraIdle: _onCameraIdle,
        onMapLongClick: _onMapLongPress,
      ),
    );
  }
}
