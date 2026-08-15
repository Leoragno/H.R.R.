import 'package:equatable/equatable.dart';

enum MissionType { daily, weekly, seasonal, event, secret }

MissionType missionTypeFromString(String value) {
  return MissionType.values
      .firstWhere((t) => t.name == value, orElse: () => MissionType.daily);
}

enum MissionDifficulty { easy, normal, hard, elite }

MissionDifficulty missionDifficultyFromString(String value) {
  return MissionDifficulty.values.firstWhere((d) => d.name == value,
      orElse: () => MissionDifficulty.normal);
}

/// Missione — entità di dominio pura. Descrive una missione istanziata
/// (riga `missions`, generata da un `mission_templates` o seminata come
/// one-off/secret), non un template. `currentValue`/`completed` restano
/// su [MissionProgress], fatto runtime per-utente separato di proposito.
class Mission extends Equatable {
  final String id;
  final String code;
  final String title;
  final String description;
  final String icon;
  final MissionType type;
  final MissionDifficulty difficulty;
  final double targetValue;
  final String targetMetric;
  final int rewardXp;
  final int rewardRep;
  final List<String> rewardBadgeIds;
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

  const Mission({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.icon,
    required this.type,
    required this.difficulty,
    required this.targetValue,
    required this.targetMetric,
    required this.rewardXp,
    required this.rewardRep,
    required this.rewardBadgeIds,
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

  @override
  List<Object?> get props => [
        id,
        code,
        title,
        description,
        icon,
        type,
        difficulty,
        targetValue,
        targetMetric,
        rewardXp,
        rewardRep,
        rewardBadgeIds,
        rewardTitles,
        rewardProfileItems,
        rewardAvatarFrame,
        hidden,
        secret,
        repeatable,
        seasonId,
        eventId,
        startsAt,
        endsAt,
        createdAt,
        updatedAt,
      ];
}
