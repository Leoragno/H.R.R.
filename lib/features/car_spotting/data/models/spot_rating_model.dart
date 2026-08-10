import '../../domain/entities/spot_rating.dart';

class SpotRatingModel {
  final String id;
  final String spotId;
  final String profileId;
  final double rating;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SpotRatingModel({
    required this.id,
    required this.spotId,
    required this.profileId,
    required this.rating,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SpotRatingModel.fromJson(Map<String, dynamic> json) {
    return SpotRatingModel(
      id: json['id'] as String,
      spotId: json['spot_id'] as String,
      profileId: json['profile_id'] as String,
      rating: (json['rating'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  SpotRating toEntity() => SpotRating(
        id: id,
        spotId: spotId,
        profileId: profileId,
        rating: rating,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
