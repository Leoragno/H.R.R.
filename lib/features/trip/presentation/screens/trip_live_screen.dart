import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../../core/theme/heat_shapes.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../../radar/domain/entities/radar_bounds.dart';
import '../../../radar/domain/entities/radar_event.dart';
import '../../../radar/presentation/providers/radar_provider.dart';
import '../../../radar/presentation/providers/radar_proximity_provider.dart';
import '../../../radar/presentation/widgets/radar_icons.dart';
import '../../../rival/presentation/providers/active_mascot_provider.dart';
import '../providers/live_map_provider.dart';
import '../providers/trip_live_provider.dart';
import '../providers/voice_channel_provider.dart';
import '../utils/route_smoothing.dart';
import '../widgets/speedometer_gauge.dart';

enum _LiveView { map, speedometer }

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

/// Guida in corso (handoff HEAT, schermata 7): tachimetro ⇄ mappa, barra
/// "Auto amiche" con push-to-talk, avvisi velox/pattuglia, CTA TERMINA
/// VIAGGIO. La logica di tracking resta in TripLiveController.
///
/// Sicurezza (DESIGN.md): numeri grandi e leggibili a colpo d'occhio,
/// nessuna interazione che richieda di tenere premuto, il PTT è a tocco.
class TripLiveScreen extends ConsumerStatefulWidget {
  const TripLiveScreen({super.key});

  @override
  ConsumerState<TripLiveScreen> createState() => _TripLiveScreenState();
}

class _TripLiveScreenState extends ConsumerState<TripLiveScreen> {
  _LiveView _view = _LiveView.speedometer;
  RadarEvent? _activeAlert;
  Timer? _alertHideTimer;

  // Pannello canali "Auto amiche" aperto sopra la CTA (con scrim). Il
  // canale voce vive in VoiceChannelController, agganciato dalla barra.
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

  // RadarProximityController emette un "impulso" ogni volta che si è
  // vicini a un nuovo evento non in cooldown: qui decidiamo per quanto
  // resta visibile l'avviso.
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
        backgroundColor: AppColor.surfaceHigh,
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

  /// Il risparmio energetico può sospendere il GPS in background — vedi
  /// TripLiveController._checkBatterySaver. Mostrato una volta per
  /// transizione a true.
  Future<void> _showBatterySaverWarning() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColor.surfaceHigh,
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
            child: Text('Apri impostazioni',
                style: TextStyle(color: AppColor.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tripLiveControllerProvider);
    final tracking = state.status == TripLiveStatus.tracking;
    final finishing = state.status == TripLiveStatus.finishing;
    final a = AppColor.accent;

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

    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColor.void_,
      body: Stack(
        children: [
          // Alone d'accento dietro al tachimetro.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -.36),
                    radius: .9,
                    colors: [a.withValues(alpha: .15), a.withValues(alpha: 0)],
                    stops: const [0, .7],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                  child: Row(
                    children: [
                      _SlantIconButton(
                        icon: Icons.close_rounded,
                        onTap: finishing ? null : _discard,
                      ),
                      const Spacer(),
                      _LiveBadge(
                        label: finishing
                            ? 'SALVO'
                            : tracking
                                ? 'LIVE'
                                : 'AVVIO…',
                      ),
                      const Spacer(),
                      _SlantIconButton(
                        icon: _view == _LiveView.map
                            ? Icons.speed_rounded
                            : Icons.map_rounded,
                        onTap: finishing
                            ? null
                            : () => setState(() {
                                  _view = _view == _LiveView.map
                                      ? _LiveView.speedometer
                                      : _LiveView.map;
                                }),
                      ),
                    ],
                  ),
                ),
                // Solo Web/PWA: senza schermo acceso il browser sospende la
                // geolocalizzazione, vedi TrackingWakelock.
                if (kIsWeb && tracking)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: _KeepScreenOnNotice(),
                  ),
                if (state.status == TripLiveStatus.error)
                  Expanded(child: _ErrorView(message: state.errorMessage))
                else if (finishing)
                  // Smontata subito la mappa (platform view MapLibre) invece
                  // di lasciarla fino al pushReplacement, che la smontava a
                  // metà transizione col flash nero.
                  const Expanded(child: _FinishingView())
                else
                  Expanded(
                    child: _view == _LiveView.speedometer
                        ? _SpeedView(state: state)
                        : _MapView(state: state),
                  ),
                if (tracking)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: _AutoAmicheBar(
                      speedKmh: state.currentSpeedKmh,
                      onOpenChannels: () =>
                          setState(() => _amicheExpanded = true),
                    ),
                  ),
                if (state.status != TripLiveStatus.error && !finishing)
                  Padding(
                    padding: EdgeInsets.fromLTRB(14, 0, 14, 18 + bottom),
                    child: HeatButton(
                      label: 'TERMINA VIAGGIO',
                      icon: Icons.flag_rounded,
                      height: 62,
                      fontSize: 25,
                      // Il glow della schermata è del tachimetro.
                      glow: false,
                      onPressed: tracking ? _finish : null,
                    ),
                  ),
              ],
            ),
          ),
          if (_activeAlert != null)
            Positioned(
              left: 14,
              right: 14,
              top: MediaQuery.paddingOf(context).top + 66,
              child: _RadarAlertBanner(event: _activeAlert!),
            ),
          if (tracking && _amicheExpanded) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _amicheExpanded = false),
                child: const ColoredBox(color: Color(0x8C000000)),
              ),
            ).animate().fadeIn(duration: 180.ms),
            Positioned(
              left: 14,
              right: 14,
              bottom: 30 + bottom,
              child: _ChannelPicker(
                onClose: () => setState(() => _amicheExpanded = false),
              ),
            ).animate().fadeIn(duration: 220.ms).slideY(begin: .12, end: 0),
          ],
        ],
      ),
    );
  }
}

