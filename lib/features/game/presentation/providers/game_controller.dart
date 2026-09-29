import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/territory_cell.dart';
import '../../domain/entities/territory_standing.dart';
import '../../domain/hex_grid.dart';
import 'territory_provider.dart';

part 'game_controller.g.dart';

/// I 2 modi di colorazione della mappa (mockup: "Giocatore singolo" /
/// "La mia mappa").
enum GameMapMode {
  solo,
  mineOnly;

  String get label => switch (this) {
        GameMapMode.solo => 'Giocatore singolo',
        GameMapMode.mineOnly => 'La mia mappa',
      };
}

enum GameGpsStatus { idle, requesting, tracking, denied, disabled }

class GameState {
  final GameMapMode mapMode;
  final TerritoryMetric panelTab;
  final bool panelExpanded;
  final HexCoord? focus;
  // Posizione reale (non arrotondata a cella) dell'ultimo fix GPS, usata
  // solo per centrare la mappa vera sotto la griglia esagonale — il
  // gioco in sé ragiona esclusivamente in HexCoord.
  final double? focusLat;
  final double? focusLon;
  final Map<String, TerritoryCell> visibleCells;
  final int myCellCount;
  final GameGpsStatus gpsStatus;

  const GameState({
    this.mapMode = GameMapMode.solo,
    this.panelTab = TerritoryMetric.general,
    this.panelExpanded = false,
    this.focus,
    this.focusLat,
    this.focusLon,
    this.visibleCells = const {},
    this.myCellCount = 0,
    this.gpsStatus = GameGpsStatus.idle,
  });

  GameState copyWith({
    GameMapMode? mapMode,
    TerritoryMetric? panelTab,
    bool? panelExpanded,
    HexCoord? focus,
    double? focusLat,
    double? focusLon,
    Map<String, TerritoryCell>? visibleCells,
    int? myCellCount,
    GameGpsStatus? gpsStatus,
  }) {
    return GameState(
      mapMode: mapMode ?? this.mapMode,
      panelTab: panelTab ?? this.panelTab,
      panelExpanded: panelExpanded ?? this.panelExpanded,
      focus: focus ?? this.focus,
      focusLat: focusLat ?? this.focusLat,
      focusLon: focusLon ?? this.focusLon,
      visibleCells: visibleCells ?? this.visibleCells,
      myCellCount: myCellCount ?? this.myCellCount,
      gpsStatus: gpsStatus ?? this.gpsStatus,
    );
  }

  double areaKm2() => myCellCount * HexGrid.cellAreaKm2();
}

// Finestra (in celle) attorno al focus per cui si interrogano le celle
// possedute — abbastanza larga da riempire lo schermo alla mappa reale.
const _kViewCols = 20;
const _kViewRows = 34;
// Tetto della finestra quando l'utente allontana lo zoom (~15×13 km):
// oltre, gli esagoni sono comunque puntini e la query diventerebbe
// l'intera tabella.
const _kMaxViewCols = 100;
const _kMaxViewRows = 100;
// Margine (in celle) oltre il bordo visibile: un piccolo pan non deve
// scoprire subito una fascia vuota in attesa della prossima query.
const _kViewMarginCells = 4;

// Fix troppo impreciso (tunnel, garage, edifici alti): scartato prima di
// spostare il focus della mappa.
const _kMinGpsAccuracyM = 25.0;

/// Stato di sola lettura della mappa territorio: mostra le celle
/// possedute e la propria posizione, ma non rivendica più nulla in
/// autonomia. L'acquisizione delle celle avviene esclusivamente durante
/// una guida registrata (vedi TripLiveController.finishTrip, che chiama
/// claimCells col punteggio di guida finale — 0026_territory_decay_
/// counterattack.sql) — nessun tracking GPS ambientale/di fondo qui, solo
/// un fix quando la schermata Gioca è aperta (niente più foreground
/// service "sta tracciando la tua conquista territorio": non c'è più
/// nulla da tracciare in background).
@riverpod
class GameController extends _$GameController {
  StreamSubscription<void>? _cellsChangedSub;
  Timer? _cellsRefreshDebounce;
  String? _watchedUserId;
  // Distingue un vero cambio di sessione (login/logout/altro utente) da
  // una riemissione di onAuthStateChange a utente invariato (es.
  // TOKEN_REFRESHED, che Supabase spara periodicamente): solo il primo
  // deve resettare lo stato/riavviare il watch delle celle.
  String? _trackedUserId;
  // Finestra attualmente inquadrata dalla mappa (vedi [onViewportChanged]):
  // null finché la camera non si è mai fermata, e allora si usa il focus
  // GPS. Senza questa, spostando la mappa verso territori lontani dalla
  // propria posizione non comparivano mai (restava la finestra del GPS).
  HexCoord? _viewCenter;
  int _viewCols = _kViewCols;
  int _viewRows = _kViewRows;

  @override
  GameState build() {
    ref.onDispose(() {
      _cellsChangedSub?.cancel();
      _cellsRefreshDebounce?.cancel();
    });

    // ref.listen (non ref.watch): un TOKEN_REFRESHED non deve far ripartire
    // build() e quindi resettare visibleCells/focus già caricati. Il
    // callback gira fuori dal frame sincrono di build(), quindi può
    // scrivere su `state` in sicurezza. fireImmediately: prende in carico
    // anche la sessione già attiva al primo avvio.
    ref.listen(authStateProvider, (previous, next) {
      final userId = next.valueOrNull?.id;
      Future.microtask(() => _onAuthChanged(userId));
    }, fireImmediately: true);

    return const GameState();
  }

