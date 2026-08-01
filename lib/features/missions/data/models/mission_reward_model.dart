import '../../domain/entities/mission_reward.dart';

class MissionRewardModel {
  final String id;
  final String claimId;
  final String rewardType;
  final Map<String, dynamic> rewardValue;
  final DateTime grantedAt;

  const MissionRewardModel({
    required this.id,
    required this.claimId,
    required this.rewardType,
    required this.rewardValue,
    required this.grantedAt,
  });

  factory MissionRewardModel.fromJson(Map<String, dynamic> json) {
    return MissionRewardModel(
      id: json['id'] as String,
      claimId: json['claim_id'] as String,
      rewardType: json['reward_type'] as String,
      rewardValue:
          Map<String, dynamic>.from(json['reward_value'] as Map? ?? const {}),
      grantedAt: DateTime.parse(json['granted_at'] as String),
    );
  }

  MissionReward toEntity() => MissionReward(
        id: id,
        claimId: claimId,
        type: missionRewardTypeFromString(rewardType),
        value: rewardValue,
        grantedAt: grantedAt,
      );
}
