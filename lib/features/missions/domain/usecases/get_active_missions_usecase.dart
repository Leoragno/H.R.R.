import '../entities/mission.dart';
import '../repositories/mission_repository.dart';

/// Missioni attive per tipo, usata dai tab Daily/Weekly/Season/Secret di
/// `missions_screen.dart`. Wrapper sottile — nessuna orchestrazione oltre
/// alla lettura, ma esposta come UseCase come richiesto esplicitamente per
/// questa feature (a differenza del resto del progetto, dove le
/// presentation chiamano il repository direttamente).
class GetActiveMissionsUseCase {
  final MissionRepository _repository;
  const GetActiveMissionsUseCase(this._repository);

  Future<List<Mission>> call({MissionType? type}) =>
      _repository.activeMissions(type: type);
}
