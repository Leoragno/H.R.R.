import 'package:equatable/equatable.dart';

/// Istanza di missione crew-scoped — riga `crew_missions`. `currentValue`
/// è la somma delle `crew_progress.contribution` dei membri, ricalcolata
/// lato server dentro `record_mission_event()`; il client non la scrive mai.
class CrewMission extends Equatable {
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

  const CrewMission({
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

  @override
  List<Object?> get props => [
        id,
        crewId,
        missionId,
        title,
        description,
        targetValue,
        currentValue,
        rewardRep,
        rewardXp,
        startsAt,
        endsAt
      ];
}
