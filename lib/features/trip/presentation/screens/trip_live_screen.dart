import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/draggable_sheet_scaffold.dart';
import '../../../../core/widgets/neon_cta_button.dart';
import '../../../../core/widgets/recenter_button.dart';
import '../../../radar/domain/entities/radar_bounds.dart';
import '../../../radar/domain/entities/radar_event.dart';
import '../../../radar/presentation/providers/radar_provider.dart';
import '../../../radar/presentation/providers/radar_proximity_provider.dart';
import '../../../radar/presentation/widgets/radar_icons.dart';
import '../../../radar/presentation/widgets/report_option_tile.dart';
import '../providers/live_map_provider.dart';
import '../providers/trip_live_provider.dart';
import '../providers/voice_channel_provider.dart';
import '../utils/route_smoothing.dart';
import '../widgets/speedometer_gauge.dart';

enum _LiveView { map, speedometer }

/// HUD del viaggio live, con toggle mappa/tachimetro (Guida.dc.html righe
/// 152-339, isMapView/isSpeedView). La logica di tracking resta invariata
/// in TripLiveController.
class TripLiveScreen extends ConsumerStatefulWidget {
  const TripLiveScreen({super.key});

  @override
  ConsumerState<TripLiveScreen> createState() => _TripLiveScreenState();
}

class _TripLiveScreenState extends ConsumerState<TripLiveScreen> {
  _LiveView _view = _LiveView.speedometer;
  RadarEvent? _activeAlert;
  Timer? _alertHideTimer;

