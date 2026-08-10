import 'package:equatable/equatable.dart';

class SpotComment extends Equatable {
  final String id;
  final String spotId;
  final String authorId;
  final String? authorUsername;
  final String content;
  final DateTime createdAt;

  const SpotComment({
    required this.id,
    required this.spotId,
    required this.authorId,
    this.authorUsername,
    required this.content,
    required this.createdAt,
  });

  @override
  List<Object?> get props =>
      [id, spotId, authorId, authorUsername, content, createdAt];
}
