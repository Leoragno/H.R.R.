import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource _remote;

  AuthRepositoryImpl(this._remote);

  @override
  Stream<AppUser?> authStateChanges() =>
      _remote.authStateChanges().map((p) => p?.toEntity());

  @override
  Future<AppUser?> currentUser() async =>
      (await _remote.currentUser())?.toEntity();

  @override
  Stream<AppUser?> watchProfile(String userId) =>
      _remote.watchProfile(userId).map((p) => p?.toEntity());

  @override
  Future<AppUser> signInWithEmail(
      {required String email, required String password}) async {
    final profile = await _remote.signInWithEmail(email, password);
    return profile.toEntity();
  }

  @override
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    final profile = await _remote.signUpWithEmail(
      email: email,
      password: password,
      username: username,
    );
    return profile.toEntity();
  }

  @override
  Future<AppUser> signInWithGoogle() async =>
      (await _remote.signInWithGoogle()).toEntity();

  @override
  Future<AppUser> signInWithApple() async =>
      (await _remote.signInWithApple()).toEntity();

  @override
  Future<void> signOut() => _remote.signOut();
}
