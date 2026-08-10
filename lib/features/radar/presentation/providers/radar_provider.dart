import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/crew_reports_remote_datasource.dart';
import '../../data/datasources/overpass_remote_datasource.dart';
import '../../data/datasources/waze_remote_datasource.dart';
import '../../data/repositories/radar_repository_impl.dart';
import '../../domain/entities/radar_bounds.dart';
import '../../domain/entities/radar_event.dart';
import '../../domain/repositories/radar_repository.dart';

part 'radar_provider.g.dart';

// ---- DI wiring ------------------------------------------------------------

@riverpod
OverpassRemoteDatasource overpassRemoteDatasource(
        OverpassRemoteDatasourceRef ref) =>
    OverpassRemoteDatasource(ref.watch(dioProvider));

@riverpod
WazeRemoteDatasource wazeRemoteDatasource(WazeRemoteDatasourceRef ref) =>
    WazeRemoteDatasource(ref.watch(dioProvider));

@riverpod
CrewReportsRemoteDatasource crewReportsRemoteDatasource(
        CrewReportsRemoteDatasourceRef ref) =>
    CrewReportsRemoteDatasource(ref.watch(supabaseClientProvider));

@riverpod
RadarRepository radarRepository(RadarRepositoryRef ref) => RadarRepositoryImpl(
      ref.watch(overpassRemoteDatasourceProvider),
      ref.watch(wazeRemoteDatasourceProvider),
      ref.watch(crewReportsRemoteDatasourceProvider),
    );

// ---- Interruttore della modalità Velox/Pattuglia ---------------------------

const _kRadarModePrefsKey = 'radar_mode_enabled';

/// On/off dell'intera modalità: mappa (marker), card di monitoraggio,
/// segnalazioni di crew e avviso di prossimità durante DRIVE dipendono
/// tutti da questo interruttore, persistito così resta impostato fra un
/// riavvio e l'altro. Da spento, nessuno dei provider sotto fa richieste
/// (rete o realtime) — non è solo un "nascondi la UI".
@Riverpod(keepAlive: true)
class RadarModeController extends _$RadarModeController {
  @override
  bool build() {
    unawaited(_restore());
    return true; // attivo di default finché le preferenze non dicono altro
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_kRadarModePrefsKey);
    if (saved != null) state = saved;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRadarModePrefsKey, state);
  }
}

// ---- Bounding box della mappa Guida ----------------------------------------

/// Ultima bounding box visibile della mappa Guida, aggiornata da
/// [HomeMapBackground] su `onCameraIdle` (già debounced lì). `keepAlive`
/// perché deve restare disponibile anche quando la mappa non è a schermo
/// (es. durante DRIVE, se si vuole comunque il conteggio dell'ultima
/// zona vista) invece di azzerarsi al primo dispose.
@Riverpod(keepAlive: true)
class MapBoundsController extends _$MapBoundsController {
  @override
  RadarBounds? build() => null;

  void update(RadarBounds bounds) {
    if (state == bounds) return;
    state = bounds;
  }
}

// ---- Fonti "API" (bounding box), con cache/debounce nel datasource --------

@riverpod
Future<List<RadarEvent>> veloxApiEvents(
        VeloxApiEventsRef ref, RadarBounds bounds) =>
    ref.watch(radarRepositoryProvider).veloxApi(bounds);

@riverpod
Future<List<RadarEvent>> pattugliaApiEvents(
        PattugliaApiEventsRef ref, RadarBounds bounds) =>
    ref.watch(radarRepositoryProvider).pattugliaApi(bounds);

/// Comodo per la UI (card monitoraggio, mappa Guida): stessa lista di
/// [veloxApiEvents] ma già agganciata alla bounding box corrente, senza
/// che il chiamante debba conoscere/propagare [RadarBounds].
@riverpod
Future<List<RadarEvent>> currentVeloxApiEvents(
    CurrentVeloxApiEventsRef ref) async {
  if (!ref.watch(radarModeControllerProvider)) return const [];
  final bounds = ref.watch(mapBoundsControllerProvider);
  if (bounds == null) return const [];
  return ref.watch(veloxApiEventsProvider(bounds).future);
}

