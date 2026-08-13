import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/events/mission_event.dart';
import '../../../../core/events/mission_event_bus.dart';
import '../../../../core/network/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/friends_remote_datasource.dart';
import '../../data/repositories/friends_repository_impl.dart';
import '../../domain/entities/friend_profile.dart';
import '../../domain/repositories/friends_repository.dart';

part 'friends_provider.g.dart';

// ---- DI wiring ----------------------------------------------------------

@riverpod
FriendsRemoteDatasource friendsRemoteDatasource(
    FriendsRemoteDatasourceRef ref) {
  return FriendsRemoteDatasource(ref.watch(supabaseClientProvider));
}

@riverpod
FriendsRepository friendsRepository(FriendsRepositoryRef ref) {
  return FriendsRepositoryImpl(ref.watch(friendsRemoteDatasourceProvider));
}

// ---- Lettura --------------------------------------------------------------

@riverpod
Future<List<FriendProfile>> myFriends(MyFriendsRef ref) =>
    ref.watch(friendsRepositoryProvider).myFriends();

@riverpod
Future<List<FriendRequest>> pendingFriendRequests(
        PendingFriendRequestsRef ref) =>
    ref.watch(friendsRepositoryProvider).pendingRequests();

// ---- Ricerca + azioni -------------------------------------------------

class FriendsSearchState {
  final String query;
  final List<FriendSearchResult> results;
  final bool loading;
  final String? error;

  const FriendsSearchState({
    this.query = '',
    this.results = const [],
    this.loading = false,
    this.error,
  });

  FriendsSearchState copyWith({
    String? query,
    List<FriendSearchResult>? results,
    bool? loading,
    String? error,
  }) =>
      FriendsSearchState(
        query: query ?? this.query,
        results: results ?? this.results,
        loading: loading ?? this.loading,
        error: error,
      );
}

/// Ricerca profili (debounced) + azioni invio/risposta/rimozione amicizia.
/// Le liste "di lettura" (myFriendsProvider/pendingFriendRequestsProvider)
/// restano provider separati e vengono invalidate da qui dopo ogni
/// mutazione, invece di essere duplicate in questo stato.
@riverpod
class FriendsSearchController extends _$FriendsSearchController {
  Timer? _debounce;

  @override
  FriendsSearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const FriendsSearchState();
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
    _debounce?.cancel();
    if (query.trim().length < 2) {
      state = state.copyWith(results: const [], loading: false, error: null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final results =
          await ref.read(friendsRepositoryProvider).searchProfiles(query);
      // La query può essere cambiata mentre aspettavamo la risposta.
      if (state.query != query) return;
      state = state.copyWith(results: results, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Ricerca non riuscita');
    }
  }

  Future<void> sendRequest(String addresseeId) async {
    final result =
        await ref.read(friendsRepositoryProvider).sendRequest(addresseeId);
    final accepted = result == 'accepted';
    _updateRelationship(
      addresseeId,
      accepted
          ? FriendRelationship.accepted
          : FriendRelationship.pendingOutgoing,
    );
    ref.invalidate(myFriendsProvider);
    if (accepted) _publishFriendAdded();
  }

  Future<void> respondToRequest({
    required String requesterId,
    required bool accept,
  }) async {
    await ref
        .read(friendsRepositoryProvider)
        .respondToRequest(requesterId: requesterId, accept: accept);
    ref.invalidate(pendingFriendRequestsProvider);
    if (accept) {
      ref.invalidate(myFriendsProvider);
      _updateRelationship(requesterId, FriendRelationship.accepted);
      _publishFriendAdded();
    }
  }

  Future<void> removeFriend(String otherId) async {
    await ref.read(friendsRepositoryProvider).removeFriend(otherId);
    ref.invalidate(myFriendsProvider);
    ref.invalidate(pendingFriendRequestsProvider);
    _updateRelationship(otherId, FriendRelationship.none);
  }

  // Aggiorna il risultato di ricerca in place (niente nuova ricerca)
  // così la UI riflette subito l'azione appena compiuta senza aspettare
  // un altro giro di rete.
  void _updateRelationship(String profileId, FriendRelationship relationship) {
    state = state.copyWith(results: [
      for (final r in state.results)
        if (r.profileId == profileId)
          FriendSearchResult(
            profileId: r.profileId,
            username: r.username,
            displayName: r.displayName,
            avatarUrl: r.avatarUrl,
            level: r.level,
            relationship: relationship,
          )
        else
          r,
    ]);
  }

  void _publishFriendAdded() {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId != null) {
      ref.read(missionEventBusProvider).publish(FriendAdded(profileId: userId));
    }
  }
}
