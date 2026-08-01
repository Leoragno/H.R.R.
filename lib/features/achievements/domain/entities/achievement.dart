import 'package:equatable/equatable.dart';

enum AchievementRarity { common, uncommon, rare, epic, legendary }

AchievementRarity achievementRarityFromString(String value) {
  return AchievementRarity.values.firstWhere((r) => r.name == value,
      orElse: () => AchievementRarity.common);
}

/// Achievement — permanente, non ripetibile (a differenza delle missioni).
/// `earnedAt` non nullo significa ottenuto: gli achievement non hanno un
/// pulsante di riscatto, vengono assegnati automaticamente lato server
/// quando l'aggregato profilo (`target_metric`) supera `targetValue`.
class Achievement extends Equatable {
  final String id;
  final String code;
  final String name;
  final String description;
  final String icon;
  final AchievementRarity rarity;
  final String targetMetric;
  final double targetValue;
  final int rewardRep;
  final int rewardXp;
  final List<String> rewardBadgeIds;
  final List<String> rewardTitles;
  final DateTime? earnedAt;

  const Achievement({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.icon,
    required this.rarity,
    required this.targetMetric,
    required this.targetValue,
    required this.rewardRep,
    required this.rewardXp,
    required this.rewardBadgeIds,
    required this.rewardTitles,
    this.earnedAt,
  });

  bool get isEarned => earnedAt != null;

  @override
  List<Object?> get props => [
        id,
        code,
        name,
        description,
        icon,
        rarity,
        targetMetric,
        targetValue,
        rewardRep,
        rewardXp,
        rewardBadgeIds,
        rewardTitles,
        earnedAt,
      ];
}
