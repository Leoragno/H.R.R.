import '../../domain/entities/crew_member.dart';

/// Parsa la riga `crew_members` join `profiles(...)` (vedi
/// `crew_remote_datasource.dart`'s `_memberSelect`).
class CrewMemberModel {
  final String profileId;
  final String crewId;
  final CrewRole role;
  final DateTime joinedAt;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final int level;

  const CrewMemberModel({
    required this.profileId,
    required this.crewId,
    required this.role,
    required this.joinedAt,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.level,
  });

  factory CrewMemberModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>;
    return CrewMemberModel(
      profileId: json['profile_id'] as String,
      crewId: json['crew_id'] as String,
      role: CrewRole.fromApi(json['role'] as String),
      joinedAt: DateTime.parse(json['joined_at'] as String),
      username: profile['username'] as String,
      displayName: profile['display_name'] as String,
      avatarUrl: profile['avatar_url'] as String?,
      level: profile['level'] as int,
    );
  }

  CrewMember toEntity() => CrewMember(
        profileId: profileId,
        crewId: crewId,
        role: role,
        joinedAt: joinedAt,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        level: level,
      );
}
