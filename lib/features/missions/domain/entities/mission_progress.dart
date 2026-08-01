import 'package:equatable/equatable.dart';

/// Progresso runtime di un utente su una missione — riga `mission_progress`.
/// Scritta solo da `record_mission_event()`/`claim_mission()` lato server;
/// il client la legge soltanto (RLS self-select, nessuna insert/update).
class MissionProgress extends Equatable {
  final String profileId;
  final String missionId;
  final double currentValue;
  final bool completed;
  final DateTime? completedAt;
  final DateTime updatedAt;

  const MissionProgress({
    required this.profileId,
    required this.missionId,
    required this.currentValue,
    required this.completed,
    this.completedAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props =>
      [profileId, missionId, currentValue, completed, completedAt, updatedAt];
}
