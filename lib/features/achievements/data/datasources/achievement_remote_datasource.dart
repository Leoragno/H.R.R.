import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/achievement_model.dart';

/// Unico punto della feature Achievements che importa supabase_flutter.
class AchievementRemoteDatasource {
  final SupabaseClient _client;

  AchievementRemoteDatasource(this._client);

  /// `achievements` è catalogo pubblico, `user_achievements` è self-only:
  /// due letture separate unite lato client (niente join cross-tabella
  /// con policy diverse, più semplice e altrettanto corretto qui).
  Future<List<AchievementModel>> myAchievements(String profileId) async {
    final achievementRows =
        await _client.from('achievements').select().order('target_value');
    final earnedRows = await _client
        .from('user_achievements')
        .select()
        .eq('profile_id', profileId);

    final earnedAtByAchievementId = <String, DateTime>{
      for (final row in earnedRows as List)
        (row as Map<String, dynamic>)['achievement_id'] as String:
            DateTime.parse(row['earned_at'] as String),
    };

    return (achievementRows as List).map((r) {
      final row = r as Map<String, dynamic>;
      return AchievementModel.fromJson(row,
          earnedAt: earnedAtByAchievementId[row['id'] as String]);
    }).toList();
  }
}