@riverpod
Future<List<RadarEvent>> currentPattugliaApiEvents(
    CurrentPattugliaApiEventsRef ref) async {
  if (!ref.watch(radarModeControllerProvider)) return const [];
  final bounds = ref.watch(mapBoundsControllerProvider);
  if (bounds == null) return const [];
  return ref.watch(pattugliaApiEventsProvider(bounds).future);
}

// ---- Segnalazioni di crew (realtime, scadenza 90 minuti) -------------------

/// Segnalazioni Velox+Pattuglia della crew dell'utente, aggiornate in
/// realtime via Supabase e già private delle voci scadute (90 minuti,
/// vedi [RadarEvent.isExpired]) — sia ad ogni nuovo evento dal DB, sia
/// periodicamente per chi scade "a riposo" senza che nel frattempo
/// arrivi un nuovo insert altrui (stesso principio dello staleness timer
/// di CrewLiveMapController).
@riverpod
class CrewReportsController extends _$CrewReportsController {
  StreamSubscription<List<RadarEvent>>? _sub;
  Timer? _expiryTimer;

  @override
  List<RadarEvent> build() {
    ref.onDispose(_cancel);
    if (!ref.watch(radarModeControllerProvider)) {
      _cancel();
      return const [];
    }
    final crewId = ref.watch(myProfileProvider).valueOrNull?.crewId;
    if (crewId != null) _subscribe(crewId);
    return const [];
  }

  void _subscribe(String crewId) {
    _sub?.cancel();
    _sub = ref.read(radarRepositoryProvider).crewReports(crewId).listen(
      (events) {
        final now = DateTime.now();
        state = events.where((e) => !e.isExpired(now)).toList();
      },
      onError: (_) {
        // Realtime momentaneamente non disponibile: si mantiene l'ultimo
        // stato noto invece di svuotare la lista, nessun errore in UI.
      },
    );

    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final now = DateTime.now();
      final fresh = state.where((e) => !e.isExpired(now)).toList();
      if (fresh.length != state.length) state = fresh;
    });
  }

  void _cancel() {
    _sub?.cancel();
    _sub = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
  }
}

@riverpod
List<RadarEvent> crewVeloxReports(CrewVeloxReportsRef ref) => ref
    .watch(crewReportsControllerProvider)
    .where((e) => e.category == RadarCategory.velox)
    .toList();

@riverpod
List<RadarEvent> crewPattugliaReports(CrewPattugliaReportsRef ref) => ref
    .watch(crewReportsControllerProvider)
    .where((e) => e.category == RadarCategory.pattuglia)
    .toList();

/// Tutti gli eventi da disegnare sulla mappa Guida (le 4 categorie
/// insieme) per la bounding box corrente — unico provider osservato da
/// [HomeMapBackground] per sincronizzare i marker nativi.
@riverpod
Future<List<RadarEvent>> homeMapMarkers(HomeMapMarkersRef ref) async {
  if (!ref.watch(radarModeControllerProvider)) return const [];
  final results = await Future.wait([
    ref.watch(currentVeloxApiEventsProvider.future),
    ref.watch(currentPattugliaApiEventsProvider.future),
  ]);
  return [
    ...results[0],
    ...results[1],
    ...ref.watch(crewVeloxReportsProvider),
    ...ref.watch(crewPattugliaReportsProvider),
  ];
}

// ---- Azioni -----------------------------------------------------------

@riverpod
class RadarActionsController extends _$RadarActionsController {
  @override
  FutureOr<void> build() {
    // no-op initial state
  }

  Future<void> submitReport({
    required RadarCategory category,
    required double lat,
    required double lon,
  }) async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    final crewId = ref.read(myProfileProvider).valueOrNull?.crewId;
    if (userId == null || crewId == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(radarRepositoryProvider).submitCrewReport(
          crewId: crewId,
          reporterId: userId,
          category: category,
          lat: lat,
          lon: lon,
        ));
  }
}
