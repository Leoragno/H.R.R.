import '../../domain/entities/achievement.dart';

class AchievementModel {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String icon;
  final String rarity;
  final String targetMetric;
  final double targetValue;
  final int rewardRep;
  final int rewardXp;
  final List<String> rewardBadges;
  final List<String> rewardTitles;
  final DateTime? earnedAt;

  const AchievementModel({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.icon,
    required this.rarity,
    required this.targetMetric,
    required this.targetValue,
    required this.rewardRep,
    required this.rewardXp,
    required this.rewardBadges,
    required this.rewardTitles,
    this.earnedAt,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json,
      {DateTime? earnedAt}) {
    return AchievementModel(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String? ?? 'trophy',
      rarity: json['rarity'] as String? ?? 'common',
      targetMetric: json['target_metric'] as String,
      targetValue: (json['target_value'] as num).toDouble(),
      rewardRep: json['reward_rep'] as int? ?? 0,
      rewardXp: json['reward_xp'] as int? ?? 0,
      rewardBadges: ((json['reward_badges'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      rewardTitles: ((json['reward_titles'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      earnedAt: earnedAt,
    );
  }

  Achievement toEntity() => Achievement(
        id: id,
        code: code,
        name: name,
        description: description ?? '',
        icon: icon,
        rarity: achievementRarityFromString(rarity),
        targetMetric: targetMetric,
        targetValue: targetValue,
        rewardRep: rewardRep,
        rewardXp: rewardXp,
        rewardBadgeIds: rewardBadges,
        rewardTitles: rewardTitles,
        earnedAt: earnedAt,
      );
}