/// Bottone quadrato a parallelogramma della barra superiore.
class _SlantIconButton extends StatelessWidget {
  const _SlantIconButton({required this.icon, required this.onTap, this.color});
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? .45 : 1,
      child: HeatPressable(
        onTap: onTap,
        child: Container(
          width: 50,
          height: 50,
          decoration: const ShapeDecoration(
            color: AppColor.surface,
            shape: SlantBorder.all(10,
                side: BorderSide(color: AppColor.line)),
          ),
          child: Icon(icon, color: color ?? AppColor.ink, size: 24),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: ShapeDecoration(
        color: AppColor.danger.withValues(alpha: .14),
        shape: const SlantBorder.all(8,
            side: BorderSide(color: AppColor.danger)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(width: 8, height: 8, color: AppColor.danger),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fade(begin: 1, end: .25, duration: 600.ms),
          const SizedBox(width: 8),
          Text(label,
              style: AppType.display(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  letterSpacing: 2,
                  color: AppColor.danger)),
        ],
      ),
    );
  }
}

/// Promemoria per chi guida da browser: il GPS si ferma se lo schermo si
/// spegne. Grigio, nessun accento.
class _KeepScreenOnNotice extends StatelessWidget {
  const _KeepScreenOnNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColor.deep,
        border: Border.all(color: AppColor.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.smartphone_rounded,
              size: 18, color: AppColor.inkFaint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'mantieni lo schermo acceso per continuare il tracciamento GPS',
              style: AppType.caption.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.message});
  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gps_off_rounded,
                size: 48, color: AppColor.danger.withValues(alpha: .8)),
            const SizedBox(height: 12),
            Text(
              message ?? 'Errore GPS',
              style: AppType.body.copyWith(color: AppColor.inkMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            HeatButton(
              label: 'RIPROVA',
              height: 52,
              fontSize: 20,
              icon: Icons.refresh_rounded,
              onPressed: () =>
                  ref.read(tripLiveControllerProvider.notifier).startTrip(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avviso di prossimità Velox/Pattuglia: banda piena a parallelogramma,
/// gialla per i dati ufficiali, ciano per le segnalazioni della community.
class _RadarAlertBanner extends StatelessWidget {
  final RadarEvent event;
  const _RadarAlertBanner({required this.event});

  @override
  Widget build(BuildContext context) {
    final isVelox = event.category == RadarCategory.velox;
    final isCommunity = event.source == RadarSource.community;
    final bg = isCommunity ? AppColor.info : AppColor.gold;
    final label = switch ((isVelox, isCommunity)) {
      (true, true) => 'velox segnalato dalla community nelle vicinanze',
      (true, false) => 'autovelox nelle vicinanze',
      (false, true) => 'pattuglia segnalata dalla community nelle vicinanze',
      (false, false) => 'pattuglia nelle vicinanze',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: ShapeDecoration(color: bg, shape: const SlantBorder.all(12)),
      child: Row(
        children: [
          Icon(
            isVelox ? Icons.videocam_rounded : Icons.local_police_rounded,
            color: AppColor.onAccent,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: AppType.display(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                height: 1.1,
                color: AppColor.onAccent,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).scaleXY(begin: .94, end: 1);
  }
}

/// Mostrata mentre finishTrip() salva il viaggio: emote della mascotte e
/// barra di caricamento inclinata.
class _FinishingView extends ConsumerWidget {
  const _FinishingView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mascot = ref.watch(activeMascotProvider);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: Image.asset(
              'assets/emotes/${mascot.id}_emote_b.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOut,
              builder: (_, v, __) => SkewBar(value: v, height: 4),
            ),
          ),
          const SizedBox(height: 16),
          Text('salvataggio del viaggio…',
              style: AppType.body.copyWith(color: AppColor.inkMuted)),
        ],
      ),
    );
  }
}

class _SpeedView extends StatelessWidget {
  final TripLiveState state;
  const _SpeedView({required this.state});

  @override
  Widget build(BuildContext context) {
    final cells = [
      ('DISTANZA', state.distanceKm.toStringAsFixed(1), 'km'),
      ('TEMPO', _formatDuration(state.elapsed), ''),
      ('VEL. MEDIA', state.avgSpeedKmh.toStringAsFixed(0), 'km/h'),
      ('VEL. MASSIMA', state.maxSpeedKmh.toStringAsFixed(0), 'km/h'),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: SpeedometerGauge(speed: state.currentSpeedKmh),
          ).animate().fadeIn(),
          const SizedBox(height: 14),
          // Due righe di due: ogni cella prende l'altezza che le serve (mai
          // un childAspectRatio fisso, che va in overflow con font grandi).
          for (var r = 0; r < 2; r++) ...[
            if (r > 0) const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < 2; c++) ...[
                  if (c > 0) const SizedBox(width: 5),
                  Expanded(
                    child: _StatCell(
                      label: cells[r * 2 + c].$1,
                      value: cells[r * 2 + c].$2,
                      unit: cells[r * 2 + c].$3,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const ShapeDecoration(
        color: AppColor.surface,
        shape: ChamferBorder(cut: 10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppType.label.copyWith(fontSize: 12, letterSpacing: 1.6)),
          Text.rich(
            TextSpan(
              text: value,
              children: [
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: AppType.display(
                        fontSize: 14, italic: false, color: AppColor.inkMuted),
                  ),
              ],
            ),
            maxLines: 1,
            style: AppType.display(
              fontWeight: FontWeight.w900,
              fontSize: 30,
              height: 1.05,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
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
          lineColor: _hex(AppColor.accent),
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
        circleColor: _hex(AppColor.accent),
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

    final category = await _showReportSheet(context);
    if (category == null) return;
    await ref.read(radarActionsControllerProvider.notifier).submitReport(
          category: category,
          lat: coords.latitude,
          lon: coords.longitude,
        );
  }

  /// Bottone "segnala qui": stessa segnalazione del long-press, sulla
  /// posizione live corrente.
  Future<void> _reportHere() async {
    final points = widget.state.routePoints;
    if (points.isEmpty) return;
    final last = points.last;
    await _onMapLongPress(
        const math.Point(0, 0), LatLng(last.lat, last.lng));
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
      return Center(
        child: CircularProgressIndicator(color: AppColor.accent),
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
          left: 12,
          top: 12,
          child: _MapStatsChip(
            km: widget.state.distanceKm,
            elapsed: widget.state.elapsed,
          ),
        ),
        Positioned(
          right: 12,
          top: 12,
          child: Column(
            children: [
              _SlantIconButton(
                  icon: Icons.my_location_rounded, onTap: _recenterCamera),
              if (ref.watch(radarModeControllerProvider)) ...[
                const SizedBox(height: 6),
                _SlantIconButton(
                  icon: Icons.campaign_rounded,
                  color: AppColor.gold,
                  onTap: _reportHere,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Km e tempo in alto a sinistra sulla mappa.
class _MapStatsChip extends StatelessWidget {
  const _MapStatsChip({required this.km, required this.elapsed});
  final double km;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    Widget cell(String v, String l) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(v,
                style: AppType.display(
                    fontWeight: FontWeight.w900, fontSize: 22, height: 1)),
            Text(l,
                style: AppType.caption
                    .copyWith(fontSize: 10, letterSpacing: 1)),
          ],
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 18, 6),
      decoration: const ShapeDecoration(
        color: Color(0xE60B0912),
        shape: SlantBorder(left: 0, right: 10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          cell(km.toStringAsFixed(1), 'KM'),
          const SizedBox(width: 14),
          cell(_formatDuration(elapsed), 'TEMPO'),
        ],
      ),
    );
  }
}


/// Foglio "SEGNALA QUI" (velox / pattuglia), stesso aspetto del prototipo:
/// pannello scuro con bordo superiore oro.
Future<RadarCategory?> _showReportSheet(BuildContext context) {
  return showModalBottomSheet<RadarCategory>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8C000000),
    builder: (ctx) => SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 30),
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColor.surface,
          border: Border(
            top: BorderSide(color: AppColor.gold, width: 2),
            left: BorderSide(color: AppColor.line),
            right: BorderSide(color: AppColor.line),
            bottom: BorderSide(color: AppColor.line),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SEGNALA QUI',
                style: AppType.display(
                    fontWeight: FontWeight.w900, fontSize: 24)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ReportOption(
                    icon: Icons.videocam_rounded,
                    color: AppColor.gold,
                    label: 'VELOX',
                    onTap: () => Navigator.of(ctx).pop(RadarCategory.velox),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ReportOption(
                    icon: Icons.shield_rounded,
                    color: AppColor.info,
                    label: 'PATTUGLIA',
                    onTap: () =>
                        Navigator.of(ctx).pop(RadarCategory.pattuglia),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReportOption extends StatelessWidget {
  const _ReportOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HeatPressable(
      onTap: onTap,
      child: Container(
        height: 60,
        color: AppColor.surfaceHigh,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 10),
            Text(label,
                style: AppType.display(fontSize: 18, italic: false)),
          ],
        ),
      ),
    );
  }
}

/// Barra "Auto amiche": velocità a sinistra, stato del canale al centro
/// (tocco = scelta canale), microfono push-to-talk a destra (un tocco per
/// parlare, un secondo per inviare: chi guida non può tenere premuto).
class _AutoAmicheBar extends ConsumerWidget {
  final double speedKmh;
  final VoidCallback onOpenChannels;
  const _AutoAmicheBar({required this.speedKmh, required this.onOpenChannels});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineCount = ref.watch(liveMapControllerProvider).length;
    // Tiene vivo il canale voce (provider autoDispose) anche a pannello
    // chiuso: un "push" ricevuto deve comunque riprodursi.
    final voice = ref.watch(voiceChannelControllerProvider);
    final notifier = ref.read(voiceChannelControllerProvider.notifier);

    final String status;
    if (voice.recording) {
      status = 'in onda · tocca per inviare';
    } else if (voice.sending) {
      status = 'invio…';
    } else if (voice.speaking != null) {
      final name = voice.speaking!.username;
      status = '${name.isEmpty ? 'qualcuno' : name} parla';
    } else {
      status = 'canale ${voice.channel} · $onlineCount online';
    }
    final highlight = voice.recording || voice.speaking != null;
    // Il canale non si cambia a metà registrazione.
    final canOpen = !voice.recording;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: const ShapeDecoration(
        color: AppColor.surface,
        shape: ChamferBorder(cut: 14, side: BorderSide(color: AppColor.line)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('VELOCITÀ',
                  style:
                      AppType.label.copyWith(fontSize: 11, letterSpacing: 1.6)),
              Text.rich(
                TextSpan(
                  text: speedKmh.toStringAsFixed(0),
                  children: [
                    TextSpan(
                      text: ' km/h',
                      style: AppType.display(
                          fontSize: 13, italic: false, color: AppColor.info),
                    ),
                  ],
                ),
                style: AppType.display(
                    fontWeight: FontWeight.w900, fontSize: 32, height: 1),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: canOpen ? onOpenChannels : null,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('AUTO AMICHE',
                          style: AppType.display(
                              fontSize: 15,
                              italic: false,
                              letterSpacing: 1.4)),
                      if (canOpen)
                        const Icon(Icons.keyboard_arrow_up_rounded,
                            color: AppColor.inkMuted, size: 18),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: AppType.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: highlight ? AppColor.info : AppColor.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _MicButton(
            recording: voice.recording,
            busy: voice.sending,
            onTap: () {
              if (voice.sending) return;
              // Chi guida non guarda lo schermo: la vibrazione conferma
              // l'avvio della registrazione / l'invio.
              HapticFeedback.mediumImpact();
              notifier.toggleTalking();
            },
          ),
        ],
      ),
    );
  }
}

/// Push-to-talk a tocco singolo (vedi VoiceChannelController.toggleTalking).
/// Nessun glow: lo stato attivo si legge dal riempimento.
class _MicButton extends StatelessWidget {
  final bool recording;
  final bool busy;
  final VoidCallback onTap;
  const _MicButton({
    required this.recording,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = recording
        ? AppColor.onAccent
        : busy
            ? AppColor.inkFaint
            : AppColor.ink;
    return Semantics(
      button: true,
      label: recording ? 'Invia messaggio vocale' : 'Parla',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: recording ? AppColor.danger : AppColor.surfaceHigh,
            border: Border.all(
                color: recording ? AppColor.danger : AppColor.lineMuted),
          ),
          child: Icon(
            recording ? Icons.mic_rounded : Icons.mic_none_rounded,
            color: iconColor,
            size: 26,
          ),
        ),
      ),
    );
  }
}

/// Pannello "Auto amiche": serve solo a scegliere il canale. Un tocco su un
/// numero lo seleziona e chiude subito il pannello.
class _ChannelPicker extends ConsumerWidget {
  final VoidCallback onClose;
  const _ChannelPicker({required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current =
        ref.watch(voiceChannelControllerProvider.select((s) => s.channel));
    final notifier = ref.read(voiceChannelControllerProvider.notifier);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: AppColor.surface,
        border: Border(
          top: BorderSide(color: AppColor.info, width: 2),
          left: BorderSide(color: AppColor.line),
          right: BorderSide(color: AppColor.line),
          bottom: BorderSide(color: AppColor.line),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              height: 16,
              width: double.infinity,
              child: Center(
                child: Transform(
                  transform: Matrix4.skewX(-.5),
                  child: Container(width: 40, height: 4, color: AppColor.line),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('AUTO AMICHE',
                  style: AppType.display(
                      fontWeight: FontWeight.w900, fontSize: 22)),
              const SizedBox(width: 6),
              Text('· scegli il canale',
                  style: AppType.caption.copyWith(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              const perRow = 4;
              const gap = 6.0;
              final w = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var n = 1; n <= kVoiceChannelCount; n++)
                    SizedBox(
                      width: w,
                      child: _ChannelChip(
                        number: n,
                        selected: n == current,
                        onTap: () {
                          notifier.selectChannel(n);
                          onClose();
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  final int number;
  final bool selected;
  final VoidCallback onTap;
  const _ChannelChip({
    required this.number,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = selected ? AppColor.info : AppColor.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Canale $number',
      child: HeatPressable(
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: AppColor.deep,
            shape: SlantBorder.all(8,
                side: BorderSide(
                    color: selected ? AppColor.info : AppColor.line)),
          ),
          child: Text('$number',
              style: AppType.display(
                  fontWeight: FontWeight.w900, fontSize: 22, color: c)),
        ),
      ),
    );
  }
}
