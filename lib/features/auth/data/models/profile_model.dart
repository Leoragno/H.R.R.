import '../../domain/entities/app_user.dart';

/// DTO mirroring the `profiles` table row. Converts to/from the
/// domain entity so the rest of the app never touches raw Supabase JSON.
class ProfileModel {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final int level;
  final int xp;
  final int rep;
  final String title;
  final String? crewId;

  const ProfileModel({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.level,
    required this.xp,
    required this.rep,
    required this.title,
    this.crewId,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      level: json['level'] as int? ?? 1,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      rep: (json['rep'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Rookie Driver',
      crewId: json['crew_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'level': level,
        'xp': xp,
        'rep': rep,
        'title': title,
        'crew_id': crewId,
      };

  AppUser toEntity() => AppUser(
        id: id,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        level: level,
        xp: xp,
        rep: rep,
        title: title,
        crewId: crewId,
      );
}
