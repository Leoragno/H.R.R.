import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/events/mission_event.dart';
import '../../../../core/events/mission_event_bus.dart';
import '../../../../core/network/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/route_point.dart';
import '../../domain/entities/trip.dart';
import 'trip_provider.dart';

export '../../domain/entities/route_point.dart' show RoutePoint;

part 'trip_live_provider.g.dart';

enum TripLiveStatus { idle, tracking, finishing, error }

class TripLiveState {
  final TripLiveStatus status;
  final String? tripId;
  final Duration elapsed;
  final double distanceKm;
  final double currentSpeedKmh;
  final double maxSpeedKmh;
  final String? errorMessage;
  final List<RoutePoint> routePoints;

  const TripLiveState({
    this.status = TripLiveStatus.idle,
    this.tripId,
    this.elapsed = Duration.zero,
    this.distanceKm = 0,
    this.currentSpeedKmh = 0,
    this.maxSpeedKmh = 0,
    this.errorMessage,
    this.routePoints = const [],
  });

  double get avgSpeedKmh =>
      elapsed.inSeconds > 0 ? distanceKm / (elapsed.inSeconds / 3600) : 0;

  TripLiveState copyWith({
    TripLiveStatus? status,
    String? tripId,
    Duration? elapsed,
    double? distanceKm,
    double? currentSpeedKmh,
    double? maxSpeedKmh,
    String? errorMessage,
    List<RoutePoint>? routePoints,
  }) {
    return TripLiveState(
      status: status ?? this.status,
      tripId: tripId ?? this.tripId,
      elapsed: elapsed ?? this.elapsed,
      distanceKm: distanceKm ?? this.distanceKm,
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      errorMessage: errorMessage,
      routePoints: routePoints ?? this.routePoints,
    );
  }
}

/// Campione di telemetria (velocità/quota nel tempo), usato solo per i
/// grafici "Speed/Elevation Over Time" della schermata di riepilogo — come
/// per [RoutePoint], non è persistito lato server.
class TelemetrySample {
  final int elapsedSeconds;
  final double speedKmh;
  final double? elevationM;
  const TelemetrySample(this.elapsedSeconds, this.speedKmh, this.elevationM);
}

/// Statistiche derivate da GPS + sensori inerziali reali (accelerometro e
/// giroscopio, via `sensors_plus`) durante il viaggio. Calcolate come stato
/// aggregato O(1) mentre il viaggio è in corso (mai bufferizzando i campioni
/// grezzi a ~60Hz), non persistite lato server — stesso trattamento
/// "effimero" già riservato a [TelemetrySample] e a `routePoints`.
class TripMotionStats {
  final double elevationGainM;
  final double? maxAltitudeM;
  final double? maxAccelerationMs2;
  final double? maxDecelerationMs2;
  final double? zeroToHundredSeconds;
  final Duration stoppedTime;
  final int totalStops;
  final double peakGForce;
  final int brakingEvents;
  final int turnsLeft;
  final int turnsRight;
  final double? maxCorneringSpeedKmh;

  const TripMotionStats({
    this.elevationGainM = 0,
    this.maxAltitudeM,
    this.maxAccelerationMs2,
    this.maxDecelerationMs2,
    this.zeroToHundredSeconds,
    this.stoppedTime = Duration.zero,
    this.totalStops = 0,
    this.peakGForce = 0,
    this.brakingEvents = 0,
    this.turnsLeft = 0,
    this.turnsRight = 0,
    this.maxCorneringSpeedKmh,
  });
}

/// Snapshot del viaggio appena concluso: il controller resetta il proprio
/// stato subito dopo aver finito la corsa, quindi TripSummaryScreen non
/// può rileggerlo da TripLiveController (già tornato a idle).
class TripSummary {
  final Trip trip;
  final List<RoutePoint> routePoints;
  final List<TelemetrySample> samples;
  final TripMotionStats motionStats;
  const TripSummary({
    required this.trip,
    required this.routePoints,
    this.samples = const [],
    this.motionStats = const TripMotionStats(),
  });
}

/// Campione di velocità usato solo per calcolare la derivata (accelerazione)
/// su una finestra di 3 fix — mai esposto fuori dal controller.
class _SpeedFix {
  final DateTime time;
  final double speedMs;
  const _SpeedFix(this.time, this.speedMs);
}

/// Tiene il TripSummary appena prodotto da finishTrip() finché
/// TripSummaryScreen non lo consuma. Prima veniva passato via `extra` di
/// GoRouter, ma `extra` non sopravvive a un refresh del router — e
/// completare un viaggio aggiorna `profiles` via realtime (XP/REP),
/// facendo scattare `refreshListenable` sul router, che ricostruisce la
/// route con `extra` nullo e mandava in crash TripSummaryScreen (o, prima
/// del fix del router, resettava la navigazione allo splash). Uno stato
/// Riverpod è immune a questo perché non passa per il router — ma deve
/// essere keepAlive: fra `set()` in finishTrip() e il primo `ref.watch`
/// di TripSummaryScreen non c'è nessun listener attivo, e un provider
/// autoDispose (default) viene smaltito in quella finestra, tornando a
/// null prima ancora che la schermata lo legga (l'utente vede la
/// schermata di riepilogo saltare dritta alla Home, come se il router
/// si fosse resettato di nuovo — stesso sintomo, causa diversa).
@Riverpod(keepAlive: true)
class LastTripSummaryController extends _$LastTripSummaryController {
  @override
  TripSummary? build() => null;

