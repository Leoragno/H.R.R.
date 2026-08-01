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
}
