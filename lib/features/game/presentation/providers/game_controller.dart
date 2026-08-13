import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/territory_cell.dart';
import '../../domain/entities/territory_claim_result.dart';
import '../../domain/entities/territory_standing.dart';
import '../../domain/hex_grid.dart';
import 'territory_provider.dart';

part 'game_controller.g.dart';

/// I 3 modi di colorazione della mappa (mockup: "Giocatore singolo" /
/// "Il mio club" / "La mia mappa").
enum GameMapMode {
  solo,
  crew,
  mineOnly;

  String get label => switch (this) {
        GameMapMode.solo => 'Giocatore singolo',
        GameMapMode.crew => 'La mia crew',
        GameMapMode.mineOnly => 'La mia mappa',
      };
}

enum GameGpsStatus { idle, requesting, tracking, denied, disabled }

class GameState {
  final GameMapMode mapMode;
  final TerritoryMetric panelTab;
  final TerritoryScope scope;
  final bool panelExpanded;
  final HexCoord? focus;
  // Posizione reale (non arrotondata a cella) dell'ultimo fix GPS, usata
  // solo per centrare la mappa vera sotto la griglia esagonale — il
  // gioco in sé ragiona esclusivamente in HexCoord.
  final double? focusLat;
  final double? focusLon;
  final Map<String, TerritoryCell> visibleCells;
  final TerritoryClaimResult session;
  final int myCellCount;
  final GameGpsStatus gpsStatus;

  const GameState({
    this.mapMode = GameMapMode.solo,
    this.panelTab = TerritoryMetric.general,
    this.scope = TerritoryScope.global,
    this.panelExpanded = false,
    this.focus,
    this.focusLat,
    this.focusLon,
    this.visibleCells = const {},
    this.session = TerritoryClaimResult.zero,
    this.myCellCount = 0,
    this.gpsStatus = GameGpsStatus.idle,
  });

  GameState copyWith({
    GameMapMode? mapMode,
    TerritoryMetric? panelTab,
    TerritoryScope? scope,
    bool? panelExpanded,
    HexCoord? focus,
    double? focusLat,
    double? focusLon,
    Map<String, TerritoryCell>? visibleCells,
    TerritoryClaimResult? session,
    int? myCellCount,
    GameGpsStatus? gpsStatus,
  }) {
    return GameState(
      mapMode: mapMode ?? this.mapMode,
      panelTab: panelTab ?? this.panelTab,
      scope: scope ?? this.scope,
      panelExpanded: panelExpanded ?? this.panelExpanded,
      focus: focus ?? this.focus,
      focusLat: focusLat ?? this.focusLat,
      focusLon: focusLon ?? this.focusLon,
      visibleCells: visibleCells ?? this.visibleCells,
      session: session ?? this.session,
      myCellCount: myCellCount ?? this.myCellCount,
      gpsStatus: gpsStatus ?? this.gpsStatus,
    );
  }

  double areaKm2() => myCellCount * HexGrid.cellAreaKm2();
}

// Finestra (in celle) attorno al focus per cui si interrogano le celle
// possedute — abbastanza larga da riempire lo schermo del painter.
const _kViewCols = 10;
const _kViewRows = 17;

// Sotto questa distanza dall'ultima cella rivendicata un nuovo fix GPS è
// rumore, non un vero spostamento in una cella diversa (l'esagono è già
// largo ~80 m da bordo a bordo, distanceFilter tiene il flusso leggero).
const _kPositionDistanceFilterM = 12;

// Fix troppo impreciso (tunnel, garage, edifici alti): scartato prima di
// spostare focus/marker o rivendicare celle, altrimenti un singolo fix
// rumoroso fa "saltare" la posizione sulla mappa — stesso filtro già
// usato da TripLiveController._onPosition per la Guida.
const _kMinGpsAccuracyM = 25.0;

// keepAlive: la conquista territorio è un tracking ambientale continuo,
// non legato alla schermata "Gioca" — deve restare attivo anche
// navigando su altre tab o con l'app minimizzata (vedi
// _liveLocationSettings). Istanziato da [HrrApp] con ref.watch (stesso
// pattern di RivalController/MissionEventBridge) così parte all'avvio
// dell'app — anzi al login — non solo alla prima apertura di GameScreen.
@Riverpod(keepAlive: true)
class GameController extends _$GameController {
  StreamSubscription<Position>? _positionSub;
  Timer? _flushTimer;
  HexCoord? _lastClaimedCell;
  final List<HexCoord> _pendingClaims = [];

