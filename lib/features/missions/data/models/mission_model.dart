import '../../domain/entities/mission.dart';

/// DTO che rispecchia la tabella `missions` dopo 0003_mission_engine.sql.
class MissionModel {
  final String id;
  final String code;
  final String title;
  final String? description;
  final String icon;
  final String type;
  final String difficulty;
  final double targetValue;
  final String targetMetric;
  final int xpReward;
  final int repReward;
  final List<String> rewardBadges;
  final List<String> rewardTitles;
  final Map<String, dynamic> rewardProfileItems;
  final String? rewardAvatarFrame;
  final bool hidden;
  final bool secret;
  final bool repeatable;
  final String? seasonId;
  final String? eventId;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MissionModel({
    required this.id,
    required this.code,
    required this.title,
    this.description,
    required this.icon,
    required this.type,
    required this.difficulty,
    required this.targetValue,
    required this.targetMetric,
    required this.xpReward,
    required this.repReward,
    required this.rewardBadges,
    required this.rewardTitles,
    required this.rewardProfileItems,
    this.rewardAvatarFrame,
    required this.hidden,
    required this.secret,
    required this.repeatable,
    this.seasonId,
    this.eventId,
    this.startsAt,
    this.endsAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MissionModel.fromJson(Map<String, dynamic> json) {
    return MissionModel(
      id: json['id'] as String,
      code: json['code'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String? ?? 'target',
      type: json['type'] as String,
      difficulty: json['difficulty'] as String? ?? 'normal',
      targetValue: (json['target_value'] as num).toDouble(),
      targetMetric: json['target_metric'] as String,
      xpReward: json['xp_reward'] as int? ?? 0,
      repReward: json['rep_reward'] as int? ?? 0,
      rewardBadges: ((json['reward_badges'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      rewardTitles: ((json['reward_titles'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      rewardProfileItems: Map<String, dynamic>.from(
          json['reward_profile_items'] as Map? ?? const {}),
      rewardAvatarFrame: json['reward_avatar_frame'] as String?,
      hidden: json['hidden'] as bool? ?? false,
      secret: json['secret'] as bool? ?? false,
      repeatable: json['repeatable'] as bool? ?? false,
      seasonId: json['season_id'] as String?,
      eventId: json['event_id'] as String?,
      startsAt: json['starts_at'] == null
          ? null
          : DateTime.parse(json['starts_at'] as String),
      endsAt: json['ends_at'] == null
          ? null
          : DateTime.parse(json['ends_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? DateTime.now()
          : DateTime.parse(json['updated_at'] as String),
    );
  }

  Mission toEntity() => Mission(
        id: id,
        code: code,
        title: title,
        description: description ?? '',
        icon: icon,
        type: missionTypeFromString(type),
        difficulty: missionDifficultyFromString(difficulty),
        targetValue: targetValue,
        targetMetric: targetMetric,
        rewardXp: xpReward,
        rewardRep: repReward,
        rewardBadgeIds: rewardBadges,
        rewardTitles: rewardTitles,
        rewardProfileItems: rewardProfileItems,
        rewardAvatarFrame: rewardAvatarFrame,
        hidden: hidden,
        secret: secret,
        repeatable: repeatable,
        seasonId: seasonId,
        eventId: eventId,
        startsAt: startsAt,
        endsAt: endsAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
