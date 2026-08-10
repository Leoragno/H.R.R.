import '../entities/app_notification.dart';

abstract class NotificationRepository {
  Stream<List<AppNotification>> watch(String profileId);
  Future<void> markRead(String id);
  Future<void> markAllRead(String profileId);
}
