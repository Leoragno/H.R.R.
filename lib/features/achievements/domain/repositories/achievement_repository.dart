import '../entities/achievement.dart';

/// Contratto Achievements. Nessun metodo di "claim": gli achievement sono
/// assegnati automaticamente lato server (`evaluate_achievements()`,
/// richiamata da `record_mission_event`), il client legge soltanto.
abstract class AchievementRepository {
  Future<List<Achievement>> myAchievements();
}
