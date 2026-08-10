import 'package:equatable/equatable.dart';

/// Auto avvistata — entità pura di dominio. `averageRating`/`ratingCount`
/// sono aggregati mantenuti server-side (trigger su spot_ratings), mai
/// calcolati lato client.
class Spot extends Equatable {
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

  const Spot({
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

  @override
  List<Object?> get props => [
        id,
        authorId,
        authorUsername,
        photoUrl,
        caption,
        locationLabel,
        detectedMake,
        detectedModel,
        detectedYear,
        detectedCategory,
        detectedRarity,
        averageRating,
        ratingCount,
        createdAt,
      ];
}