  void set(TripSummary summary) => state = summary;
}

// Soglie usate per derivare le statistiche di guida da GPS + sensori
// inerziali. Vedi commenti puntuali più sotto per la giustificazione di
// ciascuna — sono tutte euristiche su dati reali (mai valori inventati).
const _kStationarySpeedKmh = 3.0;
const _kStopMinDuration = Duration(seconds: 3);
const _kZeroToHundredArmSpeedKmh = 5.0;
const _kZeroToHundredTargetKmh = 100.0;
const _kZeroToHundredMaxAttemptSeconds = 60.0;
const _kAccelMinDt = Duration(milliseconds: 500);
const _kAccelMaxDt = Duration(seconds: 5);
const _kBrakingThresholdMs2 = 0.35 * 9.81;
const _kBrakingMinSustain = Duration(milliseconds: 150);
const _kBrakingCooldown = Duration(seconds: 2);
const _kTurnThresholdDeg = 25.0;
const _kTurnWindowTimeout = Duration(seconds: 4);
const _kTurnCooldown = Duration(seconds: 3);
const _kTurnGyroCorroborationRadS = 0.15;

// Filtri qualità/plausibilità sui fix GPS grezzi — senza questi, un
// singolo fix rumoroso (tunnel, garage, palazzi alti, riaggancio GPS)
// corrompe percorso/distanza/velocità in modo permanente e visibile.
//
// Raggio di incertezza oltre il quale un fix è troppo impreciso per
// essere usato in qualunque calcolo: GPS_high in condizioni normali sta
// sotto i 10-15m, valori più alti indicano un fix di scarsa qualità.
const _kMinGpsAccuracyM = 25.0;
// Sotto questa soglia uno spostamento tra due fix è rumore GPS da fermo,
// non movimento reale — deve stare SOPRA l'errore tipico di un fix
// buono (5-15m), non allo stesso livello del `distanceFilter` nativo
// (3m, vedi _liveLocationSettings), che scarterebbe solo i fix
// pressoché identici e lascerebbe passare comunque il rumore.
const _kJitterDistanceM = 8.0;
// Velocità implicita (spazio/tempo tra due fix consecutivi) oltre la
// quale lo spostamento non può essere un'auto in marcia reale: un
// "teletrasporto" da riaggancio GPS va scartato, non sommato alla
// distanza percorsa né disegnato come tratto di percorso.
const _kMaxPlausibleSpeedMs = 83.3; // 300 km/h
const _kMaxPlausibleSpeedKmh = 300.0;

const _kActiveTripPrefsKey = 'hrr_active_trip_v1';

/// Snapshot minimo del viaggio in corso, salvato su disco come rete di
/// sicurezza contro il kill del processo (memoria, riavvio, force-stop —
/// i casi che il foreground service Android/permesso "Always" iOS non
/// coprono). Senza questo, un viaggio interrotto a metà resta bloccato per
/// sempre con status 'active' lato server e non compare mai in cronologia
/// (che mostra solo status='completed', vedi recentTrips()).
class PersistedTripState {
  final String tripId;
  final DateTime startedAt;
  final double distanceKm;
  final double maxSpeedKmh;
  final List<RoutePoint> routePoints;

  const PersistedTripState({
    required this.tripId,
    required this.startedAt,
    required this.distanceKm,
    required this.maxSpeedKmh,
    required this.routePoints,
  });

  Map<String, dynamic> toJson() => {
        'tripId': tripId,
        'startedAt': startedAt.toIso8601String(),
        'distanceKm': distanceKm,
        'maxSpeedKmh': maxSpeedKmh,
        'route': [for (final p in routePoints) [p.lat, p.lng]],
      };

  factory PersistedTripState.fromJson(Map<String, dynamic> json) {
    return PersistedTripState(
      tripId: json['tripId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      distanceKm: (json['distanceKm'] as num).toDouble(),
      maxSpeedKmh: (json['maxSpeedKmh'] as num).toDouble(),
      routePoints: [
        for (final p in (json['route'] as List))
          RoutePoint((p[0] as num).toDouble(), (p[1] as num).toDouble())
      ],
    );
  }
}

Future<PersistedTripState?> _readPersistedTrip(SharedPreferences prefs) async {
  final raw = prefs.getString(_kActiveTripPrefsKey);
  if (raw == null) return null;
  try {
    return PersistedTripState.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    // Stato corrotto/da una versione precedente incompatibile: meglio
    // scartarlo che bloccare la Home dietro un errore di parsing.
    await prefs.remove(_kActiveTripPrefsKey);
    return null;
  }
}

/// Letto una volta all'avvio (Home): se il processo è stato ucciso mentre
/// una guida era in corso, espone lo stato salvato così la UI può offrire
/// di riprenderla o chiuderla, invece di lasciarla bloccata per sempre.
/// Verifica anche lato server che il viaggio sia ancora 'active' — se nel
/// frattempo è stato chiuso da un altro device, non riproponiamo nulla.
@riverpod
Future<PersistedTripState?> pendingTripRecovery(PendingTripRecoveryRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final saved = await _readPersistedTrip(prefs);
  if (saved == null) return null;

  try {
    final trip = await ref.read(tripRepositoryProvider).tripById(saved.tripId);
    if (trip.status != TripStatus.active) {
      await prefs.remove(_kActiveTripPrefsKey);
      return null;
    }
  } catch (_) {
    // Rete non disponibile: non scartiamo lo stato locale, ritentiamo la
    // verifica al prossimo avvio piuttosto che perdere il recupero per un
    // errore temporaneo.
  }
  return saved;
}

@riverpod
class TripLiveController extends _$TripLiveController {
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<UserAccelerometerEvent>? _userAccelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  Timer? _ticker;
  Position? _lastPosition;
  // Orario del fix accettato come _lastPosition (non del fix corrente in
  // arrivo) — usato per calcolare la velocità implicita tra due fix e
  // scartare i "teletrasporti" fisicamente impossibili, vedi _onPosition.
  DateTime? _lastPositionAt;
  double _interpolatedKm = 0;

