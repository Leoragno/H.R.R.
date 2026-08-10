import '../../domain/entities/app_notification.dart';

class AppNotificationModel {
  final String id;
  final String type;
  final String title;
  final String? body;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime createdAt;

  const AppNotificationModel({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.data = const {},
    required this.read,
    required this.createdAt,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) =>
      AppNotificationModel(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String?,
        data: (json['data'] as Map<String, dynamic>?) ?? const {},
        read: json['read'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  AppNotification toEntity() => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        data: data,
        read: read,
        createdAt: createdAt,
      );
}
