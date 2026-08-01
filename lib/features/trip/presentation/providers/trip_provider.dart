import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/trip_remote_datasource.dart';
import '../../data/repositories/trip_repository_impl.dart';
import '../../domain/entities/trip.dart';
import '../../domain/repositories/trip_repository.dart';

part 'trip_provider.g.dart';

@riverpod
TripRemoteDatasource tripRemoteDatasource(TripRemoteDatasourceRef ref) {
  return TripRemoteDatasource(ref.watch(supabaseClientProvider));
}

@riverpod
TripRepository tripRepository(TripRepositoryRef ref) {
  return TripRepositoryImpl(ref.watch(tripRemoteDatasourceProvider));
}

/// Ultimi viaggi completati dell'utente corrente (storico), usato dal
/// profilo per la cronologia viaggi.
@riverpod
Future<List<Trip>> recentTrips(RecentTripsRef ref) async {
  final userId = ref.watch(authStateProvider).valueOrNull?.id;
  if (userId == null) return const [];
  return ref.watch(tripRepositoryProvider).recentTrips(userId);
}

@riverpod
Future<Trip> tripById(TripByIdRef ref, String tripId) {
  return ref.watch(tripRepositoryProvider).tripById(tripId);
}
