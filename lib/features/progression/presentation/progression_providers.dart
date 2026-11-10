import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/providers/auth_provider.dart';
import '../../missions/domain/entities/mission.dart';
import '../../missions/presentation/providers/mission_provider.dart';
import '../../rival/presentation/providers/active_mascot_provider.dart';
import '../../trip/domain/driver_archetype.dart';
import '../../trip/presentation/providers/trip_provider.dart';
import '../domain/progression.dart';

/// Livello + avanzamento dagli XP totali del profilo (curva HEAT).
final levelProgressProvider = Provider<LevelProgress?>((ref) {
  final xp = ref.watch(myProfileProvider).valueOrNull?.xp;
  return xp == null ? null : levelProgressFromTotalXp(xp);
});

/// Orari di partenza dello storico, dal più vecchio.
final _tripStartsOldestFirstProvider = Provider<List<DateTime>>((ref) {
  final trips = ref.watch(recentTripsProvider).valueOrNull ?? const [];
  return [for (final t in trips.reversed) t.startedAt];
});

/// HEAT 1..5 ricostruito dalle ultime guide (VOLT: ±2 a guida).
final heatProvider = Provider<int>((ref) {
  final volt = ref.watch(activeMascotProvider).id == 'volt';
  return heatFromTripStarts(ref.watch(_tripStartsOldestFirstProvider),
      volt: volt);
});

/// Serie di giorni consecutivi con almeno una guida.
final streakProvider = Provider<int>((ref) {
  return streakDays(ref.watch(_tripStartsOldestFirstProvider), DateTime.now());
});

/// "Che pilota sei": storico abbinamenti dei viaggi recenti.
final pilotHistoryProvider = Provider<PilotHistory>((ref) {
  final trips = ref.watch(recentTripsProvider).valueOrNull ?? const [];
  return buildPilotHistory(archetypesOf(trips));
});

/// Missioni di oggi: (completate, totali). `null` finché non arrivano.
final todayMissionsProvider = Provider<({int done, int total})?>((ref) {
  final missions =
      ref.watch(activeMissionsProvider(type: MissionType.daily)).valueOrNull;
  if (missions == null) return null;
  final progress = ref.watch(myMissionProgressProvider).valueOrNull ?? const [];
  final ids = {for (final m in missions) m.id};
  final done =
      progress.where((p) => p.completed && ids.contains(p.missionId)).length;
  return (done: done, total: missions.length);
});
