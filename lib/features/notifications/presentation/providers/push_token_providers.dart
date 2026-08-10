import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/supabase_provider.dart';
import '../../data/datasources/push_token_remote_datasource.dart';
import '../../data/repositories/push_token_repository_impl.dart';
import '../../domain/repositories/push_token_repository.dart';

part 'push_token_providers.g.dart';

/// DI di `push_tokens` isolata dal proprio file (invece di vivere dentro
/// push_notification_service.dart): serve anche ad [AuthController] per
/// liberare il token del device al logout, che altrimenti importerebbe
/// push_notification_service.dart — che a sua volta importa già
/// auth_provider.dart per [authStateProvider] — creando un ciclo.
@riverpod
PushTokenRemoteDatasource pushTokenRemoteDatasource(
        PushTokenRemoteDatasourceRef ref) =>
    PushTokenRemoteDatasource(ref.watch(supabaseClientProvider));

@riverpod
PushTokenRepository pushTokenRepository(PushTokenRepositoryRef ref) =>
    PushTokenRepositoryImpl(ref.watch(pushTokenRemoteDatasourceProvider));
