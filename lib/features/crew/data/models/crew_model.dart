import '../../domain/entities/crew.dart';

class CrewModel {
  final String id;
  final String name;
  final String tag;
  final String? description;
  final String? emblemUrl;
  final String ownerId;
  final DateTime createdAt;

  const CrewModel({
    required this.id,
    required this.name,
    required this.tag,
    this.description,
    this.emblemUrl,
    required this.ownerId,
    required this.createdAt,
  });

  factory CrewModel.fromJson(Map<String, dynamic> json) => CrewModel(
        id: json['id'] as String,
        name: json['name'] as String,
        tag: json['tag'] as String,
        description: json['description'] as String?,
        emblemUrl: json['emblem_url'] as String?,
        ownerId: json['owner_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Crew toEntity() => Crew(
        id: id,
        name: name,
        tag: tag,
        description: description,
        emblemUrl: emblemUrl,
        ownerId: ownerId,
        createdAt: createdAt,
      );
}