  // Stato del pannello "Auto amiche" (canale drivers-live condiviso, vedi
  // LiveMapController): espanso mostra la lista dei driver online + il
  // pulsante PTT, collassato mostra solo il riepilogo. Gli altri driver
  // sono sempre visibili sulla mappa (vedi _MapView), indipendentemente da
  // questo stato — stesso comportamento di home_map_background.dart. Il
  // canale voce vero e proprio vive in VoiceChannelController
  // (voice_channel_provider.dart), agganciato direttamente da _PttButton.
  bool _amicheExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Se il tracking è già "tracking" (guida ripristinata da
      // resumeTrip() prima di navigare qui, vedi la Home), non avviarne
      // una seconda sopra quella recuperata.
      if (ref.read(tripLiveControllerProvider).status == TripLiveStatus.idle) {
        ref.read(tripLiveControllerProvider.notifier).startTrip();
      }
    });
  }

  @override
  void dispose() {
    _alertHideTimer?.cancel();
    super.dispose();
  }

  // RadarProximityController emette un "impulso" (non uno stato persistente,
  // vedi il provider) ogni volta che si è vicini a un nuovo evento non
  // ancora in cooldown: qui decidiamo per quanto resta visibile l'avviso,
  // indipendentemente da quante volte il provider ricalcola nel frattempo.
  void _onProximityAlert(RadarEvent event) {
    _alertHideTimer?.cancel();
    setState(() => _activeAlert = event);
    _alertHideTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _activeAlert = null);
    });
  }

  Future<void> _finish() async {
    try {
      final summary =
          await ref.read(tripLiveControllerProvider.notifier).finishTrip();
      if (!mounted || summary == null) return;
      context.pushReplacement(AppRoutes.tripSummary);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile salvare il viaggio. Riprova.'),
          backgroundColor: AppColor.danger,
        ),
      );
    }
  }

  Future<void> _discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1522),
        title: const Text('Annullare il viaggio?'),
        content: const Text(
            'Il viaggio verrà scartato, nessun XP/REP verrà assegnato.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continua')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Annulla viaggio',
                style: TextStyle(color: AppColor.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(tripLiveControllerProvider.notifier).discardTrip();
      if (mounted) context.pop();
    }
  }

  /// Il risparmio energetico può sospendere il GPS in background e
  /// interrompere la registrazione — vedi TripLiveController._checkBatterySaver.
  /// Mostrato una sola volta per transizione a true (vedi ref.listen in
  /// build), non ripetuto ad ogni rebuild finché resta attivo.
  Future<void> _showBatterySaverWarning() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1522),
        title: const Text('Risparmio energetico attivo'),
        content: const Text(
          'Con il risparmio energetico attivo il sistema può sospendere il '
          'GPS quando l\'app va in background, interrompendo la '
          'registrazione della guida. Per una registrazione affidabile ti '
          'consigliamo di disattivarlo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ho capito'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ph.openAppSettings();
            },
            child: const Text('Apri impostazioni',
                style: TextStyle(color: AppColor.cyan)),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tripLiveControllerProvider);
    final tracking = state.status == TripLiveStatus.tracking;

    ref.listen<AsyncValue<RadarEvent?>>(radarProximityControllerProvider,
        (previous, next) {
      final event = next.valueOrNull;
      if (event != null) _onProximityAlert(event);
    });

    ref.listen<TripLiveState>(tripLiveControllerProvider, (previous, next) {
      if (next.batterySaverActive && previous?.batterySaverActive != true) {
        _showBatterySaverWarning();
      }
    });

    return Scaffold(
      backgroundColor: AppColor.void_,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  child: Row(
                    children: [
                      _RoundIconButton(
                        icon: Icons.close_rounded,
                        onTap: _discard,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColor.danger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColor.danger),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.fiber_manual_record,
                                size: 10, color: AppColor.danger),
                            const SizedBox(width: 6),
                            Text(
                              tracking ? 'LIVE' : 'AVVIO...',
                              style: AppType.text(
                                color: AppColor.danger,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _RoundIconButton(
                        icon: _view == _LiveView.map
                            ? Icons.speed_rounded
                            : Icons.map_rounded,
                        onTap: () => setState(() {
                          _view = _view == _LiveView.map
                              ? _LiveView.speedometer
                              : _LiveView.map;
                        }),
                      ),
                    ],
                  ),
                ),
                if (state.status == TripLiveStatus.error)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.gps_off_rounded,
                                size: 48,
                                color: AppColor.danger.withValues(alpha: 0.7)),
                            const SizedBox(height: 12),
                            Text(
                              state.errorMessage ?? 'Errore GPS',
                              style: AppType.text(
                                  color: AppColor.inkMuted),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            NeonCtaButton(
                              label: 'Riprova',
                              minHeight: 52,
                              onPressed: () => ref
                                  .read(tripLiveControllerProvider.notifier)
                                  .startTrip(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (state.status == TripLiveStatus.finishing)
                  // Smontata subito la mappa (col suo platform view
                  // MapLibre) invece di lasciarla montata fino al pop della
                  // route: altrimenti il pushReplacement in _finish() la
                  // smonta di colpo a metà della sua transizione, col
                  // flash nero visto durante il salvataggio.
                  const Expanded(child: _FinishingView())
                else
                  Expanded(
                    child: _view == _LiveView.speedometer
                        ? _SpeedView(
                            state: state, formatDuration: _formatDuration)
                        : _MapView(state: state),
                  ),
                // Barra "Auto amiche" collassata: inline, sopra la CTA — mai
                // in overlay qui, altrimenti la copre (vedi _AmicheCard).
                if (state.status == TripLiveStatus.tracking &&
                    _view == _LiveView.map &&
                    !_amicheExpanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                    child: _AutoAmicheCollapsedBar(
                      speedKmh: state.currentSpeedKmh,
                      onTap: () => setState(() => _amicheExpanded = true),
                    ),
                  ),
                if (state.status != TripLiveStatus.error)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: Visibility(
                      // Nascosta (non solo coperta) quando il pannello Auto
                      // amiche è espanso: un solo elemento con glow per
                      // schermata, il PTT diventa il protagonista — vedi
                      // regola 1 di DESIGN.md.
                      visible: !(_view == _LiveView.map && _amicheExpanded),
                      maintainState: true,
                      maintainAnimation: true,
                      maintainSize: true,
                      child: NeonCtaButton(
                        label: 'Termina viaggio',
                        icon: Icons.flag_rounded,
                        minHeight: 60,
                        onPressed: tracking ? _finish : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_activeAlert != null) _RadarAlertBanner(event: _activeAlert!),
          // Pannello "Auto amiche" espanso: solo qui in overlay assoluto,
          // apposta sopra la CTA "Termina viaggio" (stesso trattamento del
          // bottom sheet nei mock) — la barra collassata sopra resta invece
          // sempre inline, non deve mai coprire nulla.
          if (_view == _LiveView.map &&
              state.status == TripLiveStatus.tracking &&
              _amicheExpanded)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: _AmicheCard(
                    child: _ExpandedGroup(
                      drivers: ref.watch(liveMapControllerProvider),
                      myPosition: state.routePoints.isEmpty
                          ? null
                          : state.routePoints.last,
                      onCollapse: () =>
                          setState(() => _amicheExpanded = false),
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 180.ms).slideY(begin: 0.12, end: 0),
        ],
      ),
    );
  }
}

