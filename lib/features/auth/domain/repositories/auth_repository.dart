import 'dart:typed_data';

import '../entities/app_user.dart';

/// Contract implemented by the data layer. Presentation/domain code
/// depends only on this abstraction, never on Supabase directly.
abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();
  Future<AppUser?> currentUser();

  /// Stream realtime della riga `profiles` dell'utente — a differenza di
  /// [authStateChanges], reagisce ai cambi di xp/rep/level (es. dopo un
  /// viaggio), non solo ai login/logout.
  Stream<AppUser?> watchProfile(String userId);

  Future<AppUser> signInWithEmail(
      {required String email, required String password});
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  });
  Future<AppUser> signInWithGoogle();
  Future<AppUser> signInWithApple();
  Future<void> signOut();

  /// Salva marca/modello del veicolo principale — usato sia
  /// dall'onboarding "il tuo ride" post-registrazione sia dal picker
  /// veicolo in Impostazioni.
  Future<AppUser> updateVehicle({
    required String userId,
    required String brand,
    required String model,
  });

  /// Aggiorna i campi opzionali di Impostazioni — solo quelli non-null
  /// vengono scritti, gli altri restano invariati.
  Future<AppUser> updateProfileSettings({
    required String userId,
    String? username,
    String? country,
    String? accentColor,
    String? mascotId,
  });

  /// Carica la nuova foto profilo e aggiorna `avatarUrl`.
  Future<AppUser> updateAvatar({
    required String userId,
    required Uint8List photoBytes,
    required String photoExtension,
  });
}
