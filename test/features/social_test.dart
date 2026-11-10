// Amici, profilo amico, sfide 1 vs 1 e "La tua settimana" con un
// repository finto (nessuna chiamata Supabase).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hrr_app/features/auth/domain/entities/app_user.dart';
import 'package:hrr_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:hrr_app/features/social/data/social_repository.dart';
import 'package:hrr_app/features/social/domain/social_models.dart';
import 'package:hrr_app/features/social/presentation/screens/challenges_screen.dart';
import 'package:hrr_app/features/social/presentation/screens/friend_profile_screen.dart';
import 'package:hrr_app/features/social/presentation/screens/friends_screen.dart';
import 'package:hrr_app/features/social/presentation/screens/week_screen.dart';
import 'package:hrr_app/features/social/presentation/social_providers.dart';
import 'package:hrr_app/features/trip/domain/entities/trip.dart';

AppUser _user(String id, String name, {int level = 5}) => AppUser(
      id: id,
      username: name,
      displayName: name,
      level: level,
      xp: 0,
      rep: 0,
      title: '',
      mascotId: 'volt',
      vehicleBrand: 'Fiat',
      vehicleModel: 'Panda',
      totalKm: 120,
      totalTrips: 9,
    );

final _me = _user('me', 'leo');
final _now = DateTime.now();

Challenge _ch(String id, ChallengeStatus status,
        {String challenger = 'me',
        String opponent = 'a',
        num cs = 0,
        num os = 0,
        String? winner,
        DateTime? endsAt}) =>
    Challenge(
      id: id,
      challengerId: challenger,
      opponentId: opponent,
      metric: ChallengeMetric.km,
      durationHours: 24,
      stakeXp: 250,
      status: status,
      createdAt: _now.subtract(const Duration(hours: 2)),
      acceptedAt: _now.subtract(const Duration(hours: 1)),
      endsAt: endsAt ?? _now.add(const Duration(hours: 5)),
      challengerScore: cs,
      opponentScore: os,
      winnerId: winner,
    );

class _FakeRepo implements SocialRepository {
  _FakeRepo(this.challenges);

  List<Challenge> challenges;
  final calls = <String>[];

  @override
  Future<List<Friend>> friends(String me) async => [
        Friend(user: _user('a', 'ale', level: 9), lastSeenAt: _now),
        Friend(
            user: _user('b', 'bea'),
            lastSeenAt: _now.subtract(const Duration(hours: 3))),
      ];

  @override
  Future<List<Challenge>> myChallenges() async => challenges;

  @override
  Future<void> createChallenge({
    required String opponentId,
    required ChallengeMetric metric,
    required int durationHours,
    required int stakeXp,
  }) async =>
      calls.add('create $opponentId ${metric.api} $durationHours $stakeXp');

  @override
  Future<void> respondChallenge(String id, {required bool accept}) async {
    calls.add('respond $id $accept');
    challenges = [
      for (final c in challenges)
        if (c.id != id) c,
    ];
  }

  @override
  Future<void> cancelChallenge(String id) async => calls.add('cancel $id');

  @override
  Future<void> touchLastSeen() async {}

  @override
  Future<List<Trip>> tripsOf(String profileId,
          {DateTime? since, int limit = 30, bool withRoute = false}) async =>
      const [];

  @override
  Future<List<XpRank>> xpRanking(DateTime from, DateTime to) async => const [];

  @override
  Future<({int got, int lost})> territoryBetween(
          String me, DateTime from, DateTime to) async =>
      (got: 7, lost: 2);
}