/// Avviso di prossimità Velox/Pattuglia durante DRIVE — [RadarEvent]
/// arrivato da [radarProximityControllerProvider], che riusa il GPS già
/// live del viaggio in corso (nessun nuovo stream di posizione).
class _RadarAlertBanner extends StatelessWidget {
  final RadarEvent event;
  const _RadarAlertBanner({required this.event});

  @override
  Widget build(BuildContext context) {
    final isVelox = event.category == RadarCategory.velox;
    final isCommunity = event.source == RadarSource.community;
    final color = isCommunity ? AppColor.cyan : const Color(0xFFFF8A1F);
    final label = switch ((isVelox, isCommunity)) {
      (true, true) => 'Velox segnalato dalla community nelle vicinanze',
      (true, false) => 'Autovelox nelle vicinanze',
      (false, true) => 'Pattuglia segnalata dalla community nelle vicinanze',
      (false, false) => 'Pattuglia nelle vicinanze',
    };

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xF00A0E1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 1.4),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVelox ? Icons.videocam_rounded : Icons.local_police_rounded,
                color: color,
                size: 26,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  style: AppType.text(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColor.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.2, end: 0);
  }
}

/// Mostrata mentre TripLiveController.finishTrip() salva il viaggio
/// (chiamata RPC + claim territori) — sostituisce subito la mappa/
/// tachimetro invece di lasciarli montati fino alla navigazione, così lo
/// smontaggio del platform view MapLibre avviene qui, non nel mezzo del
/// pushReplacement verso il riepilogo (vedi TripLiveScreen._finish).
class _FinishingView extends StatelessWidget {
  const _FinishingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColor.cyan),
          const SizedBox(height: 16),
          Text('Salvataggio del viaggio...',
              style: AppType.text(color: AppColor.inkMuted)),
        ],
      ),
    );
  }
}

