import '../../domain/entities/mission_claim.dart';
import 'mission_reward_model.dart';

class MissionClaimModel {
  final String id;
  final String profileId;
  final String missionId;
  final DateTime claimedAt;
  final List<MissionRewardModel> rewards;

  const MissionClaimModel({
    required this.id,
    required this.profileId,
    required this.missionId,
    required this.claimedAt,
    required this.rewards,
  });

  factory MissionClaimModel.fromJson(Map<String, dynamic> json,
      {List<MissionRewardModel> rewards = const []}) {
    return MissionClaimModel(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      missionId: json['mission_id'] as String,
      claimedAt: DateTime.parse(json['claimed_at'] as String),
      rewards: rewards,
    );
  }

  MissionClaim toEntity() => MissionClaim(
        id: id,
        profileId: profileId,
        missionId: missionId,
        claimedAt: claimedAt,
        rewards: rewards.map((r) => r.toEntity()).toList(),
      );
}
