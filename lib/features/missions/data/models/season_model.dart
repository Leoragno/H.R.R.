import '../../domain/entities/season.dart';

class SeasonModel {
  final String id;
  final String code;
  final String name;
  final DateTime startsAt;
  final DateTime endsAt;

  const SeasonModel({
    required this.id,
    required this.code,
    required this.name,
    required this.startsAt,
    required this.endsAt,
  });

  factory SeasonModel.fromJson(Map<String, dynamic> json) {
    return SeasonModel(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
    );
  }

  Season toEntity() => Season(
      id: id, code: code, name: name, startsAt: startsAt, endsAt: endsAt);
}
