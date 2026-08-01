import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_provider.g.dart';

// ---- DI wiring ----------------------------------------------------------

@riverpod
SupabaseClient supabaseClient(SupabaseClientRef ref) =>
    Supabase.instance.client;

@riverpod
AuthRemoteDatasource authRemoteDatasource(AuthRemoteDatasourceRef ref) {
  return AuthRemoteDatasource(ref.watch(supabaseClientProvider));
}

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepositoryImpl(ref.watch(authRemoteDatasourceProvider));
}

// ---- App state ------------------------------------------------------------

/// Stream of the current authenticated user (or null). The router watches
/// this to decide redirects between /login and the main app shell.
@riverpod
Stream<AppUser?> authState(AuthStateRef ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
}

/// Profilo live dell'utente corrente: a differenza di [authStateProvider]
/// (che emette solo su login/logout), questo si aggiorna in tempo reale
/// quando xp/rep/level cambiano (es. subito dopo aver finito un viaggio),
/// quindi è la fonte giusta per qualsiasi HUD che mostri quei valori.
@riverpod
Stream<AppUser?> myProfile(MyProfileRef ref) {
  final userId = ref.watch(authStateProvider).valueOrNull?.id;
  if (userId == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchProfile(userId);
}

/// Controller used by Login/Register screens to trigger actions and expose
/// a loading/error state independent from the auth stream itself.
@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<void> build() {
    // no-op initial state
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signInWithEmail(email: email, password: password),
    );
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signUpWithEmail(
            email: email,
            password: password,
            username: username,
          ),
    );
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(authRepositoryProvider).signInWithGoogle());
  }

  Future<void> signInWithApple() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(authRepositoryProvider).signInWithApple());
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(authRepositoryProvider).signOut());
  }
}