class _SpeedView extends StatelessWidget {
  final TripLiveState state;
  final String Function(Duration) formatDuration;
  const _SpeedView({required this.state, required this.formatDuration});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: SpeedometerGauge(speed: state.currentSpeedKmh),
            ),
          ).animate().fadeIn(),
          const SizedBox(height: 18),
          // Righe di 2 invece di GridView.count(childAspectRatio: ...): un
          // rapporto fisso va in overflow non appena il testo è più alto
          // del previsto (scala font di sistema, locale con etichette più
          // lunghe) — qui ogni cella prende l'altezza che le serve, mai un
          // taglio fisso.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StatCell(
                    label: 'Distanza',
                    value: state.distanceKm.toStringAsFixed(1),
                    unit: 'km'),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: _StatCell(
                    label: 'Tempo',
                    value: formatDuration(state.elapsed),
                    unit: ''),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StatCell(
                    label: 'Vel. media',
                    value: state.avgSpeedKmh.toStringAsFixed(0),
                    unit: 'km/h'),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: _StatCell(
                    label: 'Vel. massima',
                    value: state.maxSpeedKmh.toStringAsFixed(0),
                    unit: 'km/h'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mappa reale (stesso pattern di HomeMapBackground) con il percorso
/// percorso disegnato in ciano man mano che arrivano nuovi punti GPS da
/// TripLiveController — al posto della griglia decorativa finta usata in
/// precedenza.
class _MapView extends ConsumerStatefulWidget {
  final TripLiveState state;
  const _MapView({required this.state});

  @override
  ConsumerState<_MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<_MapView> {
  static const _defaultZoom = 16.0;

  MapLibreMapController? _controller;
  Line? _routeLine;
  Circle? _meCircle;
  // Centro camera iniziale: null finché non abbiamo una posizione vera (la
  // mappa non viene montata prima, vedi build()) — mai un fallback fisso
  // tipo "Roma", che mostrerebbe la città sbagliata finché non arriva un
  // fix buono.
  LatLng? _cameraCenter;

  // Marker + percorso degli altri utenti che stanno guidando ora (vedi
  // LiveMapController), tenuti per profileId così un aggiornamento di
  // posizione fa update invece di add/remove ad ogni fix. Ogni driver è un
  // Circle colorato (accentColor) con sopra un Symbol con l'iniziale, non
  // più solo testo — vedi _AutoAmichePanel per lo stesso trattamento nella
  // lista.
  final Map<String, Line> _liveLines = {};
  final Map<String, Circle> _liveMarkers = {};
  final Map<String, Symbol> _liveSymbols = {};

  // Marker Velox/Pattuglia (API arancioni, community ciano) — stesso
  // trattamento di home_map_background.dart, qui anche durante la guida
  // live: prima mancavano del tutto su questa mappa.
  bool _iconsReady = false;
  Timer? _boundsDebounce;
  final Map<String, Symbol> _radarSymbolsById = {};

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

  /// Il tracking è già partito in TripLiveScreen.initState prima ancora
  /// che l'utente apra questa vista mappa: se TripLiveController ha già
  /// un punto (già filtrato per accuratezza/jitter, vedi
  /// TripLiveController._onPosition) lo riusiamo direttamente, senza una
  /// seconda richiesta GPS indipendente. Solo se il tracking è appena
  /// partito e non ha ancora nessun fix, forziamo una lettura fresca —
  /// mai Geolocator.getLastKnownPosition(), che può restare in cache per
  /// giorni e aprire la mappa sulla città sbagliata.
  Future<void> _resolveInitialCamera() async {
    final points = widget.state.routePoints;
    if (points.isNotEmpty) {
      _setCameraCenter(LatLng(points.last.lat, points.last.lng));
      return;
    }
    try {
      // .timeout() Dart-side: su web geolocator_web 4.1.4 non applica
      // correttamente LocationSettings.timeLimit (bug noto del pacchetto,
      // vedi home_map_background.dart), che da solo lascerebbe questa
      // chiamata pendente per ore invece di 10 secondi.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      ).timeout(const Duration(seconds: 10));
      _setCameraCenter(LatLng(position.latitude, position.longitude));
    } catch (_) {
      // GPS lento/permesso non ancora confermato: restiamo in attesa, il
      // primo punto buono di TripLiveController risolve comunque la
      // mappa via didUpdateWidget sotto.
    }
  }

  void _setCameraCenter(LatLng center) {
    if (!mounted || _cameraCenter != null) return;
    setState(() => _cameraCenter = center);
  }

  @override
  void didUpdateWidget(covariant _MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.routePoints.length != oldWidget.state.routePoints.length) {
      _updateRouteLine();
      _updateMeMarker();
      final points = widget.state.routePoints;
      if (points.isNotEmpty) {
        _setCameraCenter(LatLng(points.last.lat, points.last.lng));
      }
    }
  }

  Future<void> _updateRouteLine() async {
    final controller = _controller;
    final points = widget.state.routePoints;
    if (controller == null || points.length < 2) return;
    final geometry = [
      for (final p in smoothRouteForDisplay(points)) LatLng(p.lat, p.lng)
    ];
    final line = _routeLine;
    if (line == null) {
      _routeLine = await controller.addLine(
        LineOptions(
          geometry: geometry,
          lineColor: '#35E0FF',
          lineWidth: 4,
          lineOpacity: 0.9,
        ),
      );
    } else {
      await controller.updateLine(line, LineOptions(geometry: geometry));
    }
  }

  /// Marker "sei qui" pilotato dagli stessi punti già filtrati per
  /// accuratezza/jitter usati per il percorso — al posto del pallino blu
  /// nativo (myLocationEnabled), che legge il GPS grezzo del device senza
  /// passare da questo filtro e "saltava" più di quanto mostrino
  /// distanza/velocità già ripulite.
  Future<void> _updateMeMarker() async {
    final controller = _controller;
    final points = widget.state.routePoints;
    if (controller == null || points.isEmpty) return;
    final last = points.last;
    try {
      final options = CircleOptions(
        geometry: LatLng(last.lat, last.lng),
        circleRadius: 8,
        circleColor: '#35E0FF',
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2.5,
        circleOpacity: 0.95,
      );
      final existing = _meCircle;
      if (existing == null) {
        _meCircle = await controller.addCircle(options);
      } else {
        await controller.updateCircle(existing, options);
      }
    } catch (_) {
      // Vedi commento in _syncLiveDrivers.
    }
  }

  /// Ricentra la camera sulla posizione live corrente — la camera non
  /// segue più ogni fix da sola (vedi myLocationEnabled: false sotto),
  /// così l'utente resta libero di guardarsi intorno/zoomare senza che
  /// si riaggiusti da sola ad ogni secondo.
  Future<void> _recenterCamera() async {
    final controller = _controller;
    final points = widget.state.routePoints;
    if (controller == null || points.isEmpty) return;
    final last = points.last;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(last.lat, last.lng), _defaultZoom),
    );
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  // Debounce (500ms): onCameraIdle può firmare più volte in rapida
  // successione durante un pinch-zoom continuo — stesso pattern di
  // home_map_background.dart.
  void _onCameraIdle() {
    _boundsDebounce?.cancel();
    _boundsDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_updateVisibleBounds());
    });
  }

  // Raggio fisso attorno al centro mappa, non più proporzionale al
  // riquadro visibile — stesso trattamento di home_map_background.dart:
  // a zoom stretto lo schermo copre un'area minuscola, quasi mai un velox
  // dentro anche se ce ne sono nei dintorni (i dati OSM sono sparsi,
  // ~1 ogni 15km² verificato). L'utente si aspetta "i velox della zona".
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
      // riprova da solo.
    }
  }

  /// Marker Velox/Pattuglia per la bounding box corrente — stesso
  /// trattamento di home_map_background.dart._syncSymbols.
  Future<void> _syncRadarSymbols(List<RadarEvent> events) async {
    final controller = _controller;
    if (controller == null || !_iconsReady) return;

    try {
      final incomingIds = events.map((e) => e.id).toSet();
      final staleIds = _radarSymbolsById.keys
          .where((id) => !incomingIds.contains(id))
          .toList();
      if (staleIds.isNotEmpty) {
        final staleSymbols =
            staleIds.map((id) => _radarSymbolsById.remove(id)!);
        await controller.removeSymbols(staleSymbols);
      }

      final newEvents =
          events.where((e) => !_radarSymbolsById.containsKey(e.id)).toList();
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
            iconOpacity: e.verified ? 1.0 : 0.55,
          ),
      ];
      final symbols = await controller.addSymbols(options);
      for (var i = 0; i < newEvents.length; i++) {
        _radarSymbolsById[newEvents[i].id] = symbols[i];
      }
    } catch (_) {
      // Stesso motivo di _syncLiveDrivers sopra: mai lasciar risalire
      // un'eccezione della piattaforma mappa da qui.
    }
  }

  /// Tieni premuto sulla mappa per segnalare un Velox/Pattuglia in quel
  /// punto — stesso flusso di home_map_background.dart._onMapLongPress,
  /// qui utile anche a mappa già in movimento durante la guida.
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

  Future<void> _onStyleLoaded() async {
    await _updateRouteLine();
    await _updateMeMarker();
    await _syncLiveDrivers(ref.read(liveMapControllerProvider));
    try {
      final icons = await RadarIconSet.render();
      for (final entry in icons.entries) {
        await _controller?.addImage(entry.key, entry.value);
      }
      if (!mounted) return;
      setState(() => _iconsReady = true);
    } catch (_) {
      // Stesso motivo di home_map_background.dart: mai lasciar risalire
      // un'eccezione della piattaforma mappa da qui.
    }
    unawaited(_updateVisibleBounds());
  }

  /// Allinea marker+percorso degli altri driver allo stato del canale
  /// realtime condiviso: aggiunge chi ha appena iniziato a guidare,
  /// aggiorna posizione/percorso di chi è già sulla mappa, rimuove chi ha
  /// smesso. Ogni driver è un Circle colorato (accentColor) + un Symbol con
  /// l'iniziale del nome sopra, non più solo testo.
  Future<void> _syncLiveDrivers(Map<String, LiveDriver> drivers) async {
    final controller = _controller;
    if (controller == null) return;

    try {
      for (final profileId in _liveSymbols.keys.toList()) {
        if (!drivers.containsKey(profileId)) {
          await controller.removeSymbol(_liveSymbols.remove(profileId)!);
        }
      }
      for (final profileId in _liveMarkers.keys.toList()) {
        if (!drivers.containsKey(profileId)) {
          await controller.removeCircle(_liveMarkers.remove(profileId)!);
        }
      }
      for (final profileId in _liveLines.keys.toList()) {
        if (!drivers.containsKey(profileId)) {
          await controller.removeLine(_liveLines.remove(profileId)!);
        }
      }

      for (final driver in drivers.values) {
        final markerOptions = CircleOptions(
          geometry: LatLng(driver.lat, driver.lng),
          circleRadius: 14,
          circleColor: driver.accentColor,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2,
          circleOpacity: 0.95,
        );
        final marker = _liveMarkers[driver.profileId];
        if (marker == null) {
          _liveMarkers[driver.profileId] =
              await controller.addCircle(markerOptions);
        } else {
          await controller.updateCircle(marker, markerOptions);
        }

        final initial = driver.username.trim().isEmpty
            ? '?'
            : driver.username.trim()[0].toUpperCase();
        final symbolOptions = SymbolOptions(
          geometry: LatLng(driver.lat, driver.lng),
          textField: initial,
          textColor: '#FFFFFF',
          textSize: 13,
          fontNames: const ['Open Sans Bold'],
        );
        final symbol = _liveSymbols[driver.profileId];
        if (symbol == null) {
          _liveSymbols[driver.profileId] =
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
        final line = _liveLines[driver.profileId];
        if (line == null) {
          _liveLines[driver.profileId] = await controller.addLine(lineOptions);
        } else {
          await controller.updateLine(line, lineOptions);
        }
      }
    } catch (_) {
      // Il supporto Symbol/Line di maplibre_gl non è uniforme su tutte le
      // piattaforme (in particolare il target web): niente marker/percorso
      // degli altri driver piuttosto che un'eccezione che destabilizza il
      // render tree della mappa — il resto della Guida live resta comunque
      // usabile (stesso trattamento di home_map_background.dart).
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(liveMapControllerProvider, (_, drivers) {
      _syncLiveDrivers(drivers);
    });
    ref.listen<AsyncValue<List<RadarEvent>>>(homeMapMarkersProvider,
        (previous, next) {
      final events = next.valueOrNull;
      if (events != null) unawaited(_syncRadarSymbols(events));
    });

    final center = _cameraCenter;
    if (center == null) {
      // Nessuna posizione risolta ancora: meglio uno spinner che aprire la
      // mappa su un centro sbagliato/arbitrario.
      return const Center(
        child: CircularProgressIndicator(color: AppColor.cyan),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: MapLibreMap(
            styleString: dotenv.env['MAP_STYLE_URL'] ?? MapLibreStyles.demo,
            initialCameraPosition:
                CameraPosition(target: center, zoom: _defaultZoom),
            myLocationEnabled: false,
            onMapCreated: _onMapCreated,
            // addLine prima che lo stile sia caricato lancia "Annotation
            // Manager has not been initialized" — va agganciato qui, non
            // in onMapCreated (che spara prima del caricamento stile).
            onStyleLoadedCallback: _onStyleLoaded,
            onCameraIdle: _onCameraIdle,
            onMapLongClick: _onMapLongPress,
          ),
        ),
        Positioned(
          right: 18,
          top: 18,
          child: RecenterButton(onTap: _recenterCamera),
        ),
      ],
    );
  }
}

