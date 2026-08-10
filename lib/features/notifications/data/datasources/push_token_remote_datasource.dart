import 'package:supabase_flutter/supabase_flutter.dart';

/// Unico punto della feature che tocca `push_tokens`. Scrive solo via RPC
/// (`register_push_token`/`unregister_push_token`, vedi
/// 0015_push_tokens.sql): l'RPC gestisce da sola il caso "stesso device,
/// account diverso da prima" liberando il token dal profilo precedente,
/// cosa che un semplice upsert client-side con RLS non potrebbe fare.
class PushTokenRemoteDatasource {
  final SupabaseClient _client;
  PushTokenRemoteDatasource(this._client);

  Future<void> register({required String token, required String platform}) async {
    await _client.rpc('register_push_token', params: {
      'p_token': token,
      'p_platform': platform,
    });
  }

  Future<void> unregister(String token) async {
    await _client.rpc('unregister_push_token', params: {'p_token': token});
  }
}