  // --- Mappa live della crew: vedi _joinCrewLiveChannel/CrewLiveMapController ---
  RealtimeChannel? _crewChannel;
  String? _crewProfileId;
  String? _crewUsername;
  String? _crewAvatarUrl;
  String? _crewAccentColor;
  DateTime? _lastCrewBroadcastAt;
  final List<RoutePoint> _points = [];
  final List<TelemetrySample> _samples = [];
  DateTime? _startedAt;
  String? _tripId;
  SharedPreferences? _prefs;
  DateTime? _lastPersistedAt;

  // --- Stato aggregato per TripMotionStats (mai campioni grezzi bufferizzati) ---
  double _elevationGainM = 0;
  double? _lastElevationM;
  double? _maxAltitudeM;

  final List<_SpeedFix> _recentSpeedFixes = [];
  double? _maxAccelerationMs2;
  double? _maxDecelerationMs2;

  DateTime? _zeroToHundredStart;
  int _lowSpeedStreak = 0;
  double? _bestZeroToHundredSeconds;

  bool _isStationary = false;
  Duration _stoppedTime = Duration.zero;
  int _currentStopStreakSeconds = 0;
  bool _currentStopCounted = false;
  int _totalStops = 0;

  double _peakGForce = 0;
  DateTime? _brakeAboveThresholdSince;
  DateTime? _lastBrakingEventAt;
  int _brakingEvents = 0;

  double? _lastBearing;
  double _turnAccumDeg = 0;
  DateTime? _turnWindowStart;
  double _turnWindowMaxSpeedKmh = 0;
  double _turnWindowGyroMagSum = 0;
  int _turnWindowGyroSamples = 0;
  DateTime? _lastTurnAt;
  int _turnsLeft = 0;
  int _turnsRight = 0;
  double? _maxCorneringSpeedKmh;
  bool _gyroEverFired = false;

  @override
  TripLiveState build() {
    ref.onDispose(() {
      _positionSub?.cancel();
      _userAccelSub?.cancel();
      _gyroSub?.cancel();
      _ticker?.cancel();
      _leaveCrewLiveChannel();
    });
    return const TripLiveState();
  }

