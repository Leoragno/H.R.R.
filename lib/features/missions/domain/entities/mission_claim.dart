import 'package:equatable/equatable.dart';

import 'mission_reward.dart';

/// Risultato di un riscatto — riga `mission_claims` + i [MissionReward]
/// concessi in quella transazione, usato per popolare l'overlay di
/// celebrazione in `missions_screen.dart`.
class MissionClaim extends Equatable {
  final String id;
  final String profileId;
  final String missionId;
  final DateTime claimedAt;
  final List<MissionReward> rewards;

  const MissionClaim({
    required this.id,
    required this.profileId,
    required this.missionId,
    required this.claimedAt,
    required this.rewards,
  });

  @override
  List<Object?> get props => [id, profileId, missionId, claimedAt, rewards];
}
