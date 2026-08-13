import '../../domain/entities/friend_profile.dart';
import '../../domain/repositories/friends_repository.dart';
import '../datasources/friends_remote_datasource.dart';

class FriendsRepositoryImpl implements FriendsRepository {
  final FriendsRemoteDatasource _remote;

  FriendsRepositoryImpl(this._remote);

  @override
  Future<List<FriendProfile>> myFriends() async =>
      (await _remote.myFriends()).map((m) => m.toEntity()).toList();

  @override
  Future<List<FriendRequest>> pendingRequests() async =>
      (await _remote.pendingRequests()).map((m) => m.toEntity()).toList();

  @override
  Future<List<FriendSearchResult>> searchProfiles(String query) async =>
      (await _remote.searchProfiles(query)).map((m) => m.toEntity()).toList();

  @override
  Future<String> sendRequest(String addresseeId) =>
      _remote.sendRequest(addresseeId);

  @override
  Future<void> respondToRequest({
    required String requesterId,
    required bool accept,
  }) =>
      _remote.respondToRequest(requesterId: requesterId, accept: accept);

  @override
  Future<void> removeFriend(String otherId) => _remote.removeFriend(otherId);
}
