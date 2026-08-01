import '../../domain/entities/crew_mission.dart';

/// DTO per `crew_missions` — letto con un embed su `missions(title,
/// description)` perché titolo/descrizione vivono sulla missione
/// collegata, non duplicati su crew_missions.
class CrewMissionModel {
  final String id;
  final String crewId;
  final String missionId;
  final String title;
  final String description;
  final double targetValue;
  final double currentValue;
  final int rewardRep;
  final int rewardXp;
  final DateTime? startsAt;
  final DateTime? endsAt;

  const CrewMissionModel({
    required this.id,
    required this.crewId,
    required this.missionId,
    required this.title,
    required this.description,
    required this.targetValue,
    required this.currentValue,
    required this.rewardRep,
    required this.rewardXp,
    this.startsAt,
    this.endsAt,
  });

  factory CrewMissionModel.fromJson(Map<String, dynamic> json) {
    final mission = json['missions'] as Map<String, dynamic>?;
    return CrewMissionModel(
      id: json['id'] as String,
      crewId: json['crew_id'] as String,
      missionId: json['mission_id'] as String,
      title: mission?['title'] as String? ?? '',
      description: mission?['description'] as String? ?? '',
      targetValue: (json['target_value'] as num).toDouble(),
      currentValue: (json['current_value'] as num?)?.toDouble() ?? 0,
      rewardRep: mission?['rep_reward'] as int? ?? 0,
      rewardXp: mission?['xp_reward'] as int? ?? 0,
      startsAt: json['starts_at'] == null
          ? null
          : DateTime.parse(json['starts_at'] as String),
      endsAt: json['ends_at'] == null
          ? null
          : DateTime.parse(json['ends_at'] as String),
    );
  }

  CrewMission toEntity() => CrewMission(
        id: id,
        crewId: crewId,
        missionId: missionId,
        title: title,
        description: description,
        targetValue: targetValue,
        currentValue: currentValue,
        rewardRep: rewardRep,
        rewardXp: rewardXp,
        startsAt: startsAt,
        endsAt: endsAt,
      );
}
