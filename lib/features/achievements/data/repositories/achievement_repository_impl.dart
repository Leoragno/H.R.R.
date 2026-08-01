import '../../domain/entities/achievement.dart';
import '../../domain/repositories/achievement_repository.dart';
import '../datasources/achievement_remote_datasource.dart';

class AchievementRepositoryImpl implements AchievementRepository {
  final AchievementRemoteDatasource _remote;
  final String Function() _currentProfileId;

  AchievementRepositoryImpl(this._remote, this._currentProfileId);

  @override
  Future<List<Achievement>> myAchievements() async {
    final achievements = await _remote.myAchievements(_currentProfileId());
    return achievements.map((a) => a.toEntity()).toList();
  }
}
