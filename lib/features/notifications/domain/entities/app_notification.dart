import 'package:equatable/equatable.dart';

/// Riga `notifications` — `type` è testo libero lato DB (nessun check
/// constraint, vedi 0001_init.sql: 'like','comment','mission_complete',
/// 'achievement_unlocked',...), non un enum Dart chiuso: nuovi tipi
/// arrivano di continuo da trigger server-side diversi, un enum
/// andrebbe aggiornato ad ogni giro. La presentazione "simpatica" per
/// tipo vive in notification_presentation.dart, con un fallback per i
/// tipi non ancora mappati.
class AppNotification extends Equatable {
  final String id;
  final String type;
  final String title;
  final String? body;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.data = const {},
    required this.read,
    required this.createdAt,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        data: data,
        read: read ?? this.read,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [id, type, title, body, data, read, createdAt];
}
