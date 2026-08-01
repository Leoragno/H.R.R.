import 'package:equatable/equatable.dart';

/// Contributo di un singolo membro a una [CrewMission] — riga `crew_progress`.
class CrewProgress extends Equatable {
  final String crewId;
  final String missionId;
  final String profileId;
  final double contribution;

  const CrewProgress({
    required this.crewId,
    required this.missionId,
    required this.profileId,
    required this.contribution,
  });

  @override
  List<Object?> get props => [crewId, missionId, profileId, contribution];
}
