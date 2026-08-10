import '../../domain/entities/spot.dart';

class SpotModel {
  final String id;
  final String authorId;
  final String? authorUsername;
  final String photoUrl;
  final String? caption;
  final String? locationLabel;
  final String? detectedMake;
  final String? detectedModel;
  final int? detectedYear;
  final String? detectedCategory;
  final String? detectedRarity;
  final double averageRating;
  final int ratingCount;
  final DateTime createdAt;

  const SpotModel({
    required this.id,
    required this.authorId,
    this.authorUsername,
    required this.photoUrl,
    this.caption,
    this.locationLabel,
    this.detectedMake,
    this.detectedModel,
    this.detectedYear,
    this.detectedCategory,
    this.detectedRarity,
    required this.averageRating,
    required this.ratingCount,
    required this.createdAt,
  });

  factory SpotModel.fromJson(Map<String, dynamic> json) {
    final author = json['profiles'] as Map<String, dynamic>?;
    return SpotModel(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      authorUsername: author?['username'] as String?,
      photoUrl: json['photo_url'] as String,
      caption: json['caption'] as String?,
      locationLabel: json['location_label'] as String?,
      detectedMake: json['detected_make'] as String?,
      detectedModel: json['detected_model'] as String?,
      detectedYear: json['detected_year'] as int?,
      detectedCategory: json['detected_category'] as String?,
      detectedRarity: json['detected_rarity'] as String?,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      ratingCount: json['rating_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Spot toEntity() => Spot(
        id: id,
        authorId: authorId,
        authorUsername: authorUsername,
        photoUrl: photoUrl,
        caption: caption,
        locationLabel: locationLabel,
        detectedMake: detectedMake,
        detectedModel: detectedModel,
        detectedYear: detectedYear,
        detectedCategory: detectedCategory,
        detectedRarity: detectedRarity,
        averageRating: averageRating,
        ratingCount: ratingCount,
        createdAt: createdAt,
      );
}
