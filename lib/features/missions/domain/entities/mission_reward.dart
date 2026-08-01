import 'package:equatable/equatable.dart';

enum MissionRewardType {
  rep,
  xp,
  badge,
  title,
  avatarFrame,
  glow,
  profileSkin,
  icon,
  missionPoints
}

MissionRewardType missionRewardTypeFromString(String value) {
  switch (value) {
    case 'rep':
      return MissionRewardType.rep;
    case 'xp':
      return MissionRewardType.xp;
    case 'badge':
      return MissionRewardType.badge;
    case 'title':
      return MissionRewardType.title;
    case 'avatar_frame':
      return MissionRewardType.avatarFrame;
    case 'glow':
      return MissionRewardType.glow;
    case 'profile_skin':
      return MissionRewardType.profileSkin;
    case 'icon':
      return MissionRewardType.icon;
    case 'mission_points':
      return MissionRewardType.missionPoints;
    default:
      return MissionRewardType.missionPoints;
  }
}

/// Un reward item concesso da un [MissionClaim] — riga `mission_rewards`.
/// Ledger normalizzato: un nuovo [MissionRewardType] non richiede mai una
/// migration, solo un nuovo valore stringa lato server.
class MissionReward extends Equatable {
  final String id;
  final String claimId;
  final MissionRewardType type;
  final Map<String, dynamic> value;
  final DateTime grantedAt;

  const MissionReward({
    required this.id,
    required this.claimId,
    required this.type,
    required this.value,
    required this.grantedAt,
  });

  @override
  List<Object?> get props => [id, claimId, type, value, grantedAt];
}
