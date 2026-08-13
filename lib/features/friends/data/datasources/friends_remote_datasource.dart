import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/friend_profile_model.dart';

/// Unico punto della feature Amici che importa supabase_flutter — tutte le
/// RPC sono definite in 0023_friends.sql.
class FriendsRemoteDatasource {
  final SupabaseClient _client;

  FriendsRemoteDatasource(this._client);

  Future<List<FriendProfileModel>> myFriends() async {
    final rows = await _client.rpc('my_friends');
    return (rows as List)
        .map((r) => FriendProfileModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<FriendRequestModel>> pendingRequests() async {
    final rows = await _client.rpc('pending_friend_requests');
    return (rows as List)
        .map((r) => FriendRequestModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<FriendSearchResultModel>> searchProfiles(String query) async {
    final rows = await _client
        .rpc('search_profiles_for_friend', params: {'p_query': query});
    return (rows as List)
        .map((r) => FriendSearchResultModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<String> sendRequest(String addresseeId) async {
    final result = await _client
        .rpc('send_friend_request', params: {'p_addressee_id': addresseeId});
    return result as String;
  }

  Future<void> respondToRequest({
    required String requesterId,
    required bool accept,
  }) async {
    await _client.rpc('respond_friend_request', params: {
      'p_requester_id': requesterId,
      'p_accept': accept,
    });
  }

  Future<void> removeFriend(String otherId) async {
    await _client.rpc('remove_friend', params: {'p_other_id': otherId});
  }
}
