import '../../domain/entities/radar_event.dart';

/// Riga `community_reports`.
class CommunityReportModel {
  final String id;
  final String category;
  final double lat;
  final double lon;
  final DateTime createdAt;

  const CommunityReportModel({
    required this.id,
    required this.category,
    required this.lat,
    required this.lon,
    required this.createdAt,
  });

  factory CommunityReportModel.fromJson(Map<String, dynamic> json) =>
      CommunityReportModel(
        id: json['id'] as String,
        category: json['category'] as String,
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  RadarEvent toEntity() => RadarEvent(
        id: 'community-$id',
        category:
            category == 'velox' ? RadarCategory.velox : RadarCategory.pattuglia,
        source: RadarSource.community,
        lat: lat,
        lon: lon,
        reportedAt: createdAt,
      );
}
