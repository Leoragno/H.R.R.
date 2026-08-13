import '../entities/friend_profile.dart';

abstract class FriendsRepository {
  Future<List<FriendProfile>> myFriends();
  Future<List<FriendRequest>> pendingRequests();
  Future<List<FriendSearchResult>> searchProfiles(String query);

  /// Ritorna 'sent' o 'accepted' — 'accepted' quando l'altro utente aveva
  /// già una richiesta pending verso di noi (vedi RPC `send_friend_request`).
  Future<String> sendRequest(String addresseeId);

  Future<void> respondToRequest({
    required String requesterId,
    required bool accept,
  });

  Future<void> removeFriend(String otherId);
}
