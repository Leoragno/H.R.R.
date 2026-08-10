import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

/// Talks directly to Supabase Auth + the `profiles` table.
/// This is the ONLY place in the auth feature allowed to import supabase_flutter.
class AuthRemoteDatasource {
  static const _avatarBucket = 'avatars';

  final SupabaseClient _client;

  AuthRemoteDatasource(this._client);

  Stream<ProfileModel?> authStateChanges() {
    return _client.auth.onAuthStateChange.asyncMap((event) async {
      final user = event.session?.user;
      if (user == null) return null;
      return _fetchProfileWithRetry(user.id);
    });
  }

  /// [signUpWithEmail] crea la riga `profiles` con un insert separato dopo
  /// `auth.signUp()`, ma l'evento `signedIn` di `onAuthStateChange` può
  /// arrivare qui prima che quell'insert sia commesso — e non rifira dopo.
  /// Senza retry questo stream emetterebbe `null` in modo permanente,
  /// facendo credere al router che l'utente sia sloggato finché non
  /// riavvia l'app (che invece rilegge lo stato con [currentUser]).
  Future<ProfileModel?> _fetchProfileWithRetry(String userId) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final profile = await _fetchProfile(userId);
      if (profile != null) return profile;
      await Future.delayed(const Duration(milliseconds: 400));
    }
    return null;
  }

  Future<ProfileModel?> currentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return _fetchProfile(user.id);
  }

  /// Stream realtime sulla riga `profiles` — richiede che la tabella sia
  /// nella pubblicazione `supabase_realtime` (vedi migration 0002).
  Stream<ProfileModel?> watchProfile(String userId) {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((rows) => rows.isEmpty ? null : ProfileModel.fromJson(rows.first));
  }

  Future<ProfileModel?> _fetchProfile(String userId) async {
    final row =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (row == null) return null;
    return ProfileModel.fromJson(row);
  }

  Future<ProfileModel> signInWithEmail(String email, String password) async {
    final res =
        await _client.auth.signInWithPassword(email: email, password: password);
    final userId = res.user!.id;
    final profile = await _fetchProfile(userId);
    if (profile == null) {
      throw StateError('Profilo non trovato per utente autenticato $userId');
    }
    return profile;
  }

  Future<ProfileModel> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    final res = await _client.auth.signUp(email: email, password: password);
    final userId = res.user?.id;
    if (userId == null) {
      throw StateError(
          'Sign-up fallito: nessun utente creato (verifica email?)');
    }

    final profileJson = ProfileModel(
      id: userId,
      username: username,
      displayName: username,
      level: 1,
      xp: 0,
      rep: 0,
      title: 'Rookie Driver',
    ).toJson();

    final inserted =
        await _client.from('profiles').insert(profileJson).select().single();
    return ProfileModel.fromJson(inserted);
  }

  Future<ProfileModel> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(OAuthProvider.google);
    // NB: su mobile il flow OAuth completa in modo asincrono via deep link.
    // authStateChanges() emetterà il nuovo stato quando la sessione è pronta.
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('OAuth Google avviato, in attesa di redirect');
    }
    final profile = await _fetchProfile(user.id);
    return profile ??
        await _createProfileForOAuthUser(user.id, user.email ?? 'driver');
  }

  Future<ProfileModel> signInWithApple() async {
    await _client.auth.signInWithOAuth(OAuthProvider.apple);
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('OAuth Apple avviato, in attesa di redirect');
    }
    final profile = await _fetchProfile(user.id);
    return profile ??
        await _createProfileForOAuthUser(user.id, user.email ?? 'driver');
  }

  Future<ProfileModel> _createProfileForOAuthUser(
      String userId, String seedName) async {
    final username = '${seedName.split('@').first}_${userId.substring(0, 6)}';
    final profileJson = ProfileModel(
      id: userId,
      username: username,
      displayName: username,
      level: 1,
      xp: 0,
      rep: 0,
      title: 'Rookie Driver',
    ).toJson();
    final inserted =
        await _client.from('profiles').insert(profileJson).select().single();
    return ProfileModel.fromJson(inserted);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<ProfileModel> updateProfileFields(
    String userId,
    Map<String, dynamic> fields,
  ) async {
    final updated = await _client
        .from('profiles')
        .update(fields)
        .eq('id', userId)
        .select()
        .single();
    return ProfileModel.fromJson(updated);
  }

  /// Carica la nuova foto profilo su Storage (bucket `avatars`, path
  /// `{userId}/...` come richiesto dalle RLS policy — vedi migration
  /// 0020) e salva l'URL pubblico su `profiles.avatar_url`.
  Future<ProfileModel> uploadAvatar({
    required String userId,
    required Uint8List photoBytes,
    required String photoExtension,
  }) async {
    final path =
        '$userId/${DateTime.now().microsecondsSinceEpoch}$photoExtension';
    await _client.storage.from(_avatarBucket).uploadBinary(
          path,
          photoBytes,
          fileOptions: const FileOptions(upsert: true),
        );
    final avatarUrl = _client.storage.from(_avatarBucket).getPublicUrl(path);
    return updateProfileFields(userId, {'avatar_url': avatarUrl});
  }
}
