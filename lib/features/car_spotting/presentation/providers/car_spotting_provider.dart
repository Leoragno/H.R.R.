import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/car_spotting_remote_datasource.dart';
import '../../data/repositories/car_spotting_repository_impl.dart';
import '../../domain/entities/spot.dart';
import '../../domain/entities/spot_comment.dart';
import '../../domain/entities/spot_rating.dart';
import '../../domain/repositories/car_spotting_repository.dart';

part 'car_spotting_provider.g.dart';

// ---- DI wiring ----------------------------------------------------------

@riverpod
CarSpottingRemoteDatasource carSpottingRemoteDatasource(
    CarSpottingRemoteDatasourceRef ref) {
  return CarSpottingRemoteDatasource(ref.watch(supabaseClientProvider));
}

@riverpod
CarSpottingRepository carSpottingRepository(CarSpottingRepositoryRef ref) {
  return CarSpottingRepositoryImpl(
    ref.watch(carSpottingRemoteDatasourceProvider),
    () => ref.read(authStateProvider).valueOrNull!.id,
  );
}

// ---- Stato -----------------------------------------------------------------

/// Feed pubblico, più recenti prima.
@riverpod
Future<List<Spot>> spotsFeed(SpotsFeedRef ref) {
  return ref.watch(carSpottingRepositoryProvider).feed();
}

@riverpod
Future<Spot> spotById(SpotByIdRef ref, String spotId) {
  return ref.watch(carSpottingRepositoryProvider).spotById(spotId);
}

/// Top auto della community — nessuna soglia minima di voti, ordinate
/// solo per media stelle.
@riverpod
Future<List<Spot>> topRatedSpots(TopRatedSpotsRef ref) {
  return ref.watch(carSpottingRepositoryProvider).topRated();
}

/// Il proprio voto per uno spot (null se non ancora votato). Mai il voto
/// di qualcun altro — RLS lo impedirebbe comunque.
@riverpod
Future<SpotRating?> myRatingForSpot(MyRatingForSpotRef ref, String spotId) {
  final userId = ref.watch(authStateProvider).valueOrNull?.id;
  if (userId == null) return Future.value(null);
  return ref.watch(carSpottingRepositoryProvider).myRating(spotId);
}

@riverpod
Future<List<SpotComment>> spotComments(SpotCommentsRef ref, String spotId) {
  return ref.watch(carSpottingRepositoryProvider).comments(spotId);
}
