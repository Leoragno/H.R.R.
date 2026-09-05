import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:battery_plus/battery_plus.dart';
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
import '../../../game/domain/hex_grid.dart';
import '../../../game/presentation/providers/territory_provider.dart';
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
  // Il risparmio energetico (Battery Saver Android / Low Power Mode iOS)
  // può limitare gli aggiornamenti GPS in background e interrompere la
  // registrazione della guida — vedi _checkBatterySaver(). true finché
  // resta attivo; la UI (TripLiveScreen) ne osserva la transizione a true
  // per mostrare l'avviso una sola volta, non ad ogni rebuild.
  final bool batterySaverActive;

  const TripLiveState({
    this.status = TripLiveStatus.idle,
    this.tripId,
    this.elapsed = Duration.zero,
    this.distanceKm = 0,
    this.currentSpeedKmh = 0,
    this.maxSpeedKmh = 0,
    this.errorMessage,
    this.routePoints = const [],
    this.batterySaverActive = false,
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
    bool? batterySaverActive,
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
      batterySaverActive: batterySaverActive ?? this.batterySaverActive,
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
  final int laneChanges;
  final double? maxCorneringSpeedKmh;

  // --- Aggregati per il punteggio di guida (vedi complete_trip in
  // 0024_drive_score.sql — il punteggio finale è calcolato lì, questi sono
  // solo gli input grezzi). Nessuno di questi è mostrato nel report al
  // posto delle statistiche sopra: alimentano solo la RPC.
  final int brakingHardEvents; // sottoinsieme di brakingEvents, decelerazione >5 m/s²
  final double? brakingJerkAvgMs3; // durezza media delle frenate rilevate
  final double? jerkRmsMs3; // fluidità: RMS del jerk longitudinale sull'intero viaggio
  final double? turnGyroStddevAvg; // curve: media della dev. standard giroscopica per svolta
  final int accelThenBrakeCount; // efficienza: accelerazione seguita da frenata entro 15s
  final double? gpsFixHz; // tasso di fix GPS accettati — gate qualità dato
  final double? gyroHz; // tasso di campioni giroscopio ricevuti — gate qualità dato

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
    this.laneChanges = 0,
    this.maxCorneringSpeedKmh,
    this.brakingHardEvents = 0,
    this.brakingJerkAvgMs3,
    this.jerkRmsMs3,
    this.turnGyroStddevAvg,
    this.accelThenBrakeCount = 0,
    this.gpsFixHz,
    this.gyroHz,
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
// Soglia di decelerazione "frenata dura", applicata alla derivata
// velocità/tempo del GPS (vedi _onPosition) — mai all'accelerometro
// grezzo: la sua magnitude non ha segno né direzione rispetto al verso di
// marcia, quindi non distingue una frenata da una sterzata decisa, da
// un'accelerata o da una buca (stesso ordine di grandezza per tutte).
// Riusata anche come soglia minima "manovra dura" in _onUserAccel, sotto
// la quale un campione dell'accelerometro non vale nemmeno la pena di
// essere considerato come possibile picco G.
const _kBrakingThresholdMs2 = 0.35 * 9.81;
const _kBrakingCooldown = Duration(seconds: 2);
// Frenata "inchiodata" per il punteggio di guida (0024_drive_score.sql):
// oltre questa decelerazione l'evento pesa il triplo nella componente
// Anticipo — valore di partenza dal brief, da tarare sui dati reali.
const _kHardBrakingThresholdMs2 = 5.0;
// Un singolo campione anomalo dell'accelerometro (buca, telefono che
// sbatte contro il supporto) alzerebbe il picco G per sempre, senza modo
// di correggerlo (è un massimo monotono, vedi _onUserAccel): un vero
// picco di guida (frenata/sterzata/accelerata decisa) resta sopra la
// soglia di rumore per più di un campione, un urto isolato no.
const _kAccelSpikeMinSustain = Duration(milliseconds: 150);
const _kTurnThresholdDeg = 25.0;
const _kTurnWindowTimeout = Duration(seconds: 4);
const _kTurnCooldown = Duration(seconds: 3);
const _kTurnGyroCorroborationRadS = 0.15;
// Cambio di corsia: stessa finestra di osservazione delle svolte
// (_turnAccumDeg/_turnWindowStart), ma una deviazione cumulativa di
// bearing più piccola di una svolta vera — sterzata più lieve e più
// breve, non rumore GPS. Banda mutuata dal prototipo (Guida.dc.html,
// 12°..45° lì, qui riscalata sulla soglia svolta locale di 25°).
const _kLaneChangeThresholdDeg = 12.0;
// Corroborazione giroscopica per un cambio corsia: sterzata più lieve di
// una svolta, quindi soglia proporzionalmente più bassa di
// _kTurnGyroCorroborationRadS.
const _kLaneChangeGyroCorroborationRadS = 0.07;
const _kLaneChangeCooldown = Duration(seconds: 3);
// Sotto questa velocità il bearing tra due fix consecutivi è dominato dal
// rumore GPS (lo spostamento reale in ~1s è piccolo quanto o meno
// dell'errore tipico di un fix, fino a _kMinGpsAccuracyM) — a quella
// velocità comunque non si sta svoltando in marcia, solo manovrando a
// passo d'uomo, quindi il campione va scartato invece di sporcare il
// conteggio delle svolte.
const _kMinTurnSpeedKmh = 10.0;

// Soglia di accelerazione "decisa" simmetrica a _kBrakingThresholdMs2,
// usata solo per il pattern "accelerazione seguita da frenata" (Efficienza
// del punteggio di guida) — non è una nuova soglia di frenata.
const _kHardAccelThresholdMs2 = 0.35 * 9.81;
// Finestra entro cui una frenata dopo un'accelerazione decisa conta come
// energia sprecata (accelerato e subito ri-frenato), non due manovre
// indipendenti.
const _kAccelThenBrakeWindow = Duration(seconds: 15);

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
        'route': [
          for (final p in routePoints) [p.lat, p.lng]
        ],
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
    return PersistedTripState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
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
Future<PersistedTripState?> pendingTripRecovery(
    PendingTripRecoveryRef ref) async {
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

  // --- Mappa live condivisa: vedi _joinLiveChannels / LiveMapController.
  // Un solo canale Realtime "drivers-live" per tutti gli utenti — l'app è
  // privata e chiusa, tutti sono già "connessi" tra loro.
  RealtimeChannel? _liveChannel;
  String? _myProfileId;
  String? _myUsername;
  String? _myAvatarUrl;
  String? _myAccentColor;
  DateTime? _lastLiveBroadcastAt;
  final List<RoutePoint> _points = [];
  final List<TelemetrySample> _samples = [];
  // Esagoni territorio attraversati durante la guida — rivendicati in
  // blocco a fine viaggio col punteggio di guida finale (vedi finishTrip),
  // non più durante il tragitto: l'acquisizione dei pentagoni è legata a
  // una guida registrata, mai a un tracking ambientale indipendente
  // (0026_territory_decay_counterattack.sql).
  final Set<HexCoord> _crossedCells = {};
  DateTime? _startedAt;
  String? _tripId;
  SharedPreferences? _prefs;
  DateTime? _lastPersistedAt;

  // --- Avviso risparmio energetico: vedi _checkBatterySaver ---
  final _battery = Battery();
  int _batteryCheckTickCount = 0;

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
  DateTime? _gSpikeSince;
  double? _gSpikeCandidateMs2;
  DateTime? _lastBrakingEventAt;
  int _brakingEvents = 0;

  // --- Aggregati per il punteggio di guida (0024_drive_score.sql) ---
  int _brakingHardEvents = 0;
  double _brakingJerkSum = 0;
  int _brakingJerkCount = 0;
  double? _lastAccelMs2; // ultima accelerazione derivata dal GPS (con segno)
  DateTime? _lastAccelAt;
  double _jerkSumSq = 0;
  int _jerkCount = 0;
  DateTime? _lastHardAccelAt;
  int _accelThenBrakeCount = 0;
  int _gpsAcceptedFixCount = 0;
  int _gyroSampleCount = 0;
  double _turnWindowGyroMagSumSq = 0;
  double _turnStddevSum = 0; // somma delle dev. standard per-svolta, per la media finale
  int _turnStddevCount = 0;

  double? _lastBearing;
  double _turnAccumDeg = 0;
  DateTime? _turnWindowStart;
  double _turnWindowMaxSpeedKmh = 0;
  double _turnWindowGyroMagSum = 0;
  int _turnWindowGyroSamples = 0;
  DateTime? _lastTurnAt;
  int _turnsLeft = 0;
  int _turnsRight = 0;
  DateTime? _lastLaneChangeAt;
  int _laneChanges = 0;
  double? _maxCorneringSpeedKmh;
  bool _gyroEverFired = false;

  @override
  TripLiveState build() {
    ref.onDispose(() {
      _positionSub?.cancel();
      _userAccelSub?.cancel();
      _gyroSub?.cancel();
      _ticker?.cancel();
      _leaveLiveChannels();
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
    // feature ancora placeholder (spotting/POI) non hanno punti reali da
    // cui pubblicare gli altri MissionEvent.
    ref.read(missionEventBusProvider).publish(TripStarted(profileId: userId));

    _tripId = trip.id;
    _startedAt = DateTime.now();
    _lastPosition = null;
    _lastPositionAt = null;
    _points.clear();
    _samples.clear();
    _crossedCells.clear();
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
    _crossedCells
      ..clear()
      ..addAll(
          saved.routePoints.map((p) => HexGrid.cellOf(p.lat, p.lng)));
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
    _batteryCheckTickCount = 0;
    unawaited(_checkBatterySaver());

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = _startedAt;
      if (startedAt != null) {
        state = state.copyWith(elapsed: DateTime.now().difference(startedAt));
      }

      // Riletto ogni 30s (non ad ogni tick, per non interrogare la
      // piattaforma inutilmente): il risparmio energetico può essere
      // attivato anche a guida già iniziata, non solo da fermi.
      _batteryCheckTickCount++;
      if (_batteryCheckTickCount >= 30) {
        _batteryCheckTickCount = 0;
        unawaited(_checkBatterySaver());
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

    unawaited(_joinLiveChannels());

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

  /// Il risparmio energetico (Battery Saver su Android, Low Power Mode su
  /// iOS) può ridurre o sospendere gli aggiornamenti GPS quando l'app va in
  /// background, interrompendo la registrazione della guida — non
  /// prevenibile lato app, solo segnalabile: TripLiveScreen mostra un
  /// avviso quando questo passa a true, consigliando di disattivarlo.
  /// Non supportato su web (battery_plus web lancia UnsupportedError).
  Future<void> _checkBatterySaver() async {
    if (kIsWeb) return;
    try {
      final saveMode = await _battery.isInBatterySaveMode;
      if (saveMode != state.batterySaverActive) {
        state = state.copyWith(batterySaverActive: saveMode);
      }
    } catch (_) {
      // Piattaforma senza supporto (es. desktop): nessun avviso, il
      // tracking GPS non dipende in alcun modo da questo controllo.
    }
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

  /// Pubblica la guida sul canale realtime condiviso "drivers-live", sola
  /// lettura per gli osservatori (chi guida non legge mai il proprio) —
  /// vedi [LiveMapController] per il lato osservatore. Fallisce
  /// silenziosamente in ogni caso, il tracking GPS locale del viaggio non
  /// dipende in alcun modo da questo.
  Future<void> _joinLiveChannels() async {
    try {
      final profile = await ref.read(myProfileProvider.future);
      // Il trip potrebbe essere già terminato mentre attendevamo il profilo.
      if (profile == null || _tripId == null) return;

      _myProfileId = profile.id;
      _myUsername = profile.username;
      _myAvatarUrl = profile.avatarUrl;
      _myAccentColor = profile.accentColor;
      final presence = {
        'profileId': profile.id,
        'username': profile.username,
        'avatarUrl': profile.avatarUrl,
        'accentColor': profile.accentColor,
      };

      final liveChannel = ref.read(supabaseClientProvider).channel(
            'drivers-live',
            opts: const RealtimeChannelConfig(private: true),
          );
      _liveChannel = liveChannel;
      liveChannel.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          unawaited(liveChannel.track(presence));
        }
      });
    } catch (_) {
      // Best-effort: la mappa condivisa non deve mai bloccare o
      // interrompere il tracking GPS locale del viaggio.
    }
  }

  void _leaveLiveChannels() {
    final liveChannel = _liveChannel;
    _liveChannel = null;
    _myProfileId = null;
    _myUsername = null;
    _myAvatarUrl = null;
    _myAccentColor = null;
    _lastLiveBroadcastAt = null;
    if (liveChannel != null) {
      unawaited(liveChannel.untrack());
      unawaited(Supabase.instance.client.removeChannel(liveChannel));
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
    _gSpikeSince = null;
    _gSpikeCandidateMs2 = null;
    _lastBrakingEventAt = null;
    _brakingEvents = 0;
    _brakingHardEvents = 0;
    _brakingJerkSum = 0;
    _brakingJerkCount = 0;
    _lastAccelMs2 = null;
    _lastAccelAt = null;
    _jerkSumSq = 0;
    _jerkCount = 0;
    _lastHardAccelAt = null;
    _accelThenBrakeCount = 0;
    _gpsAcceptedFixCount = 0;
    _gyroSampleCount = 0;
    _turnWindowGyroMagSumSq = 0;
    _turnStddevSum = 0;
    _turnStddevCount = 0;
    _lastBearing = null;
    _turnAccumDeg = 0;
    _turnWindowStart = null;
    _turnWindowMaxSpeedKmh = 0;
    _turnWindowGyroMagSum = 0;
    _turnWindowGyroSamples = 0;
    _lastTurnAt = null;
    _turnsLeft = 0;
    _turnsRight = 0;
    _lastLaneChangeAt = null;
    _laneChanges = 0;
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

    // Tasso di fix GPS "buoni" ricevuti (indipendente da hadRealMotion:
    // conta la qualità del segnale, non il movimento) — gate di qualità
    // per Fluidità/Anticipo del punteggio di guida, vedi finishTrip().
    _gpsAcceptedFixCount++;
    _crossedCells.add(HexGrid.cellOf(position.latitude, position.longitude));

    final rawSpeedKmh = (position.speed.isFinite && position.speed > 0)
        ? position.speed * 3.6
        : 0.0;
    // Tetto di plausibilità anche sulla velocità istantanea riportata dal
    // GPS: senza questo un singolo fix anomalo alza maxSpeedKmh per
    // sempre, senza alcun modo di correggerlo (è un massimo monotono).
    final speedKmh = math.min(rawSpeedKmh, _kMaxPlausibleSpeedKmh);

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
      final dtSeconds =
          lastAt != null ? now.difference(lastAt).inMilliseconds / 1000 : 0.0;
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
      // parte in questo file. Sotto _kMinTurnSpeedKmh il bearing tra due
      // fix è troppo rumoroso per essere affidabile (vedi costante) — si
      // scarta il campione senza aggiornare _lastBearing, così il
      // prossimo confronto utile resta comunque quello vero precedente.
      if (speedKmh > _kMinTurnSpeedKmh) {
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

    state = state.copyWith(
      distanceKm: distanceKm,
      currentSpeedKmh: speedKmh,
      maxSpeedKmh: speedKmh > state.maxSpeedKmh ? speedKmh : state.maxSpeedKmh,
      routePoints: List.unmodifiable(_points),
    );

    final livePayload = {
      'profileId': _myProfileId,
      'username': _myUsername,
      'avatarUrl': _myAvatarUrl,
      'accentColor': _myAccentColor,
      'lat': position.latitude,
      'lng': position.longitude,
      'speedKmh': speedKmh,
      'heading': position.heading.isFinite ? position.heading : null,
    };
    // Throttle allineato all'intervallo GPS nativo (1s, vedi
    // _liveLocationSettings): evita raffiche ravvicinate se la piattaforma
    // consegna comunque più fix di quanti richiesti.
    final liveChannel = _liveChannel;
    if (liveChannel != null &&
        (_lastLiveBroadcastAt == null ||
            now.difference(_lastLiveBroadcastAt!) >=
                const Duration(milliseconds: 900))) {
      _lastLiveBroadcastAt = now;
      unawaited(liveChannel.sendBroadcastMessage(
          event: 'position', payload: livePayload));
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

    // Accelerazione/decelerazione max e conteggio frenate: derivata della
    // velocità GPS su una finestra di 3 fix (attenua il rumore/
    // quantizzazione di un singolo fix), non dagli assi grezzi
    // dell'accelerometro — l'asse "avanti" del telefono rispetto al
    // veicolo non è noto, quindi la sua magnitude non distingue una
    // frenata da una sterzata decisa, un'accelerata o una buca (vedi
    // _kBrakingThresholdMs2 e _onUserAccel).
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
          // Jerk (derivata dell'accelerazione stessa) fra questo campione
          // di `a` e il precedente — usato per Fluidità/Anticipo del
          // punteggio di guida (0024_drive_score.sql). Stessa finestra di
          // validità (_kAccelMinDt.._kAccelMaxDt) del calcolo di `a` sopra,
          // per non dividere per un intervallo troppo corto o troppo vecchio.
          final lastAccel = _lastAccelMs2;
          final lastAccelAt = _lastAccelAt;
          double? jerk;
          if (lastAccel != null && lastAccelAt != null) {
            final jerkDt = now.difference(lastAccelAt);
            if (jerkDt >= _kAccelMinDt && jerkDt <= _kAccelMaxDt) {
              jerk = (a - lastAccel) / (jerkDt.inMilliseconds / 1000);
              _jerkSumSq += jerk * jerk;
              _jerkCount++;
            }
          }
          _lastAccelMs2 = a;
          _lastAccelAt = now;

          if (a >= _kHardAccelThresholdMs2) {
            _lastHardAccelAt = now;
          }

          if (a <= -_kBrakingThresholdMs2) {
            final cooledDown = _lastBrakingEventAt == null ||
                now.difference(_lastBrakingEventAt!) > _kBrakingCooldown;
            if (cooledDown) {
              _brakingEvents++;
              if (a <= -_kHardBrakingThresholdMs2) _brakingHardEvents++;
              if (jerk != null) {
                _brakingJerkSum += jerk.abs();
                _brakingJerkCount++;
              }
              final lastHardAccelAt = _lastHardAccelAt;
              if (lastHardAccelAt != null &&
                  now.difference(lastHardAccelAt) <= _kAccelThenBrakeWindow) {
                _accelThenBrakeCount++;
              }
              _lastBrakingEventAt = now;
            }
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
        // Dev. standard della magnitudine giroscopica durante QUESTA svolta
        // — sterzata costante (bassa) = pulita, oscillante (alta) = sporca.
        // Componente Curve del punteggio di guida (0024_drive_score.sql).
        // Richiede almeno 2 campioni per una varianza sensata.
        if (_turnWindowGyroSamples > 1) {
          final variance = (_turnWindowGyroMagSumSq / _turnWindowGyroSamples) -
              (avgGyroMag * avgGyroMag);
          _turnStddevSum += math.sqrt(variance < 0 ? 0 : variance);
          _turnStddevCount++;
        }
        _lastTurnAt = now;
      }
      _closeTurnWindow();
    } else if (now.difference(_turnWindowStart!) > _kTurnWindowTimeout) {
      _maybeCountLaneChange(now);
      _closeTurnWindow();
    }
  }

  /// Una finestra di svolta che scade senza raggiungere
  /// _kTurnThresholdDeg non è per forza rumore: una sterzata più lieve ma
  /// comunque intenzionale, corroborata dal giroscopio, è un cambio di
  /// corsia — non una svolta.
  void _maybeCountLaneChange(DateTime now) {
    final abs = _turnAccumDeg.abs();
    if (abs < _kLaneChangeThresholdDeg) return;
    final canCount = _lastLaneChangeAt == null ||
        now.difference(_lastLaneChangeAt!) > _kLaneChangeCooldown;
    if (!canCount) return;
    final avgGyroMag = _turnWindowGyroSamples > 0
        ? _turnWindowGyroMagSum / _turnWindowGyroSamples
        : 0.0;
    final gyroCorroborated =
        !_gyroEverFired || avgGyroMag >= _kLaneChangeGyroCorroborationRadS;
    if (!gyroCorroborated) return;
    _laneChanges++;
    _lastLaneChangeAt = now;
  }

  void _closeTurnWindow() {
    _turnAccumDeg = 0;
    _turnWindowStart = null;
    _turnWindowMaxSpeedKmh = 0;
    _turnWindowGyroMagSum = 0;
    _turnWindowGyroMagSumSq = 0;
    _turnWindowGyroSamples = 0;
  }

  void _onUserAccel(UserAccelerometerEvent event) {
    final magnitude =
        math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    final now = DateTime.now();

    // Un singolo campione anomalo (buca, telefono che sbatte contro il
    // supporto, urto) alzerebbe il picco G per sempre senza modo di
    // correggerlo (è un massimo monotono): un vero picco di guida
    // (frenata/sterzata/accelerata decisa) resta sopra la soglia "hard
    // maneuver" per più di un campione, un urto isolato no — si richiede
    // che resti sopra per un breve intervallo sostenuto prima di
    // accettarlo come nuovo picco.
    if (magnitude >= _kBrakingThresholdMs2) {
      _gSpikeSince ??= now;
      final candidate = _gSpikeCandidateMs2;
      if (candidate == null || magnitude > candidate) {
        _gSpikeCandidateMs2 = magnitude;
      }
      if (now.difference(_gSpikeSince!) >= _kAccelSpikeMinSustain) {
        final g = _gSpikeCandidateMs2! / 9.81;
        if (g > _peakGForce) _peakGForce = g;
      }
    } else {
      _gSpikeSince = null;
      _gSpikeCandidateMs2 = null;
    }
  }

  void _onGyro(GyroscopeEvent event) {
    _gyroEverFired = true;
    // Tasso di campioni giroscopio ricevuti sull'intero viaggio — gate di
    // qualità per Curve del punteggio di guida, indipendente dalle finestre
    // di svolta (che coprono solo una piccola parte del viaggio).
    _gyroSampleCount++;
    if (_turnWindowStart == null) return;
    final magnitude =
        math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    _turnWindowGyroMagSum += magnitude;
    _turnWindowGyroMagSumSq += magnitude * magnitude;
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
    // TripLiveScreen sostituisce la mappa live con uno spinner appena lo
    // stato passa a "finishing" (vedi _FinishingView), per smontare la
    // PlatformView nativa MapLibre PRIMA della navigazione verso il
    // riepilogo. Ma quello smontaggio nativo lato Android non è istantaneo:
    // se la RPC sotto risponde più in fretta di quanto richieda, il
    // pushReplacement successivo arriva a metà dello smontaggio della
    // mappa — il flash/schermo nero (a volte bloccato) osservato premendo
    // "Termina viaggio". Questa pausa dà tempo reale al frame senza mappa
    // di essere disegnato e alla PlatformView di chiudersi per bene prima
    // di proseguire.
    await Future.delayed(const Duration(milliseconds: 300));

    final elapsedSeconds = state.elapsed.inSeconds;
    // RMS del jerk sull'intero viaggio (Fluidità) — null se non è mai
    // stato possibile calcolarlo (nessuna coppia di campioni `a` valida).
    final jerkRmsMs3 =
        _jerkCount > 0 ? math.sqrt(_jerkSumSq / _jerkCount) : null;
    final brakingJerkAvgMs3 =
        _brakingJerkCount > 0 ? _brakingJerkSum / _brakingJerkCount : null;
    final turnGyroStddevAvg =
        _turnStddevCount > 0 ? _turnStddevSum / _turnStddevCount : null;
    final gpsFixHz =
        elapsedSeconds > 0 ? _gpsAcceptedFixCount / elapsedSeconds : null;
    final gyroHz =
        elapsedSeconds > 0 ? _gyroSampleCount / elapsedSeconds : null;

    final Trip finished;
    try {
      finished = await ref.read(tripRepositoryProvider).completeTrip(
            tripId: tripId,
            distanceKm: state.distanceKm,
            durationSeconds: elapsedSeconds,
            avgSpeedKmh: state.avgSpeedKmh,
            maxSpeedKmh: state.maxSpeedKmh,
            route: List.unmodifiable(_points),
            jerkRmsMs3: jerkRmsMs3,
            brakingSoftCount: _brakingEvents - _brakingHardEvents,
            brakingHardCount: _brakingHardEvents,
            brakingJerkAvgMs3: brakingJerkAvgMs3,
            turnsCount: _turnsLeft + _turnsRight,
            turnGyroStddevAvg: turnGyroStddevAvg,
            totalStops: _totalStops,
            stoppedSeconds: _stoppedTime.inSeconds,
            accelThenBrakeCount: _accelThenBrakeCount,
            gpsFixHz: gpsFixHz,
            gyroHz: gyroHz,
            elevationGainM: _elevationGainM,
            maxAltitudeM: _maxAltitudeM,
            maxAccelerationMs2: _maxAccelerationMs2,
            maxDecelerationMs2: _maxDecelerationMs2,
            zeroToHundredSeconds: _bestZeroToHundredSeconds,
            peakGForce: _peakGForce,
            turnsLeft: _turnsLeft,
            turnsRight: _turnsRight,
            laneChanges: _laneChanges,
            maxCorneringSpeedKmh: _maxCorneringSpeedKmh,
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
        laneChanges: _laneChanges,
        maxCorneringSpeedKmh: _maxCorneringSpeedKmh,
        brakingHardEvents: _brakingHardEvents,
        brakingJerkAvgMs3: brakingJerkAvgMs3,
        jerkRmsMs3: jerkRmsMs3,
        turnGyroStddevAvg: turnGyroStddevAvg,
        accelThenBrakeCount: _accelThenBrakeCount,
        gpsFixHz: gpsFixHz,
        gyroHz: gyroHz,
      ),
    );

    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId != null && finished.distanceKm > 0) {
      ref.read(missionEventBusProvider).publish(
            TripCompleted(profileId: userId, distanceKm: finished.distanceKm),
          );
    }

    // Rivendica in blocco gli esagoni attraversati durante la guida, col
    // punteggio di guida appena calcolato server-side — mai prima d'ora,
    // mai senza un viaggio completato (0026_territory_decay_
    // counterattack.sql). Best-effort: un errore di rete qui non deve mai
    // bloccare o invalidare il riepilogo del viaggio, che è già salvato.
    if (_crossedCells.isNotEmpty) {
      final cellsToClaim = _crossedCells.toList();
      unawaited(() async {
        try {
          await ref.read(territoryRepositoryProvider).claimCells(
                cellsToClaim,
                driveScore: finished.drivingScore,
              );
        } catch (_) {}
      }());
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
    // Nessun aggregato di guida raccolto per un viaggio recuperato dopo un
    // kill del processo (mai passato da resumeTrip): drivingScore è quindi
    // sempre null qui, quindi può solo rivendicare celle libere/decadute,
    // mai rubarne una attiva — comunque meglio di perdere del tutto gli
    // esagoni attraversati prima dell'interruzione.
    final cellsToClaim = {
      for (final p in saved.routePoints) HexGrid.cellOf(p.lat, p.lng),
    }.toList();
    if (cellsToClaim.isNotEmpty) {
      unawaited(() async {
        try {
          await ref
              .read(territoryRepositoryProvider)
              .claimCells(cellsToClaim, driveScore: finished.drivingScore);
        } catch (_) {}
      }());
    }

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
    _crossedCells.clear();
    _resetMotionStats();
    _leaveLiveChannels();
    state = const TripLiveState();
  }
}
