import '../../domain/entities/friend_profile.dart';

class FriendProfileModel {
  final String profileId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String accentColor;
  final int level;

  const FriendProfileModel({
    required this.profileId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.accentColor,
    required this.level,
  });

  factory FriendProfileModel.fromJson(Map<String, dynamic> json) =>
      FriendProfileModel(
        profileId: json['profile_id'] as String,
        username: json['username'] as String,
        displayName: json['display_name'] as String,
        avatarUrl: json['avatar_url'] as String?,
        accentColor: json['accent_color'] as String? ?? '#35e0ff',
        level: json['level'] as int,
      );

  FriendProfile toEntity() => FriendProfile(
        profileId: profileId,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        accentColor: accentColor,
        level: level,
      );
}

class FriendRequestModel {
  final String requesterId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String accentColor;
  final int level;
  final DateTime createdAt;

  const FriendRequestModel({
    required this.requesterId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.accentColor,
    required this.level,
    required this.createdAt,
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) =>
      FriendRequestModel(
        requesterId: json['requester_id'] as String,
        username: json['username'] as String,
        displayName: json['display_name'] as String,
        avatarUrl: json['avatar_url'] as String?,
        accentColor: json['accent_color'] as String? ?? '#35e0ff',
        level: json['level'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  FriendRequest toEntity() => FriendRequest(
        requesterId: requesterId,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        accentColor: accentColor,
        level: level,
        createdAt: createdAt,
      );
}

class FriendSearchResultModel {
  final String profileId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final int level;
  final FriendRelationship relationship;

  const FriendSearchResultModel({
    required this.profileId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.level,
    required this.relationship,
  });

  factory FriendSearchResultModel.fromJson(Map<String, dynamic> json) =>
      FriendSearchResultModel(
        profileId: json['profile_id'] as String,
        username: json['username'] as String,
        displayName: json['display_name'] as String,
        avatarUrl: json['avatar_url'] as String?,
        level: json['level'] as int,
        relationship:
            FriendRelationship.fromApi(json['relationship'] as String),
      );

  FriendSearchResult toEntity() => FriendSearchResult(
        profileId: profileId,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        level: level,
        relationship: relationship,
      );
}
