// Test minimi Car Spotting: feed costruibile con provider mockati, e
// CarSpottingController.publishSpot con un repository fake (nessuna
// chiamata Supabase reale). imageCompressorProvider viene sovrascritto:
// flutter_image_compress non ha un'implementazione per ogni piattaforma
// (es. Windows desktop, dove girano questi test) e lancerebbe
// UnimplementedError prima ancora di toccare un platform channel.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hrr_app/features/auth/domain/entities/app_user.dart';
import 'package:hrr_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:image_picker/image_picker.dart';

import 'package:hrr_app/features/car_spotting/domain/entities/spot.dart';
import 'package:hrr_app/features/car_spotting/domain/entities/spot_comment.dart';
import 'package:hrr_app/features/car_spotting/domain/entities/spot_rating.dart';
import 'package:hrr_app/features/car_spotting/domain/repositories/car_spotting_repository.dart';
import 'package:hrr_app/features/car_spotting/presentation/providers/car_spotting_controller.dart';
import 'package:hrr_app/features/car_spotting/presentation/providers/car_spotting_provider.dart';
import 'package:hrr_app/features/car_spotting/presentation/screens/car_spotting_feed_screen.dart';

final _now = DateTime.now();

Spot _spot({
  String id = 's1',
  String make = 'BMW',
  String model = 'M3 E46',
  double averageRating = 4.8,
  int ratingCount = 12,
}) {
  return Spot(
    id: id,
    authorId: 'user-1',
    authorUsername: 'leo',
    photoUrl: 'https://example.com/photo.jpg',
    detectedMake: make,
    detectedModel: model,
    averageRating: averageRating,
    ratingCount: ratingCount,
    createdAt: _now,
  );
}

/// Repository fake — copre publishSpot (unico metodo esercitato dal test
/// del controller) e implementa il resto in modo banale per soddisfare
/// l'interfaccia.
class _FakeCarSpottingRepository implements CarSpottingRepository {
  Map<String, dynamic>? lastPublishArgs;

  @override
  Future<Spot> publishSpot({
    required Uint8List photoBytes,
    required String photoExtension,
    required String make,
    required String model,
    int? year,
    String? caption,
    String? locationLabel,
  }) async {
    lastPublishArgs = {
      'make': make,
      'model': model,
      'year': year,
      'caption': caption,
      'locationLabel': locationLabel,
      'photoBytesLength': photoBytes.length,
    };
    return _spot(make: make, model: model, averageRating: 0, ratingCount: 0);
  }

  @override
  Future<List<Spot>> feed({int limit = 30}) async => const [];
  @override
  Future<List<Spot>> topRated({int limit = 20}) async => const [];
  @override
  Future<List<Spot>> byAuthor(String authorId, {int limit = 50}) async =>
      const [];
  @override
  Future<Spot> spotById(String spotId) async => _spot(id: spotId);
  @override
  Future<SpotRating?> myRating(String spotId) async => null;
  @override
  Future<SpotRating> rateSpot(
      {required String spotId, required double rating}) async {
    return SpotRating(
        id: 'r1',
        spotId: spotId,
        profileId: 'user-1',
        rating: rating,
        createdAt: _now,
        updatedAt: _now);
  }

  @override
  Future<List<SpotComment>> comments(String spotId) async => const [];
  @override
  Future<SpotComment> addComment(
      {required String spotId, required String content}) async {
    return SpotComment(
        id: 'c1',
        spotId: spotId,
        authorId: 'user-1',
        content: content,
        createdAt: _now);
  }

  @override
  Future<void> deleteSpot(
      {required String spotId, required String photoUrl}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpFeed(WidgetTester tester, List<Override> overrides) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Evita il vero authRepositoryProvider (Supabase non inizializzato).
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          ...overrides,
        ],
        // Animazioni ridotte: il riflesso della CTA SPOTTA gira all'infinito.
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const CarSpottingFeedScreen(),
        ),
      ),
    );
    // Non pumpAndSettle: lo spinner di CachedNetworkImage anima
    // all'infinito (l'immagine remota fallisce sempre nei test).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('feed HEAT: card con targa, voto e contatori', (tester) async {
    await pumpFeed(tester, [
      spotsFeedProvider.overrideWith((ref) async => [_spot()]),
    ]);

    expect(find.text('SPOTTING'), findsOneWidget);
    expect(find.text('M3 E46'), findsOneWidget);
    expect(find.text('BMW'), findsOneWidget);
    expect(find.text('4,8'), findsOneWidget);
    expect(find.text('@leo'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tab TOP AUTO mostra il rank, empty state a feed vuoto',
      (tester) async {
    await pumpFeed(tester, [
      spotsFeedProvider.overrideWith((ref) async => const []),
      topRatedSpotsProvider.overrideWith((ref) async => [_spot()]),
    ]);
    expect(find.textContaining('nessuno spot ancora'), findsOneWidget);

    await tester.tap(find.text('TOP AUTO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('M3 E46'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
      'CarSpottingController.publishSpot pubblica tramite il repository e ritorna lo spot',
      () async {
    final fakeRepo = _FakeCarSpottingRepository();
    final container = ProviderContainer(overrides: [
      carSpottingRepositoryProvider.overrideWithValue(fakeRepo),
      imageCompressorProvider
          .overrideWithValue((bytes) async => Uint8List.fromList([1, 2, 3])),
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          const AppUser(
            id: 'user-1',
            username: 'leo',
            displayName: 'Leo',
            level: 1,
            xp: 0,
            rep: 0,
            title: 'Rookie',
          ),
        ),
      ),
    ]);
    addTearDown(container.dispose);

    // Un listener permanente tiene vivo authStateProvider (autoDispose):
    // senza, verrebbe scartato subito dopo il primo `read` e il controller
    // lo ritroverebbe ricreato da zero (AsyncLoading, valueOrNull null).
    container.listen(authStateProvider, (_, __) {});
    await container.read(authStateProvider.future);

    final photo = XFile.fromData(Uint8List.fromList([0, 1, 2, 3]),
        name: 'test.jpg', mimeType: 'image/jpeg');

    final result = await container
        .read(carSpottingControllerProvider.notifier)
        .publishSpot(
          photo: photo,
          make: 'Ferrari',
          model: 'F40',
          year: 1992,
        );

    expect(result, isNotNull);
    expect(result!.detectedMake, 'Ferrari');
    expect(fakeRepo.lastPublishArgs?['make'], 'Ferrari');
    expect(fakeRepo.lastPublishArgs?['model'], 'F40');
    expect(fakeRepo.lastPublishArgs?['year'], 1992);
    expect(container.read(carSpottingControllerProvider),
        const AsyncValue<void>.data(null));
  });
}
