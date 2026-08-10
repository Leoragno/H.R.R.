import '../../domain/entities/spot_comment.dart';

class SpotCommentModel {
  final String id;
  final String spotId;
  final String authorId;
  final String? authorUsername;
  final String content;
  final DateTime createdAt;

  const SpotCommentModel({
    required this.id,
    required this.spotId,
    required this.authorId,
    this.authorUsername,
    required this.content,
    required this.createdAt,
  });

  factory SpotCommentModel.fromJson(Map<String, dynamic> json) {
    final author = json['profiles'] as Map<String, dynamic>?;
    return SpotCommentModel(
      id: json['id'] as String,
      spotId: json['spot_id'] as String,
      authorId: json['author_id'] as String,
      authorUsername: author?['username'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  SpotComment toEntity() => SpotComment(
        id: id,
        spotId: spotId,
        authorId: authorId,
        authorUsername: authorUsername,
        content: content,
        createdAt: createdAt,
      );
}
