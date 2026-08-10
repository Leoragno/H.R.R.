import 'package:equatable/equatable.dart';

/// Voto personale dell'utente corrente su uno spot — mai il voto di
/// qualcun altro: RLS espone solo `profile_id = auth.uid()`.
class SpotRating extends Equatable {
  final String id;
  final String spotId;
  final String profileId;
  final double rating;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SpotRating({
    required this.id,
    required this.spotId,
    required this.profileId,
    required this.rating,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props =>
      [id, spotId, profileId, rating, createdAt, updatedAt];
}
