import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/events/mission_event.dart';
import '../../../../core/events/mission_event_bus.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/spot.dart';
import '../../domain/entities/spot_comment.dart';
import '../../domain/entities/spot_rating.dart';
import 'car_spotting_provider.dart';

part 'car_spotting_controller.g.dart';

typedef ImageCompressor = Future<Uint8List> Function(Uint8List bytes);

/// Isolato dietro un provider (non chiamato staticamente nel controller)
/// solo per poterlo sovrascrivere nei test: `flutter_image_compress` non
/// ha un'implementazione per ogni piattaforma (es. Windows desktop) e
/// lancerebbe UnimplementedError prima ancora di toccare un platform
/// channel mockabile.
@riverpod
ImageCompressor imageCompressor(ImageCompressorRef ref) {
  return (bytes) => FlutterImageCompress.compressWithList(
        bytes,
        quality: 85,
        minWidth: 1280,
        minHeight: 1280,
      );
}

/// Orchestrazione publish/rate: chiama il repository, poi pubblica sul
/// bus del Mission Engine e invalida i provider di lettura così la UI
/// riflette subito l'esito. Nessuna feature deve mai chiamare
/// record_mission_event/il repository missioni direttamente — solo
/// publish() sul bus condiviso.
@riverpod
class CarSpottingController extends _$CarSpottingController {
  @override
  FutureOr<void> build() {
    // no-op initial state
  }

  Future<Spot?> publishSpot({
    required XFile photo,
    required String make,
    required String model,
    int? year,
    String? caption,
    String? locationLabel,
  }) async {
    // Nessuno fa `ref.watch` di questo controller (solo `ref.read(...).notifier`
    // dagli screen) — senza keepAlive, essendo autoDispose, Riverpod può
    // smontarlo mentre l'upload/insert è ancora in volo, e il successivo
    // `state = ...` fallisce con "Bad state: Future already completed"
    // invece di propagare l'errore vero alla UI. Chiuso nel finally,
    // qualunque sia l'esito.
    final keepAliveLink = ref.keepAlive();
    try {
      state = const AsyncLoading();
      final userId = ref.read(authStateProvider).valueOrNull?.id;

      Spot? result;
      state = await AsyncValue.guard(() async {
        if (userId == null) {
          throw StateError('Utente non autenticato');
        }

        final rawBytes = await photo.readAsBytes();
        final compressed = await ref.read(imageCompressorProvider)(rawBytes);

        result = await ref.read(carSpottingRepositoryProvider).publishSpot(
              photoBytes: Uint8List.fromList(compressed),
              photoExtension: '.jpg',
              make: make,
              model: model,
              year: year,
              caption: caption,
              locationLabel: locationLabel,
            );

        ref
            .read(missionEventBusProvider)
            .publish(PhotoUploaded(profileId: userId));
        ref
            .read(missionEventBusProvider)
            .publish(CarSpotted(profileId: userId, make: make));
      });

      final currentState = state;
      if (currentState is AsyncError) {
        Error.throwWithStackTrace(currentState.error, currentState.stackTrace);
      }

      ref.invalidate(spotsFeedProvider);
      ref.invalidate(topRatedSpotsProvider);

      return result;
    } finally {
      keepAliveLink.close();
    }
  }

  Future<SpotRating?> rateSpot(
      {required String spotId, required double rating}) async {
    final keepAliveLink = ref.keepAlive();
    try {
      state = const AsyncLoading();
      final userId = ref.read(authStateProvider).valueOrNull?.id;

      SpotRating? result;
      state = await AsyncValue.guard(() async {
        if (userId == null) {
          throw StateError('Utente non autenticato');
        }

        result = await ref
            .read(carSpottingRepositoryProvider)
            .rateSpot(spotId: spotId, rating: rating);

        ref
            .read(missionEventBusProvider)
            .publish(RatingGiven(profileId: userId, rating: rating));
      });

      ref.invalidate(spotByIdProvider(spotId));
      ref.invalidate(myRatingForSpotProvider(spotId));
      ref.invalidate(spotsFeedProvider);
      ref.invalidate(topRatedSpotsProvider);

      return result;
    } finally {
      keepAliveLink.close();
    }
  }

  Future<SpotComment?> addComment(
      {required String spotId, required String content}) async {
    final keepAliveLink = ref.keepAlive();
    try {
      state = const AsyncLoading();
      final userId = ref.read(authStateProvider).valueOrNull?.id;

      SpotComment? result;
      state = await AsyncValue.guard(() async {
        if (userId == null) {
          throw StateError('Utente non autenticato');
        }

        result = await ref
            .read(carSpottingRepositoryProvider)
            .addComment(spotId: spotId, content: content);

        ref
            .read(missionEventBusProvider)
            .publish(CommentAdded(profileId: userId));
      });

      ref.invalidate(spotCommentsProvider(spotId));
      return result;
    } finally {
      keepAliveLink.close();
    }
  }

  Future<void> deleteSpot(
      {required String spotId, required String photoUrl}) async {
    final keepAliveLink = ref.keepAlive();
    try {
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => ref
          .read(carSpottingRepositoryProvider)
          .deleteSpot(spotId: spotId, photoUrl: photoUrl));

      final currentState = state;
      if (currentState is AsyncError) {
        Error.throwWithStackTrace(currentState.error, currentState.stackTrace);
      }

      ref.invalidate(spotsFeedProvider);
      ref.invalidate(topRatedSpotsProvider);
      ref.invalidate(spotByIdProvider(spotId));
    } finally {
      keepAliveLink.close();
    }
  }
}