Widget _app(_FakeRepo repo, GoRouter router) => ProviderScope(
      overrides: [
        socialRepositoryProvider.overrideWithValue(repo),
        authStateProvider.overrideWith((ref) => Stream.value(_me)),
        myProfileProvider.overrideWith((ref) => Stream.value(_me)),
        drivingNowProvider.overrideWithValue({'b'}),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    );

GoRouter _router(Widget home) => GoRouter(routes: [
      GoRoute(path: '/', builder: (c, s) => home),
      GoRoute(
          path: '/friends/:profileId',
          builder: (c, s) =>
              FriendProfileScreen(profileId: s.pathParameters['profileId']!)),
      GoRoute(
          path: '/home',
          builder: (c, s) => const Scaffold(body: Text('HOME-OK'))),
    ]);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('stato amico e etichette tempo', () {
    final f = Friend(user: _me, lastSeenAt: _now);
    expect(friendStatus(f, driving: true, now: _now).label, 'IN GUIDA');
    expect(friendStatus(f, driving: false, now: _now).label, 'ONLINE');
    expect(agoLabel(_now.subtract(const Duration(hours: 3)), _now), '3 H FA');
    expect(timeLeftLabel(_now.add(const Duration(hours: 5, minutes: 3)), _now),
        '5 H 3 MIN');
    final rec = recordOf([
      _ch('1', ChallengeStatus.finished, winner: 'me'),
      _ch('2', ChallengeStatus.finished, winner: 'a'),
      _ch('3', ChallengeStatus.finished),
    ], 'me');
    expect((rec.won, rec.lost), (1, 1));
  });

  test('riepilogo settimana', () {
    final from = weekStart(DateTime(2026, 11, 12, 15));
    expect(from, DateTime(2026, 11, 9));
    expect(weekRangeLabel(from), '9 – 15 NOV');
    Trip trip(int day, int hour, double km, int flow) => Trip(
          id: '$day$hour',
          driverId: 'me',
          startedAt: DateTime(2026, 11, day, hour),
          distanceKm: km,
          durationSeconds: 1800,
          xpEarned: 0,
          repEarned: 0,
          drivingScore: flow,
          status: TripStatus.completed,
        );
    final w = buildWeekRecap(
      from: from,
      to: DateTime(2026, 11, 12, 15),
      me: 'me',
      trips: [trip(11, 23, 12.5, 80), trip(10, 9, 7.5, 91), trip(5, 9, 99, 99)],
      territory: (got: 4, lost: 1),
      rankingBefore: const [XpRank('a', 900), XpRank('me', 500)],
      rankingNow: const [XpRank('me', 700), XpRank('a', 300)],
      challenges: const [],
    );
    expect(w.trips, 2);
    expect(w.km, 20);
    expect(w.nightTrips, 1);
    expect(w.best?.drivingScore, 91);
    expect((w.rankBefore, w.rankNow, w.xp), (2, 1, 700));
  });

  testWidgets('amici: lista, stati e profilo amico', (tester) async {
    _phone(tester);
    final repo = _FakeRepo([
      _ch('done', ChallengeStatus.finished,
          cs: 30, os: 10, winner: 'me', endsAt: _now),
    ]);
    await tester.pumpWidget(_app(repo, _router(const FriendsScreen())));
    await _settle(tester);

    expect(find.text('AMICI'), findsOneWidget);
    expect(find.text('@ale'), findsOneWidget);
    expect(find.text('ONLINE'), findsOneWidget);
    expect(find.text('IN GUIDA'), findsOneWidget); // bea, dal canale live
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('@ale'));
    await _settle(tester);
    expect(find.text('IL SUO PILOTA'), findsOneWidget);
    expect(find.text('SFIDA @ALE'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('VINTA'), 200,
        scrollable: find
            .descendant(
                of: find.byType(FriendProfileScreen),
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('VINTA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sfide: ricevute, in corso, nuova sfida', (tester) async {
    _phone(tester);
    final repo = _FakeRepo([
      _ch('in', ChallengeStatus.pending, challenger: 'b', opponent: 'me'),
      _ch('live', ChallengeStatus.active, cs: 42.5, os: 12),
    ]);
    await tester.pumpWidget(_app(repo, _router(const ChallengesScreen())));
    await _settle(tester);

    expect(find.text('@bea'), findsNothing); // nome nel Text.rich
    expect(find.text('KM · 24 H · 250 XP'), findsOneWidget);
    expect(find.text('stai vincendo'), findsOneWidget);
    expect(find.text('42,5'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('ACCETTA'));
    await _settle(tester);
    expect(repo.calls, contains('respond in true'));
    expect(find.text('ACCETTA'), findsNothing);

    await tester.tap(find.text('NUOVA SFIDA'));
    await _settle(tester);
    expect(find.text('SCEGLI UN AMICO'), findsOneWidget);
    await tester.tap(find.text('ale'));
    await tester.tap(find.text('500 XP'));
    await tester.pump();
    await tester.tap(find.text('SFIDA @ALE'));
    await _settle(tester);
    expect(repo.calls, contains('create a flow 24 500'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('settimana: slide e chiusura in strada', (tester) async {
    _phone(tester);
    await tester
        .pumpWidget(_app(_FakeRepo(const []), _router(const WeekScreen())));
    await _settle(tester);

    expect(find.text('HAI GUIDATO'), findsOneWidget);
    expect(
        find.text('ancora nessuna guida questa settimana. la strada aspetta.'),
        findsOneWidget);
    for (var i = 0; i < 2; i++) {
      await tester.tapAt(const Offset(300, 400));
      await tester.pump();
    }
    expect(find.text('TERRITORIO'), findsOneWidget);
    expect(find.text('+5'), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      await tester.tapAt(const Offset(300, 400));
      await tester.pump();
    }
    expect(find.text('LA GUIDA MIGLIORE'), findsOneWidget);
    await tester.tap(find.text('IN STRADA'));
    await _settle(tester);
    expect(find.text('HOME-OK'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
