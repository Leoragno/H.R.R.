import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_provider.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../trip/domain/driver_archetype.dart';
import '../../trip/domain/entities/trip.dart';
import '../../trip/presentation/providers/live_map_provider.dart';
import '../data/social_repository.dart';
import '../domain/social_models.dart';

// Provider "normali" (niente codegen: build_runner è rotto sul progetto).

final socialRepositoryProvider = Provider<SocialRepository>(
    (ref) => SupabaseSocialRepository(ref.watch(supabaseClientProvider)));

final _myIdProvider =
    Provider<String?>((ref) => ref.watch(authStateProvider).valueOrNull?.id);

final friendsProvider = FutureProvider.autoDispose<List<Friend>>((ref) async {
  final me = ref.watch(_myIdProvider);
  if (me == null) return const [];
  return ref.watch(socialRepositoryProvider).friends(me);
});

final friendProvider = Provider.autoDispose.family<Friend?, String>((ref, id) {
  final list = ref.watch(friendsProvider).valueOrNull ?? const <Friend>[];
  for (final f in list) {
    if (f.id == id) return f;
  }
  return null;
});

/// Profili in guida adesso (canale realtime "drivers-live").
final drivingNowProvider = Provider.autoDispose<Set<String>>(
    (ref) => ref.watch(liveMapControllerProvider).keys.toSet());

final friendTripsProvider = FutureProvider.autoDispose
    .family<List<Trip>, String>((ref, id) =>
        ref.watch(socialRepositoryProvider).tripsOf(id, limit: 30));

/// Pilota principale di un amico, dalle sue ultime guide.
final friendPilotProvider =
    Provider.autoDispose.family<PilotHistory, String>((ref, id) {
  final trips = ref.watch(friendTripsProvider(id)).valueOrNull ?? const [];
  return buildPilotHistory(archetypesOf(trips));
});

class ChallengesController extends AutoDisposeAsyncNotifier<List<Challenge>> {
  SocialRepository get _repo => ref.read(socialRepositoryProvider);

  @override
  Future<List<Challenge>> build() =>
      ref.watch(socialRepositoryProvider).myChallenges();

  Future<void> _then(Future<void> Function() op) async {
    await op();
    state = AsyncData(await _repo.myChallenges());
  }

  Future<void> create({
    required String opponentId,
    required ChallengeMetric metric,
    required int durationHours,
    required int stakeXp,
  }) =>
      _then(() => _repo.createChallenge(
            opponentId: opponentId,
            metric: metric,
            durationHours: durationHours,
            stakeXp: stakeXp,
          ));

  Future<void> respond(String id, {required bool accept}) =>
      _then(() => _repo.respondChallenge(id, accept: accept));

  Future<void> cancel(String id) => _then(() => _repo.cancelChallenge(id));
}

final challengesProvider =
    AsyncNotifierProvider.autoDispose<ChallengesController, List<Challenge>>(
        ChallengesController.new);

/// Messaggio leggibile per gli errori delle RPC delle sfide.
String challengeErrorText(Object e) {
  final s = e.toString();
  if (s.contains('too_many_open_challenges')) {
    return 'hai già 3 sfide aperte. chiudine una prima.';
  }
  if (s.contains('challenge_already_open')) {
    return 'avete già una sfida aperta.';
  }
  if (s.contains('challenge_not_pending')) return 'la sfida non è più valida.';
  return 'qualcosa è andato storto. riprova.';
}

/// Riepilogo della settimana in corso (lunedì 00:00 → adesso).
class WeekRecap {
  const WeekRecap({
    required this.from,
    required this.to,
    required this.km,
    required this.trips,
    required this.hours,
    required this.nightTrips,
    required this.pilot,
    required this.pilotCount,
    required this.hexGot,
    required this.hexLost,
    required this.rankBefore,
    required this.rankNow,
    required this.xp,
    required this.challengesPlayed,
    required this.challengesWon,
    required this.best,
  });

  final DateTime from;
  final DateTime to;
  final double km;
  final int trips;
  final double hours;
  final int nightTrips;
  final DriverArchetype? pilot;
  final int pilotCount;
  final int hexGot;
  final int hexLost;
  final int? rankBefore;
  final int? rankNow;
  final int xp;
  final int challengesPlayed;
  final int challengesWon;
  final Trip? best;
}

DateTime weekStart(DateTime now) {
  final d = DateTime(now.year, now.month, now.day);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

bool _isNight(DateTime t) => t.hour >= 22 || t.hour < 6;

/// Costruisce il riepilogo dai dati grezzi (puro, testabile).
WeekRecap buildWeekRecap({
  required DateTime from,
  required DateTime to,
  required String me,
  required List<Trip> trips,
  required ({int got, int lost}) territory,
  required List<XpRank> rankingBefore,
  required List<XpRank> rankingNow,
  required List<Challenge> challenges,
}) {
  final week = [
    for (final t in trips)
      if (!t.startedAt.isBefore(from) && t.startedAt.isBefore(to)) t,
  ];
  final pilots = archetypesOf(week);
  final tally = <DriverArchetype, int>{};
  for (final a in pilots) {
    tally[a] = (tally[a] ?? 0) + 1;
  }
  final top = tally.entries.isEmpty
      ? null
      : (tally.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .first;
  Trip? best;
  for (final t in week) {
    if ((t.drivingScore ?? -1) > (best?.drivingScore ?? -1)) best = t;
  }
  final done = [
    for (final c in challenges)
      if (c.status == ChallengeStatus.finished &&
          c.endsAt != null &&
          !c.endsAt!.isBefore(from))
        c,
  ];
  final mine = rankingNow.where((r) => r.profileId == me);
  return WeekRecap(
    from: from,
    to: to,
    km: week.fold(0.0, (s, t) => s + t.distanceKm),
    trips: week.length,
    hours: week.fold(0, (s, t) => s + t.durationSeconds) / 3600,
    nightTrips: week.where((t) => _isNight(t.startedAt)).length,
    pilot: top?.key,
    pilotCount: top?.value ?? 0,
    hexGot: territory.got,
    hexLost: territory.lost,
    rankBefore: positionOf(rankingBefore, me),
    rankNow: positionOf(rankingNow, me),
    xp: mine.isEmpty ? 0 : mine.first.xp,
    challengesPlayed: done.length,
    challengesWon:
        done.where((c) => c.outcomeFor(me) == ChallengeOutcome.won).length,
    best: best,
  );
}

final weekRecapProvider = FutureProvider.autoDispose<WeekRecap?>((ref) async {
  final me = ref.watch(_myIdProvider);
  if (me == null) return null;
  final repo = ref.watch(socialRepositoryProvider);
  final now = DateTime.now();
  final from = weekStart(now);
  final prevFrom = from.subtract(const Duration(days: 7));

  final trips =
      await repo.tripsOf(me, since: from, limit: 100, withRoute: true);
  final territory = await repo.territoryBetween(me, from, now);
  // Classifica e sfide arrivano da 0039: se non è ancora applicata il
  // riepilogo esce lo stesso, senza quelle due slide piene.
  List<XpRank> before = const [], current = const [];
  List<Challenge> challenges = const [];
  try {
    before = await repo.xpRanking(prevFrom, from);
    current = await repo.xpRanking(from, now);
    challenges = await repo.myChallenges();
  } catch (_) {}
  return buildWeekRecap(
    from: from,
    to: now,
    me: me,
    trips: trips,
    territory: territory,
    rankingBefore: before,
    rankingNow: current,
    challenges: challenges,
  );
});