  Future<void> startTrip() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        status: TripLiveStatus.error,
        errorMessage: 'Permesso di localizzazione negato',
      );
      return;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      state = state.copyWith(
          status: TripLiveStatus.error, errorMessage: 'GPS disattivato');
      return;
    }

    // Su iOS il tracking in background richiede il permesso "Always", ma
    // Geolocator.requestPermission() sa mostrare solo il prompt "When In
    // Use": con permesso già concesso (non più "notDetermined") una seconda
    // chiamata a Geolocator ritorna subito lo stato corrente senza chiedere
    // nulla. Solo permission_handler attiva davvero il prompt di upgrade
    // nativo — qui, dopo aver già ottenuto "When In Use" sopra.
    if (!kIsWeb && Platform.isIOS) {
      await ph.Permission.locationAlways.request();
    }

    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return;

    final trip =
        await ref.read(tripRepositoryProvider).startTrip(driverId: userId);

    // Unico evento di dominio già realmente emesso end-to-end oggi: le
    // feature ancora placeholder (spotting/crew/friends/POI) non hanno
    // punti reali da cui pubblicare gli altri MissionEvent.
    ref.read(missionEventBusProvider).publish(TripStarted(profileId: userId));

    _tripId = trip.id;
    _startedAt = DateTime.now();
    _lastPosition = null;
    _lastPositionAt = null;
    _points.clear();
    _samples.clear();
    _resetMotionStats();

    state = TripLiveState(status: TripLiveStatus.tracking, tripId: trip.id);
    unawaited(_persistState());

    _beginTracking();
  }

  /// Ripristina una guida che risultava ancora 'active' lato server dopo un
  /// riavvio del processo (vedi [pendingTripRecoveryProvider]), riusando lo
  /// stesso tripId invece di aprirne uno nuovo, e senza ripubblicare
  /// TripStarted (già pubblicato al primo avvio di questo viaggio).
  Future<void> resumeTrip(PersistedTripState saved) async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        status: TripLiveStatus.error,
        errorMessage: 'Permesso di localizzazione negato',
      );
      return;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      state = state.copyWith(
          status: TripLiveStatus.error, errorMessage: 'GPS disattivato');
      return;
    }
    if (!kIsWeb && Platform.isIOS) {
      await ph.Permission.locationAlways.request();
    }

    _tripId = saved.tripId;
    _startedAt = saved.startedAt;
    _lastPosition = null;
    _lastPositionAt = null;
    _points
      ..clear()
      ..addAll(saved.routePoints);
    _samples.clear();
    _resetMotionStats();

    state = TripLiveState(
      status: TripLiveStatus.tracking,
      tripId: saved.tripId,
      elapsed: DateTime.now().difference(saved.startedAt),
      distanceKm: saved.distanceKm,
      maxSpeedKmh: saved.maxSpeedKmh,
      routePoints: List.unmodifiable(_points),
    );
    unawaited(_persistState());

    _beginTracking();
  }

  void _beginTracking() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = _startedAt;
      if (startedAt != null) {
        state = state.copyWith(elapsed: DateTime.now().difference(startedAt));
      }
      // Heartbeat a 1Hz per il tempo da fermo/soste: col GPS il
      // getPositionStream (distanceFilter: 5) smette praticamente di
      // consegnare fix quando il veicolo è fermo, quindi non possiamo
      // misurare una durata "da fermo" affidabile contando sui fix.
      if (_isStationary) {
        _stoppedTime += const Duration(seconds: 1);
        _currentStopStreakSeconds += 1;
        if (!_currentStopCounted &&
            _currentStopStreakSeconds >= _kStopMinDuration.inSeconds) {
          _totalStops += 1;
          _currentStopCounted = true;
        }
      } else if (state.currentSpeedKmh > 0) {
        // Fa avanzare il contachilometri ogni secondo stimando la distanza
        // dall'ultima velocità nota, invece di aspettare il prossimo fix GPS
        // (che arriva solo ogni pochi metri): _onPosition sottrae questa
        // stima e la sostituisce col delta reale al fix successivo, quindi
        // qui si accumula solo un errore temporaneo tra un fix e l'altro.
        final deltaKm = state.currentSpeedKmh / 3600;
        _interpolatedKm += deltaKm;
        state = state.copyWith(distanceKm: state.distanceKm + deltaKm);
      }
    });

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: _liveLocationSettings(),
    ).listen(_onPosition);

    unawaited(_joinCrewLiveChannel());

    // Accelerometro/giroscopio: sottoscrizioni indipendenti con onError
    // silenzioso — un sensore assente su un device/emulatore non deve far
    // fallire il tracciamento GPS, che resta la fonte primaria.
    _userAccelSub?.cancel();
    _userAccelSub = userAccelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_onUserAccel, onError: (_) {});

    _gyroSub?.cancel();
    _gyroSub = gyroscopeEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_onGyro, onError: (_) {});
  }

  Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Scrive lo stato minimo della guida in corso su disco — vedi
  /// [PersistedTripState]. Chiamata al via del tracking e poi throttled
  /// (ogni 5s) da [_onPosition], mai ad ogni singolo fix GPS.
  Future<void> _persistState() async {
    final tripId = _tripId;
    final startedAt = _startedAt;
    if (tripId == null || startedAt == null) return;
    await _ensurePrefs();
    final saved = PersistedTripState(
      tripId: tripId,
      startedAt: startedAt,
      distanceKm: state.distanceKm,
      maxSpeedKmh: state.maxSpeedKmh,
      routePoints: List.unmodifiable(_points),
    );
    await _prefs?.setString(_kActiveTripPrefsKey, jsonEncode(saved.toJson()));
  }

  Future<void> _clearPersisted() async {
    await _ensurePrefs();
    await _prefs?.remove(_kActiveTripPrefsKey);
  }

  /// Impostazioni GPS piattaforma-specifiche: su Android avvia il tracking
  /// come foreground service con notifica persistente (mantiene il
  /// tracking "in foreground" agli occhi del sistema a schermo bloccato o
  /// app in background, senza richiedere ACCESS_BACKGROUND_LOCATION); su
  /// iOS abilita gli aggiornamenti in background (richiede il permesso
  /// "Always", vedi sopra, + UIBackgroundModes=location in Info.plist).
  LocationSettings _liveLocationSettings() {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        // Basso apposta: qui serve solo scartare i fix del tutto identici
        // e lasciar passare il resto al ritmo di intervalDuration sotto —
        // la vera classificazione "è rumore o movimento reale" è fatta in
        // software su una soglia più realistica (_kJitterDistanceM, 8m),
        // vedi _onPosition. Un distanceFilter nativo più alto rallenterebbe
        // anche i fix a bassa velocità (parcheggio, coda), non solo il rumore.
        distanceFilter: 3,
        // Senza questo, geolocator_android applica un intervallo di
        // richiesta di 5000ms di default: ad alta velocità (autostrada,
        // pista) il veicolo percorre centinaia di metri tra un fix e
        // l'altro, facendo apparire il contachilometri lento/a scatti
        // rispetto a Google Maps, che aggiorna la posizione ~1 volta al
        // secondo. 1000ms è già al limite della frequenza nativa dei chip
        // GPS civili (1Hz), quindi non ha costo aggiuntivo in termini di
        // fix realmente disponibili.
        intervalDuration: const Duration(milliseconds: 1000),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'HRR sta registrando la tua guida',
          notificationText: 'Tocca per tornare all\'app',
          notificationChannelName: 'Guida in corso',
          setOngoing: true,
        ),
      );
    }
    if (!kIsWeb && Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
        accuracy: LocationAccuracy.high, distanceFilter: 3);
  }

  /// Pubblica la guida sul canale realtime privato della crew ("crew-live-
  /// <crewId>", vedi migration 0009 per l'autorizzazione RLS) così i
  /// compagni di crew vedono live posizione e percorso sulla mappa della
  /// sezione guida — [CrewLiveMapController] è il lato osservatore.
  /// Nessuna crew, nessun canale: fallisce silenziosamente, il tracking
  /// GPS locale del viaggio non dipende in alcun modo da questo.
  Future<void> _joinCrewLiveChannel() async {
    try {
      final profile = await ref.read(myProfileProvider.future);
      final crewId = profile?.crewId;
      // Il trip potrebbe essere già terminato mentre attendevamo il profilo.
      if (crewId == null || profile == null || _tripId == null) return;

      _crewProfileId = profile.id;
      _crewUsername = profile.username;
      _crewAvatarUrl = profile.avatarUrl;
      _crewAccentColor = profile.accentColor;

      final channel = ref.read(supabaseClientProvider).channel(
            'crew-live-$crewId',
            opts: const RealtimeChannelConfig(private: true),
          );
      _crewChannel = channel;
      channel.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          unawaited(channel.track({
            'profileId': profile.id,
            'username': profile.username,
            'avatarUrl': profile.avatarUrl,
            'accentColor': profile.accentColor,
          }));
        }
      });
    } catch (_) {
      // Best-effort: la mappa condivisa con la crew non deve mai bloccare
      // o interrompere il tracking GPS locale del viaggio.
    }
  }

  void _leaveCrewLiveChannel() {
    final channel = _crewChannel;
    _crewChannel = null;
    _crewProfileId = null;
    _crewUsername = null;
    _crewAvatarUrl = null;
    _crewAccentColor = null;
    _lastCrewBroadcastAt = null;
    if (channel != null) {
      unawaited(channel.untrack());
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
  }

  void _resetMotionStats() {
    _elevationGainM = 0;
    _lastElevationM = null;
    _maxAltitudeM = null;
    _recentSpeedFixes.clear();
    _maxAccelerationMs2 = null;
    _maxDecelerationMs2 = null;
    _zeroToHundredStart = null;
    _lowSpeedStreak = 0;
    _bestZeroToHundredSeconds = null;
    _isStationary = false;
    _stoppedTime = Duration.zero;
    _currentStopStreakSeconds = 0;
    _currentStopCounted = false;
    _totalStops = 0;
    _peakGForce = 0;
    _brakeAboveThresholdSince = null;
    _lastBrakingEventAt = null;
    _brakingEvents = 0;
    _lastBearing = null;
    _turnAccumDeg = 0;
    _turnWindowStart = null;
    _turnWindowMaxSpeedKmh = 0;
    _turnWindowGyroMagSum = 0;
    _turnWindowGyroSamples = 0;
    _lastTurnAt = null;
    _turnsLeft = 0;
    _turnsRight = 0;
    _maxCorneringSpeedKmh = null;
    _gyroEverFired = false;
  }

  void _onPosition(Position position) {
    final now = DateTime.now();

    // Fix troppo impreciso (tunnel, garage, sotto palazzi alti): nessun
    // contributo a percorso/distanza/velocità/telemetria, si aspetta il
    // prossimo fix. _lastPosition non viene toccato, quindi il prossimo
    // fix buono si confronta comunque con l'ultima posizione BUONA nota,
    // non con questo rumore.
    final accuracy = position.accuracy;
    if (accuracy.isFinite && accuracy > _kMinGpsAccuracyM) return;

    final last = _lastPosition;
    final lastAt = _lastPositionAt;
    var hadRealMotion = last == null;
    var meters = 0.0;
    if (last != null) {
      meters = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        position.latitude,
        position.longitude,
      );

      // Tetto di plausibilità fisica: uno scatto la cui velocità implicita
      // supera quella di un'auto reale (riaggancio GPS dopo un tunnel,
      // cambio cella) non è un vero spostamento — si scarta l'intero fix
      // invece di sommarlo alla distanza o disegnarlo come tratto di
      // percorso. _lastPosition resta quello precedente, stesso motivo del
      // filtro accuratezza sopra.
      final dtSeconds = lastAt != null
          ? now.difference(lastAt).inMilliseconds / 1000
          : 0.0;
      final impliedSpeedMs = dtSeconds > 0 ? meters / dtSeconds : 0.0;
      if (impliedSpeedMs > _kMaxPlausibleSpeedMs) return;

      // Filtra il jitter GPS da fermo: sotto la soglia è rumore, non
      // movimento reale. La soglia sta sopra l'errore tipico di un fix
      // buono (non allo stesso livello del `distanceFilter` nativo, 3m —
      // vedi _liveLocationSettings —, che scarterebbe solo i fix
      // pressoché identici e lascerebbe passare comunque il rumore).
      hadRealMotion = meters > _kJitterDistanceM;
    }

    // Annulla la stima accumulata dal ticker a 1Hz: da qui in poi la
    // distanza torna a basarsi solo sul delta reale tra fix GPS.
    var distanceKm = state.distanceKm - _interpolatedKm;
    _interpolatedKm = 0;

    if (hadRealMotion && last != null) {
      distanceKm += meters / 1000;

      // Direzione delle svolte: solo da bearing GPS, mai dall'asse z del
      // giroscopio, che sarebbe "yaw" solo assumendo un montaggio fisso
      // del telefono nel veicolo — assunzione che non facciamo da nessuna
      // parte in questo file.
      final bearing = Geolocator.bearingBetween(
        last.latitude,
        last.longitude,
        position.latitude,
        position.longitude,
      );
      if (_lastBearing != null) {
        var delta = bearing - _lastBearing!;
        delta = ((delta + 180) % 360) - 180;
        _turnAccumDeg += delta;
        _turnWindowStart ??= now;
      }
      _lastBearing = bearing;
    }
    _lastPosition = position;
    _lastPositionAt = now;

    // Aggiunge il punto al tracciato solo su movimento reale: i fix
    // scartati come jitter (sopra) altrimenti si accumulano come punti
    // quasi duplicati e rendono la linea disegnata più frastagliata.
    if (hadRealMotion) {
      _points.add(RoutePoint(position.latitude, position.longitude));
    }
    if (_points.length > 1000) {
      // +1 sul limite superiore per includere sempre l'ultimo indice
      // anche quando la lunghezza è pari — altrimenti il punto appena
      // aggiunto sopra (sempre l'ultimo della lista) sparirebbe subito
      // dal diradamento invece di restarci fino al prossimo fix.
      final thinned = <RoutePoint>[
        for (var i = 0; i < _points.length; i += 2) _points[i],
        if (_points.length.isEven) _points.last,
      ];
      _points
        ..clear()
        ..addAll(thinned);
    }

    final rawSpeedKmh = (position.speed.isFinite && position.speed > 0)
        ? position.speed * 3.6
        : 0.0;
    // Tetto di plausibilità anche sulla velocità istantanea riportata dal
    // GPS: senza questo un singolo fix anomalo alza maxSpeedKmh per
    // sempre, senza alcun modo di correggerlo (è un massimo monotono).
    final speedKmh = math.min(rawSpeedKmh, _kMaxPlausibleSpeedKmh);
    state = state.copyWith(
      distanceKm: distanceKm,
      currentSpeedKmh: speedKmh,
      maxSpeedKmh: speedKmh > state.maxSpeedKmh ? speedKmh : state.maxSpeedKmh,
      routePoints: List.unmodifiable(_points),
    );

    final crewChannel = _crewChannel;
    final lastBroadcast = _lastCrewBroadcastAt;
    // Throttle allineato all'intervallo GPS nativo (1s, vedi
    // _liveLocationSettings): evita raffiche ravvicinate se la piattaforma
    // consegna comunque più fix di quanti richiesti.
    final canBroadcast = lastBroadcast == null ||
        now.difference(lastBroadcast) >= const Duration(milliseconds: 900);
    if (crewChannel != null && canBroadcast) {
      _lastCrewBroadcastAt = now;
      unawaited(crewChannel.sendBroadcastMessage(
        event: 'position',
        payload: {
          'profileId': _crewProfileId,
          'username': _crewUsername,
          'avatarUrl': _crewAvatarUrl,
          'accentColor': _crewAccentColor,
          'lat': position.latitude,
          'lng': position.longitude,
          'speedKmh': speedKmh,
          'heading': position.heading.isFinite ? position.heading : null,
        },
      ));
    }

    if (_turnWindowStart != null && speedKmh > _turnWindowMaxSpeedKmh) {
      _turnWindowMaxSpeedKmh = speedKmh;
    }
    _resolveTurnWindow(now);

    // Quota: dislivello (somma dei soli guadagni) e altitudine massima —
    // dato GPS già raccolto, nessun sensore aggiuntivo necessario.
    final elevationM = position.altitude.isFinite ? position.altitude : null;
    if (elevationM != null) {
      final lastElevation = _lastElevationM;
      if (lastElevation != null && elevationM > lastElevation) {
        _elevationGainM += elevationM - lastElevation;
      }
      if (_maxAltitudeM == null || elevationM > _maxAltitudeM!) {
        _maxAltitudeM = elevationM;
      }
      _lastElevationM = elevationM;
    }

    // Accelerazione/decelerazione max: derivata della velocità GPS su una
    // finestra di 3 fix (attenua il rumore/quantizzazione di un singolo
    // fix), non dagli assi grezzi dell'accelerometro — l'asse "avanti" del
    // telefono rispetto al veicolo non è noto.
    if (hadRealMotion) {
      _recentSpeedFixes.add(_SpeedFix(now, speedKmh / 3.6));
      if (_recentSpeedFixes.length > 3) _recentSpeedFixes.removeAt(0);
      if (_recentSpeedFixes.length == 3) {
        final first = _recentSpeedFixes.first;
        final lastFix = _recentSpeedFixes.last;
        final dt = lastFix.time.difference(first.time);
        if (dt >= _kAccelMinDt && dt <= _kAccelMaxDt) {
          final a =
              (lastFix.speedMs - first.speedMs) / (dt.inMilliseconds / 1000);
          if (a > 0 &&
              (_maxAccelerationMs2 == null || a > _maxAccelerationMs2!)) {
            _maxAccelerationMs2 = a;
          }
          if (a < 0 &&
              (_maxDecelerationMs2 == null || a < _maxDecelerationMs2!)) {
            _maxDecelerationMs2 = a;
          }
        }
      }
    } else {
      _recentSpeedFixes.clear();
    }

    // Tempo 0-100 km/h: isteresi per non far ripartire il tentativo su un
    // singolo campione GPS rumoroso.
    if (speedKmh <= _kZeroToHundredArmSpeedKmh) {
      _lowSpeedStreak++;
      if (_lowSpeedStreak >= 2) {
        _zeroToHundredStart = null;
      }
    } else {
      _lowSpeedStreak = 0;
      _zeroToHundredStart ??= now;
    }
    final zeroToHundredStart = _zeroToHundredStart;
    if (zeroToHundredStart != null && speedKmh >= _kZeroToHundredTargetKmh) {
      final elapsed = now.difference(zeroToHundredStart).inMilliseconds / 1000;
      if (elapsed <= _kZeroToHundredMaxAttemptSeconds &&
          (_bestZeroToHundredSeconds == null ||
              elapsed < _bestZeroToHundredSeconds!)) {
        _bestZeroToHundredSeconds = elapsed;
      }
    }

    // Tempo da fermo/soste: qui rileviamo solo la transizione, l'accumulo
    // di durata è sul ticker a 1Hz (vedi startTrip) perché il GPS smette di
    // consegnare fix regolari quando il veicolo è fermo.
    final wasStationary = _isStationary;
    _isStationary = speedKmh < _kStationarySpeedKmh;
    if (_isStationary && !wasStationary) {
      _currentStopStreakSeconds = 0;
      _currentStopCounted = false;
    }

    final startedAt = _startedAt;
    final elapsedSeconds =
        startedAt == null ? 0 : now.difference(startedAt).inSeconds;
    _samples.add(TelemetrySample(elapsedSeconds, speedKmh, elevationM));
    if (_samples.length > 600) {
      // Stesso +1 di sopra sul diradamento di _points: senza, il campione
      // appena aggiunto (sempre l'ultimo della lista) sparisce quando la
      // lunghezza è pari.
      final thinned = <TelemetrySample>[
        for (var i = 0; i < _samples.length; i += 2) _samples[i],
        if (_samples.length.isEven) _samples.last,
      ];
      _samples
        ..clear()
        ..addAll(thinned);
    }

    final lastPersisted = _lastPersistedAt;
    if (lastPersisted == null ||
        now.difference(lastPersisted) >= const Duration(seconds: 5)) {
      _lastPersistedAt = now;
      unawaited(_persistState());
    }
  }

  /// Chiude la finestra di svolta corrente se ha superato la soglia
  /// cumulativa di bearing (svolta reale, corroborata dal giroscopio) o se
  /// è scaduta senza raggiungerla (rumore/leggera curva, scartata).
  void _resolveTurnWindow(DateTime now) {
    if (_turnWindowStart == null) return;
    if (_turnAccumDeg.abs() >= _kTurnThresholdDeg) {
      final canCount =
          _lastTurnAt == null || now.difference(_lastTurnAt!) > _kTurnCooldown;
      final avgGyroMag = _turnWindowGyroSamples > 0
          ? _turnWindowGyroMagSum / _turnWindowGyroSamples
          : 0.0;
      // Se il giroscopio non ha mai consegnato un evento in tutto il
      // viaggio (assente sul device, o stream in errore), non blocchiamo
      // la rilevazione delle svolte sulla sua corroborazione: il bearing
      // GPS da solo resta un segnale valido.
      final gyroCorroborated =
          !_gyroEverFired || avgGyroMag >= _kTurnGyroCorroborationRadS;
      if (canCount && gyroCorroborated) {
        if (_turnAccumDeg > 0) {
          _turnsRight++;
        } else {
          _turnsLeft++;
        }
        if (_maxCorneringSpeedKmh == null ||
            _turnWindowMaxSpeedKmh > _maxCorneringSpeedKmh!) {
          _maxCorneringSpeedKmh = _turnWindowMaxSpeedKmh;
        }
        _lastTurnAt = now;
      }
      _closeTurnWindow();
    } else if (now.difference(_turnWindowStart!) > _kTurnWindowTimeout) {
      _closeTurnWindow();
    }
  }

  void _closeTurnWindow() {
    _turnAccumDeg = 0;
    _turnWindowStart = null;
    _turnWindowMaxSpeedKmh = 0;
    _turnWindowGyroMagSum = 0;
    _turnWindowGyroSamples = 0;
  }

  void _onUserAccel(UserAccelerometerEvent event) {
    final magnitude =
        math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    final g = magnitude / 9.81;
    if (g > _peakGForce) _peakGForce = g;

    final now = DateTime.now();
    if (magnitude > _kBrakingThresholdMs2) {
      _brakeAboveThresholdSince ??= now;
      final sustained = now.difference(_brakeAboveThresholdSince!);
      final cooledDown = _lastBrakingEventAt == null ||
          now.difference(_lastBrakingEventAt!) > _kBrakingCooldown;
      if (sustained >= _kBrakingMinSustain && cooledDown) {
        _brakingEvents++;
        _lastBrakingEventAt = now;
      }
    } else {
      _brakeAboveThresholdSince = null;
    }
  }

  void _onGyro(GyroscopeEvent event) {
    _gyroEverFired = true;
    if (_turnWindowStart == null) return;
    final magnitude =
        math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    _turnWindowGyroMagSum += magnitude;
    _turnWindowGyroSamples++;
  }

  Future<TripSummary?> finishTrip() async {
    final tripId = _tripId;
    if (tripId == null) return null;

    await _positionSub?.cancel();
    await _userAccelSub?.cancel();
    await _gyroSub?.cancel();
    _ticker?.cancel();
    state = state.copyWith(status: TripLiveStatus.finishing);

    final Trip finished;
    try {
      finished = await ref.read(tripRepositoryProvider).completeTrip(
            tripId: tripId,
            distanceKm: state.distanceKm,
            durationSeconds: state.elapsed.inSeconds,
            avgSpeedKmh: state.avgSpeedKmh,
            maxSpeedKmh: state.maxSpeedKmh,
            route: List.unmodifiable(_points),
          );
    } catch (_) {
      // Il viaggio resta 'active' lato server (nessuna riga aggiornata se
      // la RPC fallisce): riportiamo lo stato a tracking così l'utente
      // può ritentare "Termina viaggio" invece di restare bloccato su
      // "finishing" col pulsante disabilitato.
      state = state.copyWith(status: TripLiveStatus.tracking);
      rethrow;
    }

    final summary = TripSummary(
      trip: finished,
      routePoints: List.unmodifiable(_points),
      samples: List.unmodifiable(_samples),
      motionStats: TripMotionStats(
        elevationGainM: _elevationGainM,
        maxAltitudeM: _maxAltitudeM,
        maxAccelerationMs2: _maxAccelerationMs2,
        maxDecelerationMs2: _maxDecelerationMs2,
        zeroToHundredSeconds: _bestZeroToHundredSeconds,
        stoppedTime: _stoppedTime,
        totalStops: _totalStops,
        peakGForce: _peakGForce,
        brakingEvents: _brakingEvents,
        turnsLeft: _turnsLeft,
        turnsRight: _turnsRight,
        maxCorneringSpeedKmh: _maxCorneringSpeedKmh,
      ),
    );

    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId != null && finished.distanceKm > 0) {
      ref.read(missionEventBusProvider).publish(
            TripCompleted(profileId: userId, distanceKm: finished.distanceKm),
          );
    }

    ref.invalidate(recentTripsProvider);
    ref.read(lastTripSummaryControllerProvider.notifier).set(summary);
    await _clearPersisted();
    _reset();
    return summary;
  }

  Future<void> discardTrip() async {
    final tripId = _tripId;
    await _positionSub?.cancel();
    await _userAccelSub?.cancel();
    await _gyroSub?.cancel();
    _ticker?.cancel();
    if (tripId != null) {
      await ref.read(tripRepositoryProvider).discardTrip(tripId);
    }
    await _clearPersisted();
    _reset();
  }

  /// Chiude una guida recuperata da [PersistedTripState] (dopo un kill del
  /// processo, vedi [pendingTripRecoveryProvider]) usando solo i dati già
  /// raccolti prima dell'interruzione — non riprende il tracking GPS. Non
  /// tocca lo stato "live" del controller, che resta idle.
  Future<void> finishPersistedTrip(PersistedTripState saved) async {
    final durationSeconds =
        DateTime.now().difference(saved.startedAt).inSeconds;
    final avgSpeedKmh =
        durationSeconds > 0 ? saved.distanceKm / (durationSeconds / 3600) : 0.0;
    final finished = await ref.read(tripRepositoryProvider).completeTrip(
          tripId: saved.tripId,
          distanceKm: saved.distanceKm,
          durationSeconds: durationSeconds,
          avgSpeedKmh: avgSpeedKmh,
          maxSpeedKmh: saved.maxSpeedKmh,
          route: saved.routePoints,
        );
    ref.invalidate(recentTripsProvider);
    ref.read(lastTripSummaryControllerProvider.notifier).set(
          TripSummary(trip: finished, routePoints: saved.routePoints),
        );
    await _clearPersisted();
  }

  /// Scarta una guida recuperata da [PersistedTripState] senza riprendere il
  /// tracking GPS.
  Future<void> discardPersistedTrip(PersistedTripState saved) async {
    await ref.read(tripRepositoryProvider).discardTrip(saved.tripId);
    await _clearPersisted();
  }

  void _reset() {
    _tripId = null;
    _startedAt = null;
    _lastPosition = null;
    _lastPositionAt = null;
    _points.clear();
    _samples.clear();
    _resetMotionStats();
    _leaveCrewLiveChannel();
    state = const TripLiveState();
  }
}