  // Distingue un vero cambio di sessione (login/logout/altro utente) da una
  // riemissione di onAuthStateChange a utente invariato (es. TOKEN_REFRESHED,
  // che Supabase spara periodicamente): solo il primo deve (ri)avviare o
  // fermare il tracking GPS.
  String? _trackedUserId;

  @override
  GameState build() {
    ref.onDispose(() {
      _positionSub?.cancel();
      _flushTimer?.cancel();
    });

    // ref.listen (non ref.watch): il tracking deve reagire ai cambi di
    // sessione come EFFETTO — non deve far ripartire build() (e quindi
    // resettare lo stato già accumulato: visibleCells, session, focus) ad
    // ogni evento auth. Il callback gira fuori dal frame sincrono di
    // build(), quindi può scrivere su `state` in sicurezza (a differenza di
    // build() stesso, dove `state` non è ancora inizializzato — vedi
    // _onAuthChanged). fireImmediately: prende in carico anche la sessione
    // già attiva al primo avvio, non solo i login successivi.
    ref.listen(authStateProvider, (previous, next) {
      final userId = next.valueOrNull?.id;
      Future.microtask(() => _onAuthChanged(userId));
    }, fireImmediately: true);

    return const GameState();
  }

  void _stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _pendingClaims.clear();
    _lastClaimedCell = null;
  }

  Future<void> _onAuthChanged(String? userId) async {
    if (userId == _trackedUserId) return;
    _trackedUserId = userId;

    if (userId == null) {
      _stopTracking();
      state = const GameState();
      return;
    }

    state = const GameState();
    unawaited(_refreshMyCellCount(userId));
    await _startTracking();
  }

  Future<void> _startTracking() async {
    state = state.copyWith(gpsStatus: GameGpsStatus.requesting);

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      state = state.copyWith(gpsStatus: GameGpsStatus.denied);
      return;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      state = state.copyWith(gpsStatus: GameGpsStatus.disabled);
      return;
    }

    // Su iOS il tracking in background richiede il permesso "Always", ma
    // Geolocator.requestPermission() sa mostrare solo il prompt "When In
    // Use": con permesso già concesso (non più "notDetermined") una seconda
    // chiamata a Geolocator ritorna subito lo stato corrente senza chiedere
    // nulla. Solo permission_handler attiva davvero il prompt di upgrade
    // nativo — qui, dopo aver già ottenuto "When In Use" sopra (stesso
    // pattern di TripLiveController.startTrip).
    if (!kIsWeb && Platform.isIOS) {
      await ph.Permission.locationAlways.request();
    }

    try {
      // Fix fresco, non l'ultimo noto in cache (Geolocator.getLastKnownPosition
      // può restare valido per giorni): all'apertura del gioco la visuale deve
      // partire dalla posizione attuale, non da dove ti trovavi l'ultima volta.
      // Non supportato su web (geolocator_web lancia UnsupportedError): va
      // bene, il primo vero fix arriva comunque dallo stream sotto.
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      await _onPosition(current);
    } catch (_) {}

    state = state.copyWith(gpsStatus: GameGpsStatus.tracking);
    _positionSub?.cancel();
    _positionSub =
        Geolocator.getPositionStream(locationSettings: _liveLocationSettings())
            .listen(_onPosition);

    _flushTimer?.cancel();
    _flushTimer =
        Timer.periodic(const Duration(seconds: 8), (_) => _flushClaims());
  }

  /// Impostazioni GPS piattaforma-specifiche perché la conquista territorio
  /// continui anche ad app minimizzata/schermo bloccato: su Android come
  /// foreground service con notifica persistente (mantiene il tracking "in
  /// foreground" agli occhi del sistema senza richiedere
  /// ACCESS_BACKGROUND_LOCATION); su iOS con gli aggiornamenti in
  /// background abilitati (richiede il permesso "Always" sopra +
  /// UIBackgroundModes=location in Info.plist). Stesso pattern di
  /// TripLiveController._liveLocationSettings.
  LocationSettings _liveLocationSettings() {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _kPositionDistanceFilterM,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'HRR sta tracciando la tua conquista territorio',
          notificationText: 'Tocca per tornare all\'app',
          notificationChannelName: 'Conquista territorio',
          setOngoing: true,
        ),
      );
    }
    if (!kIsWeb && Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _kPositionDistanceFilterM,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: _kPositionDistanceFilterM,
    );
  }

  /// Forza un fix GPS immediato e ridisegna — usato dal pulsante "Centra"
  /// (utile se lo stream non ha ancora consegnato un fix, es. da fermi).
  Future<void> recenterNow() async {
    if (state.gpsStatus == GameGpsStatus.denied ||
        state.gpsStatus == GameGpsStatus.disabled) {
      await _startTracking();
      return;
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _onPosition(position);
    } catch (_) {
      // GPS momentaneamente non disponibile: lo stream in background
      // riproverà da solo, nessun errore bloccante da mostrare qui.
    }
  }

  Future<void> _onPosition(Position position) async {
    final cell = HexGrid.cellOf(position.latitude, position.longitude);
    final focusChanged = state.focus != cell;

    // Mappa/focus seguono comunque il GPS grezzo — meglio una posizione
    // approssimata (o la mappa reale sotto, che si autocorregge da sola col
    // fix successivo) che uno schermo vuoto in attesa di un fix perfetto.
    state = state.copyWith(
      focus: cell,
      focusLat: position.latitude,
      focusLon: position.longitude,
    );
    if (focusChanged) {
      unawaited(_refreshVisibleCells());
    }

    // La rivendicazione delle celle invece resta protetta dal filtro di
    // accuratezza: un fix rumoroso non deve intaccare la proprietà reale
    // di un esagono, anche se può muovere la camera di qualche metro senza
    // conseguenze — stesso principio di TripLiveController._onPosition
    // applicato a distanza/velocità.
    final accuracy = position.accuracy;
    if (accuracy.isFinite && accuracy > _kMinGpsAccuracyM) return;

    if (cell != _lastClaimedCell) {
      _lastClaimedCell = cell;
      if (!_pendingClaims.contains(cell)) _pendingClaims.add(cell);
    }

    if (_pendingClaims.length >= 6) {
      unawaited(_flushClaims());
    }
  }

  Future<void> _refreshVisibleCells() async {
    final focus = state.focus;
    if (focus == null) return;
    try {
      final cells = await ref.read(territoryRepositoryProvider).cellsNear(
            focus: focus,
            cols: _kViewCols,
            rows: _kViewRows,
          );
      state = state.copyWith(
        visibleCells: {for (final c in cells) c.coord.key: c},
      );
    } catch (_) {
      // Mappa non aggiornata per un errore di rete transitorio: la prossima
      // variazione di cella riprova da sola, nessuno stato di errore da
      // propagare (il claim resta comunque valido lato server).
    }
  }

  Future<void> _flushClaims() async {
    if (_pendingClaims.isEmpty) return;
    final batch = List<HexCoord>.of(_pendingClaims);
    _pendingClaims.clear();
    try {
      final result =
          await ref.read(territoryRepositoryProvider).claimCells(batch);
      state = state.copyWith(session: state.session + result);
      unawaited(_refreshVisibleCells());
      final userId = ref.read(authStateProvider).valueOrNull?.id;
      if (userId != null) unawaited(_refreshMyCellCount(userId));
    } catch (_) {
      // Riprova al prossimo tick: nessuna cella persa per un errore di
      // rete transitorio.
      _pendingClaims.insertAll(0, batch);
    }
  }

  Future<void> _refreshMyCellCount(String userId) async {
    try {
      final count =
          await ref.read(territoryRepositoryProvider).myCellCount(userId);
      state = state.copyWith(myCellCount: count);
    } catch (_) {
      // Il badge area resta al valore precedente finché non riesce un
      // prossimo refresh (dopo il prossimo claim).
    }
  }

  void setMapMode(GameMapMode mode) => state = state.copyWith(mapMode: mode);

  void setPanelTab(TerritoryMetric tab) =>
      state = state.copyWith(panelTab: tab);

  void setScope(TerritoryScope scope) => state = state.copyWith(scope: scope);

  void togglePanel() =>
      state = state.copyWith(panelExpanded: !state.panelExpanded);

  void setPanelExpanded(bool expanded) =>
      state = state.copyWith(panelExpanded: expanded);
}