  void _onAuthChanged(String? userId) {
    if (userId == _trackedUserId) return;
    _trackedUserId = userId;
    _watchedUserId = userId;

    _cellsChangedSub?.cancel();
    _cellsChangedSub = null;

    if (userId == null) {
      state = const GameState();
      return;
    }

    state = const GameState();
    _viewCenter = null;
    unawaited(_refreshMyCellCount(userId));
    unawaited(fetchPosition());
    _watchCellChanges();
  }

  void _watchCellChanges() {
    // I furti/claim altrui devono comparire sulla mappa senza dover
    // riaprire la schermata. Debounced perché lo stream emette un evento
    // per singola cella cambiata: una raffica ravvicinata (un rivale che
    // completa un viaggio attraverso più esagoni) altrimenti scatenerebbe
    // un territory_cells_near per ciascuna.
    _cellsChangedSub?.cancel();
    _cellsChangedSub =
        ref.read(territoryRepositoryProvider).watchCellChanges().listen((_) {
      _cellsRefreshDebounce?.cancel();
      _cellsRefreshDebounce = Timer(
        const Duration(milliseconds: 800),
        () => unawaited(_refreshVisibleCells()),
      );
    });
  }

  /// Fix di posizione one-shot per centrare la mappa — chiamato
  /// all'apertura della schermata Gioca e dal pulsante "Centra". Nessuno
  /// stream continuo: la mappa non deve più seguire il giocatore in
  /// tempo reale fuori da una guida attiva.
  Future<void> fetchPosition() async {
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
      final accuracy = position.accuracy;
      if (accuracy.isFinite && accuracy > _kMinGpsAccuracyM) {
        state = state.copyWith(gpsStatus: GameGpsStatus.tracking);
        return;
      }

      final cell = HexGrid.cellOf(position.latitude, position.longitude);
      final focusChanged = state.focus != cell;
      state = state.copyWith(
        focus: cell,
        focusLat: position.latitude,
        focusLon: position.longitude,
        gpsStatus: GameGpsStatus.tracking,
      );
      if (focusChanged && _viewCenter == null) {
        unawaited(_refreshVisibleCells());
      }
    } catch (_) {
      state = state.copyWith(gpsStatus: GameGpsStatus.tracking);
      // GPS momentaneamente non disponibile: l'utente può ritentare col
      // pulsante "Centra", nessun errore bloccante da mostrare.
    }
  }

  /// Alias esplicito per il pulsante "Centra" della UI.
  Future<void> recenterNow() => fetchPosition();

  /// Chiamato dalla mappa a camera ferma (pan/zoom terminato) coi bordi
  /// dell'area visibile: ricarica le celle di quella zona invece di quella
  /// attorno al GPS.
  void onViewportChanged(
    double southLat,
    double westLon,
    double northLat,
    double eastLon,
  ) {
    final sw = HexGrid.cellOf(southLat, westLon);
    final ne = HexGrid.cellOf(northLat, eastLon);
    final center =
        HexGrid.cellOf((southLat + northLat) / 2, (westLon + eastLon) / 2);
    final needCols = ((ne.q - sw.q).abs() / 2).ceil();
    final needRows = ((ne.r - sw.r).abs() / 2).ceil();
    // Area inquadrata già interamente dentro la finestra caricata (pan
    // piccolo, o zoom in): nessuna nuova query. Il realtime tiene
    // comunque aggiornata la finestra corrente.
    final loaded = _viewCenter;
    if (loaded != null &&
        (center.q - loaded.q).abs() + needCols <= _viewCols &&
        (center.r - loaded.r).abs() + needRows <= _viewRows) {
      return;
    }
    final clampedCols =
        (needCols + _kViewMarginCells).clamp(_kViewCols, _kMaxViewCols);
    final clampedRows =
        (needRows + _kViewMarginCells).clamp(_kViewRows, _kMaxViewRows);
    _viewCenter = center;
    _viewCols = clampedCols;
    _viewRows = clampedRows;
    unawaited(_refreshVisibleCells());
  }

  Future<void> _refreshVisibleCells() async {
    final focus = _viewCenter ?? state.focus;
    if (focus == null) return;
    try {
      final cells = await ref.read(territoryRepositoryProvider).cellsNear(
            focus: focus,
            cols: _viewCols,
            rows: _viewRows,
          );
      // Risposta superata da un pan successivo: la query della nuova
      // finestra è già partita, non sovrascriverla con quella vecchia.
      if (focus != (_viewCenter ?? state.focus)) return;
      state = state.copyWith(
        visibleCells: {for (final c in cells) c.coord.key: c},
      );
    } catch (_) {
      // Mappa non aggiornata per un errore di rete transitorio: il
      // prossimo cambio di focus o evento realtime riprova da solo.
    }
  }

  Future<void> _refreshMyCellCount(String userId) async {
    try {
      final count =
          await ref.read(territoryRepositoryProvider).myCellCount(userId);
      if (_watchedUserId == userId) {
        state = state.copyWith(myCellCount: count);
      }
    } catch (_) {
      // Il badge area resta al valore precedente finché non riesce un
      // prossimo refresh.
    }
  }

  void setMapMode(GameMapMode mode) => state = state.copyWith(mapMode: mode);

  void setPanelTab(TerritoryMetric tab) =>
      state = state.copyWith(panelTab: tab);

  void togglePanel() =>
      state = state.copyWith(panelExpanded: !state.panelExpanded);

  void setPanelExpanded(bool expanded) =>
      state = state.copyWith(panelExpanded: expanded);
}