/// Decorazione condivisa della card "Auto amiche" — usata sia dalla barra
/// collassata (inline nel flusso, sopra la CTA "Termina viaggio") sia dal
/// pannello espanso (overlay assoluto che copre la CTA, vedi TripLiveScreen.
/// build). Prima erano nella stessa Positioned bottom:0 e la barra
/// collassata finiva sempre sopra la CTA, coprendola: ora solo l'overlay
/// espanso lo fa, di proposito.
class _AmicheCard extends StatelessWidget {
  final Widget child;
  const _AmicheCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xEB0D1222), Color(0xF5060810)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x2E7896FF)),
      ),
      child: child,
    );
  }
}

/// Barra collassata "Auto amiche" — sempre inline nel flusso (mai in
/// overlay) mentre si è in vista mappa, così non copre mai la CTA sotto.
class _AutoAmicheCollapsedBar extends ConsumerWidget {
  final double speedKmh;
  final VoidCallback onTap;
  const _AutoAmicheCollapsedBar({required this.speedKmh, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineCount = ref.watch(liveMapControllerProvider).length;
    // Tiene vivo il canale voce (provider autoDispose) anche a pannello
    // chiuso: un "push" ricevuto mentre il gruppo è collassato deve
    // comunque riprodursi, non solo quando _ExpandedGroup/_PttButton sono
    // montati.
    final speaking = ref.watch(voiceChannelControllerProvider).speaking;

    return _AmicheCard(
      child: _CollapsedBar(
        speedKmh: speedKmh,
        onlineCount: onlineCount,
        speaking: speaking,
        onTap: onTap,
      ),
    );
  }
}

class _CollapsedBar extends StatelessWidget {
  final double speedKmh;
  final int onlineCount;
  final VoiceActivity? speaking;
  final VoidCallback onTap;
  const _CollapsedBar({
    required this.speedKmh,
    required this.onlineCount,
    required this.speaking,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('VELOCITÀ',
                  style: AppType.text(
                      fontSize: 12,
                      letterSpacing: 1.4,
                      color: AppColor.inkMuted)),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  text: speedKmh.toStringAsFixed(0),
                  style: AppType.text(
                      fontWeight: FontWeight.w900,
                      fontSize: 38,
                      color: AppColor.ink),
                  children: [
                    TextSpan(
                      text: ' km/h',
                      style: AppType.text(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColor.cyan),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: AppMotion.base,
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: speaking != null
                            ? AppColor.cyan.withValues(alpha: 0.22)
                            : AppColor.surfaceHigh,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mic_rounded,
                          color: AppColor.cyan, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text('AUTO AMICHE',
                        style: AppType.text(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColor.ink)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (speaking != null)
                      _Pill(
                          text:
                              '${speaking!.username.isEmpty ? "Qualcuno" : speaking!.username} parla',
                          tint: AppColor.cyan)
                    else
                      _Pill(text: '$onlineCount Online', tint: AppColor.cyan),
                    const SizedBox(width: 6),
                    const _Pill(text: 'Canale 1', tint: AppColor.inkMuted),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color tint;
  const _Pill({required this.text, required this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: AppType.text(
              fontSize: 11, fontWeight: FontWeight.w600, color: tint)),
    );
  }
}

class _ExpandedGroup extends ConsumerWidget {
  final Map<String, LiveDriver> drivers;
  final RoutePoint? myPosition;
  final VoidCallback onCollapse;

  const _ExpandedGroup({
    required this.drivers,
    required this.myPosition,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speakingId =
        ref.watch(voiceChannelControllerProvider.select((s) => s.speaking))
            ?.profileId;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onCollapse,
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColor.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Text('AUTO AMICHE',
                  style: AppType.text(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColor.ink)),
              const SizedBox(width: 6),
              Text('· Canale 1',
                  style:
                      AppType.text(fontSize: 13, color: AppColor.inkMuted)),
              const Spacer(),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColor.inkMuted),
                onPressed: onCollapse,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (drivers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text('Nessun altro utente online ora.',
                  style:
                      AppType.text(color: AppColor.inkMuted, fontSize: 13)),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final driver in drivers.values)
                      SizedBox(
                        width: cardWidth,
                        child: _DriverCard(
                          driver: driver,
                          myPosition: myPosition,
                          isSpeaking: driver.profileId == speakingId,
                        ),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 22),
          const Center(child: _PttButton()),
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final LiveDriver driver;
  final RoutePoint? myPosition;
  final bool isSpeaking;
  const _DriverCard({
    required this.driver,
    required this.myPosition,
    required this.isSpeaking,
  });

  String get _initial {
    final t = driver.username.trim();
    return t.isEmpty ? '?' : t[0].toUpperCase();
  }

  String _locationLabel() {
    final me = myPosition;
    if (me == null) return 'Online';
    final meters =
        Geolocator.distanceBetween(me.lat, me.lng, driver.lat, driver.lng);
    if (meters < 1000) return 'Vicino (${meters.round()}m)';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(driver.accentColor);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColor.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isSpeaking ? AppColor.cyan : AppColor.line,
          width: isSpeaking ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.4),
            ),
            child: Text(_initial,
                style: AppType.text(
                    fontWeight: FontWeight.w800, fontSize: 14, color: color)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(driver.username.isEmpty ? 'Driver' : driver.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.text(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColor.ink)),
                Text('Online',
                    style: AppType.text(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColor.cyan)),
                Text(_locationLabel(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.text(
                        fontSize: 11, color: AppColor.inkMuted)),
              ],
            ),
          ),
          Icon(
            isSpeaking ? Icons.mic_rounded : Icons.mic_none_rounded,
            size: 14,
            color: isSpeaking ? AppColor.cyan : AppColor.inkFaint,
          ),
        ],
      ),
    );
  }
}

