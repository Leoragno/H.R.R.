import 'dart:async';
import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/draggable_sheet_scaffold.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../radar/domain/entities/radar_bounds.dart';
import '../../../radar/domain/entities/radar_event.dart';
import '../../../radar/presentation/providers/radar_provider.dart';
import '../../../radar/presentation/widgets/radar_icons.dart';
import '../../../trip/presentation/providers/crew_live_map_provider.dart';

/// Mappa reale (MapLibre GL + tile OpenFreeMap/OSM) dietro la sheet Guida,
/// al posto della griglia decorativa finta [StreetGridBackground]. Il
/// centro iniziale usa l'ultima posizione nota se disponibile, altrimenti
/// un centro neutro (Italia) — nessun prompt di permesso esplicito qui,
/// [MapLibreMap.myLocationEnabled] gestisce da sé il pallino posizione live.
///
/// Ospita anche i marker Velox/Pattuglia (API arancioni, Crew ciano — vedi
/// lib/features/radar/) e la posizione live dei membri della crew che
/// stanno guidando ora (vedi CrewLiveMapController — stesso provider usato
/// da TripLiveScreen, qui riletto così i compagni sono visibili anche
/// senza un proprio viaggio attivo): stessa mappa, nessuna seconda view
/// sovrapposta. I marker sono Symbol nativi MapLibre (non widget Flutter
/// overlay) per restare fluidi durante pan/zoom anche con centinaia di
/// punti.
class HomeMapBackground extends ConsumerStatefulWidget {
  final ValueChanged<MapLibreMapController>? onMapCreated;
  const HomeMapBackground({super.key, this.onMapCreated});

  static const _fallbackCenter = LatLng(41.9028, 12.4964); // Roma

  @override
  ConsumerState<HomeMapBackground> createState() => _HomeMapBackgroundState();
}

class _HomeMapBackgroundState extends ConsumerState<HomeMapBackground> {
  CameraPosition _initialCamera =
      const CameraPosition(target: HomeMapBackground._fallbackCenter, zoom: 5);

  MapLibreMapController? _controller;
  bool _iconsReady = false;
  Timer? _boundsDebounce;
  final Map<String, Symbol> _symbolsById = {};

  // Marker + percorso dei membri della crew che stanno guidando ora (vedi
  // CrewLiveMapController), tenuti per profileId così un aggiornamento di
  // posizione fa update invece di add/remove ad ogni fix — stesso pattern
  // di trip_live_screen.dart.
  final Map<String, Symbol> _crewSymbolsById = {};
  final Map<String, Line> _crewLinesById = {};

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
      final position = await Geolocator.getLastKnownPosition();
      if (position == null || !mounted) return;
      setState(() {
        _initialCamera = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 14,
        );
      });
    } catch (_) {
      // Permesso non concesso o servizio posizione assente: resta sul
      // centro di fallback, non è un errore da mostrare all'utente.
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
    unawaited(_syncCrewDrivers(ref.read(crewLiveMapControllerProvider)));
  }

  /// Allinea marker+percorso dei membri della crew allo stato del canale
  /// realtime: aggiunge chi ha appena iniziato a guidare, aggiorna
  /// posizione/percorso di chi è già sulla mappa, rimuove chi ha smesso —
  /// identico a _syncCrewDrivers in trip_live_screen.dart, qui però senza
  /// bisogno di un proprio viaggio attivo.
  Future<void> _syncCrewDrivers(Map<String, CrewLiveDriver> drivers) async {
    final controller = _controller;
    if (controller == null) return;

    try {
      for (final profileId in _crewSymbolsById.keys.toList()) {
        if (!drivers.containsKey(profileId)) {
          await controller.removeSymbol(_crewSymbolsById.remove(profileId)!);
        }
      }
      for (final profileId in _crewLinesById.keys.toList()) {
        if (!drivers.containsKey(profileId)) {
          await controller.removeLine(_crewLinesById.remove(profileId)!);
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
        final symbol = _crewSymbolsById[driver.profileId];
        if (symbol == null) {
          _crewSymbolsById[driver.profileId] =
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
        final line = _crewLinesById[driver.profileId];
        if (line == null) {
          _crewLinesById[driver.profileId] =
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
      // deve restare usabile anche senza i marker della crew.
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

  Future<void> _updateVisibleBounds() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final region = await controller.getVisibleRegion();
      final bounds = RadarBounds.quantized(
        south: region.southwest.latitude,
        west: region.southwest.longitude,
        north: region.northeast.latitude,
        east: region.northeast.longitude,
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
              e.source == RadarSource.crew,
            ),
            iconSize: 0.42,
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

  Future<void> _onMapLongPress(Point<double> point, LatLng coords) async {
    if (!ref.read(radarModeControllerProvider)) return;
    final crewId = ref.read(myProfileProvider).valueOrNull?.crewId;
    if (crewId == null) return; // niente crew, niente segnalazioni condivise
    if (!mounted) return;

    final category = await DraggableSheetScaffold.show<RadarCategory>(
      context,
      title: 'Segnala qui',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ReportOptionTile(
            icon: Icons.videocam_rounded,
            label: 'Velox',
            onTap: () => Navigator.of(ctx).pop(RadarCategory.velox),
          ),
          const SizedBox(height: 8),
          _ReportOptionTile(
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
    ref.listen<Map<String, CrewLiveDriver>>(crewLiveMapControllerProvider,
        (previous, next) => unawaited(_syncCrewDrivers(next)));

    return ColoredBox(
      color: AppColors.guidaBg,
      child: MapLibreMap(
        styleString: dotenv.env['MAP_STYLE_URL'] ?? MapLibreStyles.demo,
        initialCameraPosition: _initialCamera,
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

class _ReportOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ReportOptionTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF0101828),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: AppColors.guidaCyan),
              const SizedBox(width: 14),
              Text(label,
                  style: AppTheme.archivo(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}
