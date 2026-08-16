import 'dart:async';

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
import '../../../../core/widgets/neon_cta_button.dart';
import '../../../../core/widgets/recenter_button.dart';
import '../../../radar/domain/entities/radar_event.dart';
import '../../../radar/presentation/providers/radar_proximity_provider.dart';
import '../providers/live_map_provider.dart';
import '../providers/trip_live_provider.dart';
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
                else
                  Expanded(
                    child: _view == _LiveView.speedometer
                        ? _SpeedView(
                            state: state, formatDuration: _formatDuration)
                        : _MapView(
                            state: state, formatDuration: _formatDuration),
                  ),
                if (state.status != TripLiveStatus.error)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: NeonCtaButton(
                      label: 'Termina viaggio',
                      icon: Icons.flag_rounded,
                      minHeight: 60,
                      onPressed: tracking ? _finish : null,
                    ),
                  ),
              ],
            ),
          ),
          if (_activeAlert != null) _RadarAlertBanner(event: _activeAlert!),
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
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 22,
            mainAxisSpacing: 4,
            childAspectRatio: 3.6,
            children: [
              _StatCell(
                  label: 'Distanza',
                  value: state.distanceKm.toStringAsFixed(1),
                  unit: 'km'),
              _StatCell(
                  label: 'Tempo',
                  value: formatDuration(state.elapsed),
                  unit: ''),
              _StatCell(
                  label: 'Vel. media',
                  value: state.avgSpeedKmh.toStringAsFixed(0),
                  unit: 'km/h'),
              _StatCell(
                  label: 'Vel. massima',
                  value: state.maxSpeedKmh.toStringAsFixed(0),
                  unit: 'km/h'),
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
  final String Function(Duration) formatDuration;
  const _MapView({required this.state, required this.formatDuration});

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
  // posizione fa update invece di add/remove ad ogni fix.
  final Map<String, Line> _liveLines = {};
  final Map<String, Symbol> _liveSymbols = {};

  @override
  void initState() {
    super.initState();
    _resolveInitialCamera();
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

  Future<void> _onStyleLoaded() async {
    await _updateRouteLine();
    await _updateMeMarker();
    await _syncLiveDrivers(ref.read(liveMapControllerProvider));
  }

  /// Allinea marker+percorso degli altri driver allo stato del canale
  /// realtime condiviso: aggiunge chi ha appena iniziato a guidare,
  /// aggiorna posizione/percorso di chi è già sulla mappa, rimuove chi ha
  /// smesso.
  Future<void> _syncLiveDrivers(Map<String, LiveDriver> drivers) async {
    final controller = _controller;
    if (controller == null) return;

    try {
      for (final profileId in _liveSymbols.keys.toList()) {
        if (!drivers.containsKey(profileId)) {
          await controller.removeSymbol(_liveSymbols.remove(profileId)!);
        }
      }
      for (final profileId in _liveLines.keys.toList()) {
        if (!drivers.containsKey(profileId)) {
          await controller.removeLine(_liveLines.remove(profileId)!);
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
          ),
        ),
        Positioned(
          right: 18,
          top: 18,
          child: RecenterButton(onTap: _recenterCamera),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 18,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xEB0D1222), Color(0xF5060810)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x2E7896FF)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        text: widget.state.currentSpeedKmh.toStringAsFixed(0),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('DISTANZA · DURATA',
                        style: AppType.text(
                            fontSize: 12,
                            letterSpacing: 1.4,
                            color: AppColor.inkMuted)),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.state.distanceKm.toStringAsFixed(1)} km · '
                      '${widget.formatDuration(widget.state.elapsed)}',
                      style: AppType.text(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppColor.ink),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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
