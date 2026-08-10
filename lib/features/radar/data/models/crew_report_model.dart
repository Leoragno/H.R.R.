import '../../domain/entities/radar_event.dart';

/// Riga `crew_reports`.
class CrewReportModel {
  final String id;
  final String category;
  final double lat;
  final double lon;
  final DateTime createdAt;

  const CrewReportModel({
    required this.id,
    required this.category,
    required this.lat,
    required this.lon,
    required this.createdAt,
  });

  factory CrewReportModel.fromJson(Map<String, dynamic> json) =>
      CrewReportModel(
        id: json['id'] as String,
        category: json['category'] as String,
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  RadarEvent toEntity() => RadarEvent(
        id: 'crew-$id',
        category:
            category == 'velox' ? RadarCategory.velox : RadarCategory.pattuglia,
        source: RadarSource.crew,
        lat: lat,
        lon: lon,
        reportedAt: createdAt,
      );
}
