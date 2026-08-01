import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/events/mission_event.dart';
import '../../../../core/events/mission_event_bus.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/trip.dart';
import 'trip_provider.dart';

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

  const TripLiveState({
    this.status = TripLiveStatus.idle,
    this.tripId,
    this.elapsed = Duration.zero,
    this.distanceKm = 0,
    this.currentSpeedKmh = 0,
    this.maxSpeedKmh = 0,
    this.errorMessage,
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
  }) {
    return TripLiveState(
      status: status ?? this.status,
      tripId: tripId ?? this.tripId,
      elapsed: elapsed ?? this.elapsed,
      distanceKm: distanceKm ?? this.distanceKm,
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      errorMessage: errorMessage,
    );
  }
}

/// Punto leggero della rotta percorsa, usato solo per l'anteprima grafica
/// di fine viaggio (non è la geometria PostGIS salvata lato server).
class RoutePoint {
  final double lat;
  final double lng;
  const RoutePoint(this.lat, this.lng);
}

/// Payload passato a TripSummaryScreen via `extra` di GoRouter: il
/// controller resetta il proprio stato subito dopo aver finito la corsa,
/// quindi la schermata riceve uno snapshot invece di rileggerlo da un
/// provider che nel frattempo è già tornato a idle.
class TripSummary {
  final Trip trip;
  final List<RoutePoint> routePoints;
  const TripSummary({required this.trip, required this.routePoints});
}

@riverpod
class TripLiveController extends _$TripLiveController {
  StreamSubscription<Position>? _positionSub;
  Timer? _ticker;
  Position? _lastPosition;
  final List<RoutePoint> _points = [];
  DateTime? _startedAt;
  String? _tripId;

  @override
  TripLiveState build() {
    ref.onDispose(() {
      _positionSub?.cancel();
      _ticker?.cancel();
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
    _points.clear();

    state = TripLiveState(status: TripLiveStatus.tracking, tripId: trip.id);

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = _startedAt;
      if (startedAt != null) {
        state = state.copyWith(elapsed: DateTime.now().difference(startedAt));
      }
    });

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen(_onPosition);
  }

  void _onPosition(Position position) {
    var distanceKm = state.distanceKm;
    final last = _lastPosition;
    if (last != null) {
      final meters = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        position.latitude,
        position.longitude,
      );
      // Filtra il jitter GPS da fermo: sotto i 3m è rumore, non movimento.
      if (meters > 3) {
        distanceKm += meters / 1000;
      }
    }
    _lastPosition = position;

    _points.add(RoutePoint(position.latitude, position.longitude));
    if (_points.length > 1000) {
      final thinned = <RoutePoint>[
        for (var i = 0; i < _points.length; i += 2) _points[i]
      ];
      _points
        ..clear()
        ..addAll(thinned);
    }

    final speedKmh = (position.speed.isFinite && position.speed > 0)
        ? position.speed * 3.6
        : 0.0;
    state = state.copyWith(
      distanceKm: distanceKm,
      currentSpeedKmh: speedKmh,
      maxSpeedKmh: speedKmh > state.maxSpeedKmh ? speedKmh : state.maxSpeedKmh,
    );
  }

  Future<TripSummary?> finishTrip() async {
    final tripId = _tripId;
    if (tripId == null) return null;

    await _positionSub?.cancel();
    _ticker?.cancel();
    state = state.copyWith(status: TripLiveStatus.finishing);

    final finished = await ref.read(tripRepositoryProvider).completeTrip(
          tripId: tripId,
          distanceKm: state.distanceKm,
          durationSeconds: state.elapsed.inSeconds,
          avgSpeedKmh: state.avgSpeedKmh,
          maxSpeedKmh: state.maxSpeedKmh,
        );

    final summary =
        TripSummary(trip: finished, routePoints: List.unmodifiable(_points));

    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId != null && finished.distanceKm > 0) {
      ref.read(missionEventBusProvider).publish(
            TripCompleted(profileId: userId, distanceKm: finished.distanceKm),
          );
    }

    ref.invalidate(recentTripsProvider);
    _reset();
    return summary;
  }

  Future<void> discardTrip() async {
    final tripId = _tripId;
    await _positionSub?.cancel();
    _ticker?.cancel();
    if (tripId != null) {
      await ref.read(tripRepositoryProvider).discardTrip(tripId);
    }
    _reset();
  }

  void _reset() {
    _tripId = null;
    _startedAt = null;
    _lastPosition = null;
    _points.clear();
    state = const TripLiveState();
  }
}
