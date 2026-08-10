import '../../domain/repositories/push_token_repository.dart';
import '../datasources/push_token_remote_datasource.dart';

class PushTokenRepositoryImpl implements PushTokenRepository {
  final PushTokenRemoteDatasource _remote;
  PushTokenRepositoryImpl(this._remote);

  @override
  Future<void> register({required String token, required String platform}) =>
      _remote.register(token: token, platform: platform);

  @override
  Future<void> unregister(String token) => _remote.unregister(token);
}
