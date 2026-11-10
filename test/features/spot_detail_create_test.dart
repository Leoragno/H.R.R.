// Smoke test Spotting HEAT: dettaglio (hero, voto, commenti, niente voto
// sui propri spot) e nuovo spot (validazione del primo step).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hrr_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:hrr_app/features/car_spotting/domain/entities/spot.dart';
import 'package:hrr_app/features/car_spotting/domain/entities/spot_comment.dart';
import 'package:hrr_app/features/car_spotting/presentation/providers/car_spotting_provider.dart';
import 'package:hrr_app/features/car_spotting/presentation/screens/create_spot_screen.dart';
import 'package:hrr_app/features/car_spotting/presentation/screens/spot_detail_screen.dart';

final _now = DateTime.now();

final _spot = Spot(
  id: 's1',
  authorId: 'other',
  authorUsername: 'luca',
  photoUrl: '',
  detectedMake: 'Alfa Romeo',
  detectedModel: 'Giulia QV',
  detectedYear: 2017,
  locationLabel: 'Milano',
  averageRating: 4.25,
  ratingCount: 4,
  createdAt: _now.subtract(const Duration(hours: 3)),
);

Widget _app(Widget home, List<Override> overrides) => ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        ...overrides,
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: home,
      ),
    );

void main() {
  testWidgets('dettaglio spot: hero, voto medio, commenti', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const SpotDetailScreen(spotId: 's1'), [
      spotByIdProvider('s1').overrideWith((ref) async => _spot),
      myRatingForSpotProvider('s1').overrideWith((ref) async => null),
      spotCommentsProvider('s1').overrideWith((ref) async => [
            SpotComment(
              id: 'c1',
              spotId: 's1',
              authorId: 'x',
              authorUsername: 'giulia',
              content: 'che bestia',
              createdAt: _now,
            ),
          ]),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('GIULIA QV'), findsOneWidget);
    expect(find.text('ALFA ROMEO · 2017'), findsOneWidget);
    expect(find.text('4,3'), findsOneWidget);
    expect(find.text('tocca una stella'), findsOneWidget);
    expect(find.text('che bestia'), findsOneWidget);
    // Non è mio: niente cestino.
    expect(find.byIcon(Icons.delete_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nuovo spot: senza foto AVANTI mostra l\'errore', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const CreateSpotScreen(), const []));
    await tester.pump();

    expect(find.text('NUOVO SPOT'), findsOneWidget);
    await tester.tap(find.text('AVANTI'));
    await tester.pump();
    expect(find.textContaining('scatta o scegli una foto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
