import 'dart:math' as math;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../trip/presentation/providers/trip_live_provider.dart';
import '../../domain/entities/radar_bounds.dart';
import '../../domain/entities/radar_event.dart';
import 'radar_provider.dart';

part 'radar_proximity_provider.g.dart';

// Soglia di avviso e cooldown per non ripetere lo stesso avviso in loop
// mentre si resta vicini allo stesso punto (es. traffico fermo).
const _kProximityThresholdMeters = 400.0;
const _kAlertCooldown = Duration(minutes: 3);
// Mezzo lato del riquadro interrogato attorno alla posizione live —
// abbastanza largo da coprire la soglia di prossimità con margine, senza
// interrogare un'area enorme ad ogni fix.
const _kProximityBoxDeg = 0.03; // ~3 km

/// Durante DRIVE, riusa il GPS già live in [tripLiveControllerProvider]
/// (nessun nuovo stream di posizione) per capire se l'utente si sta
/// avvicinando a un Velox/Pattuglia (API o crew) e restituisce l'evento
/// da segnalare — un impulso, non uno stato persistente: [Timer]/durata
/// di visualizzazione dell'avviso restano a carico della UI (vedi
/// RadarAlertBanner), qui c'è solo "quale evento, se c'è, va segnalato ora".
@riverpod
class RadarProximityController extends _$RadarProximityController {
  final Map<String, DateTime> _lastAlertedAt = {};

  @override
  Future<RadarEvent?> build() async {
    if (!ref.watch(radarModeControllerProvider)) return null;

    final tripState = ref.watch(tripLiveControllerProvider);
    if (tripState.status != TripLiveStatus.tracking ||
        tripState.routePoints.isEmpty) {
      return null;
    }
    final here = tripState.routePoints.last;

    final bounds = RadarBounds.quantized(
      south: here.lat - _kProximityBoxDeg,
      west: here.lng - _kProximityBoxDeg,
      north: here.lat + _kProximityBoxDeg,
      east: here.lng + _kProximityBoxDeg,
    );

    final candidates = [
      ...await ref.watch(veloxApiEventsProvider(bounds).future),
      ...await ref.watch(pattugliaApiEventsProvider(bounds).future),
      ...ref.watch(crewVeloxReportsProvider),
      ...ref.watch(crewPattugliaReportsProvider),
    ];

    final now = DateTime.now();
    for (final event in candidates) {
      final distance =
          _distanceMeters(here.lat, here.lng, event.lat, event.lon);
      if (distance > _kProximityThresholdMeters) continue;

      final lastAlert = _lastAlertedAt[event.id];
      if (lastAlert != null && now.difference(lastAlert) < _kAlertCooldown) {
        continue;
      }
      _lastAlertedAt[event.id] = now;
      return event;
    }
    return null;
  }
}

double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusM = 6371000.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degToRad(lat1)) *
          math.cos(_degToRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusM * c;
}

double _degToRad(double deg) => deg * (math.pi / 180);