/// Pulsante push-to-talk: tenuto premuto registra e invia sul canale voce
/// reale (VoiceChannelController), rilasciato ferma e spedisce il clip —
/// vedi voice_channel_provider.dart per l'invio/ricezione via broadcast
/// Realtime sullo stesso topic "drivers-live" delle posizioni.
class _PttButton extends ConsumerStatefulWidget {
  const _PttButton();

  @override
  ConsumerState<_PttButton> createState() => _PttButtonState();
}

class _PttButtonState extends ConsumerState<_PttButton> {
  bool _pressed = false;

  void _setPressed(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    final voice = ref.watch(voiceChannelControllerProvider);
    final notifier = ref.read(voiceChannelControllerProvider.notifier);
    final speaking = voice.speaking;

    final label = voice.recording
        ? 'REGISTRAZIONE...'
        : voice.sending
            ? 'INVIO...'
            : speaking != null
                ? '${speaking.username.isEmpty ? "Qualcuno" : speaking.username} sta parlando'
                : 'PREMI PER PARLARE';
    final active = _pressed || voice.recording;

    return GestureDetector(
      onTapDown: voice.sending ? null : (_) {
        _setPressed(true);
        notifier.startTalking();
      },
      onTapUp: (_) {
        _setPressed(false);
        notifier.stopTalking();
      },
      onTapCancel: () {
        _setPressed(false);
        notifier.stopTalking();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: active ? 1.08 : 1.0,
            duration: AppMotion.fast,
            child: Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColor.cyan,
                boxShadow:
                    AppGlow.soft(AppColor.cyan, opacity: active ? 0.55 : 0.35),
              ),
              child: Icon(
                voice.recording ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: AppColor.void_,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(label.toUpperCase(),
              style: AppType.label.copyWith(color: AppColor.cyan)),
        ],
      ),
    );
  }
}

Color _hexToColor(String hex) {
  final normalized = hex.replaceFirst('#', '');
  final value = int.tryParse(normalized, radix: 16) ?? 0x35E0FF;
  return Color(0xFF000000 | value);
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _StatCell(
      {required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF1D2740))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppType.text(
                  fontSize: 14, color: AppColor.inkMuted)),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              text: value,
              style: AppType.text(
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                  color: AppColor.ink),
              children: [
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: AppType.text(
                        fontSize: 15, color: AppColor.cyan),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xEB0D1222),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: AppColor.cyan, size: 22),
        ),
      ),
    );
  }
}
