import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification_model.dart';

/// Unico punto della feature Notifications che importa supabase_flutter.
/// La tabella `notifications` esiste (0001_init.sql) e viene già popolata
/// da più trigger server-side (missioni, achievement, rating — vedi
/// 0003/0004): qui la leggiamo soltanto, mai un insert dal client (nessuna
/// policy lo permetterebbe: solo le funzioni security definer scrivono).
class NotificationsRemoteDatasource {
  final SupabaseClient _client;
  NotificationsRemoteDatasource(this._client);

  Stream<List<AppNotificationModel>> watch(String profileId) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('profile_id', profileId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(AppNotificationModel.fromJson).toList());
  }

  Future<void> markRead(String id) async {
    await _client.from('notifications').update({'read': true}).eq('id', id);
  }

  Future<void> markAllRead(String profileId) async {
    await _client
        .from('notifications')
        .update({'read': true})
        .eq('profile_id', profileId)
        .eq('read', false);
  }
}
