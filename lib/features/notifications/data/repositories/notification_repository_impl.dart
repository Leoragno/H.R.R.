import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notifications_remote_datasource.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationsRemoteDatasource _remote;
  NotificationRepositoryImpl(this._remote);

  @override
  Stream<List<AppNotification>> watch(String profileId) =>
      _remote.watch(profileId).map((rows) => rows.map((r) => r.toEntity()).toList());

  @override
  Future<void> markRead(String id) => _remote.markRead(id);

  @override
  Future<void> markAllRead(String profileId) => _remote.markAllRead(profileId);
}
