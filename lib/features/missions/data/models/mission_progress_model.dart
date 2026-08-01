import '../../domain/entities/mission_progress.dart';

class MissionProgressModel {
  final String profileId;
  final String missionId;
  final double currentValue;
  final bool completed;
  final DateTime? completedAt;
  final DateTime updatedAt;

  const MissionProgressModel({
    required this.profileId,
    required this.missionId,
    required this.currentValue,
    required this.completed,
    this.completedAt,
    required this.updatedAt,
  });

  factory MissionProgressModel.fromJson(Map<String, dynamic> json) {
    return MissionProgressModel(
      profileId: json['profile_id'] as String,
      missionId: json['mission_id'] as String,
      currentValue: (json['current_value'] as num?)?.toDouble() ?? 0,
      completed: json['completed'] as bool? ?? false,
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      updatedAt: json['updated_at'] == null
          ? DateTime.now()
          : DateTime.parse(json['updated_at'] as String),
    );
  }

  MissionProgress toEntity() => MissionProgress(
        profileId: profileId,
        missionId: missionId,
        currentValue: currentValue,
        completed: completed,
        completedAt: completedAt,
        updatedAt: updatedAt,
      );
}
