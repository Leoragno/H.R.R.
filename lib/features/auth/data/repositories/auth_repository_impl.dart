import 'dart:typed_data';

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

  @override
  Future<AppUser> updateVehicle({
    required String userId,
    required String brand,
    required String model,
  }) async {
    final profile = await _remote.updateProfileFields(userId, {
      'vehicle_brand': brand,
      'vehicle_model': model,
    });
    return profile.toEntity();
  }

  @override
  Future<AppUser> updateProfileSettings({
    required String userId,
    String? username,
    String? country,
    String? accentColor,
    String? mascotId,
  }) async {
    final fields = <String, dynamic>{
      if (username != null) 'username': username,
      if (country != null) 'country': country,
      if (accentColor != null) 'accent_color': accentColor,
      if (mascotId != null) 'mascot_id': mascotId,
    };
    final profile = await _remote.updateProfileFields(userId, fields);
    return profile.toEntity();
  }

  @override
  Future<AppUser> updateAvatar({
    required String userId,
    required Uint8List photoBytes,
    required String photoExtension,
  }) async {
    final profile = await _remote.uploadAvatar(
      userId: userId,
      photoBytes: photoBytes,
      photoExtension: photoExtension,
    );
    return profile.toEntity();
  }
}
