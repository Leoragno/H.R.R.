import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/models/profile_model.dart';
import '../../trip/data/models/trip_model.dart';
import '../../trip/domain/entities/trip.dart';
import '../domain/social_models.dart';

/// Amici, sfide 1 vs 1 e dati di "La tua settimana". Le RPC stanno in
/// supabase/migrations/0039_challenges_presence.sql.
abstract class SocialRepository {
  /// Tutti gli altri profili (l'app è chiusa: sono tutti amici).
  Future<List<Friend>> friends(String me);

  Future<List<Challenge>> myChallenges();

  Future<void> createChallenge({
    required String opponentId,
    required ChallengeMetric metric,
    required int durationHours,
    required int stakeXp,
  });

  Future<void> respondChallenge(String id, {required bool accept});

  Future<void> cancelChallenge(String id);

  /// Aggiorna `last_seen_at` (il server ignora se è recente).
  Future<void> touchLastSeen();

  /// Viaggi completati di un pilota, dal più recente. Senza [withRoute]
  /// il tracciato non viaggia (basta per pilota e statistiche).
  Future<List<Trip>> tripsOf(String profileId,
      {DateTime? since, int limit, bool withRoute});

  /// Classifica per XP guadagnati in [from, to).
  Future<List<XpRank>> xpRanking(DateTime from, DateTime to);

  /// Esagoni presi e persi da [me] in [from, to).
  Future<({int got, int lost})> territoryBetween(
      String me, DateTime from, DateTime to);
}

/// Colonne di `trips` lette da TripModel, senza la geometria `route`.
const _tripColumns = 'id, driver_id, car_id, started_at, ended_at, '
    'distance_km, duration_seconds, avg_speed_kmh, max_speed_kmh, '
    'xp_earned, rep_earned, driving_score, status, elevation_gain_m, '
    'max_altitude_m, max_acceleration_ms2, max_deceleration_ms2, '
    'zero_to_hundred_seconds, peak_g_force, turns_left, turns_right, '
    'lane_changes, max_cornering_speed_kmh, braking_events, total_stops, '
    'stopped_seconds';

class SupabaseSocialRepository implements SocialRepository {
  SupabaseSocialRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Friend>> friends(String me) async {
    final rows = await _client
        .from('profiles')
        .select()
        .neq('id', me)
        .order('level', ascending: false)
        .order('username');
    return [
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        Friend(
          user: ProfileModel.fromJson(r).toEntity(),
          // Colonna aggiunta da 0039: assente finché la migrazione non è
          // applicata.
          lastSeenAt: r['last_seen_at'] == null
              ? null
              : DateTime.parse(r['last_seen_at'] as String).toLocal(),
        ),
    ];
  }

  @override
  Future<List<Challenge>> myChallenges() async {
    final rows = await _client.rpc('my_challenges');
    return [
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        Challenge.fromJson(r),
    ];
  }

  @override
  Future<void> createChallenge({
    required String opponentId,
    required ChallengeMetric metric,
    required int durationHours,
    required int stakeXp,
  }) =>
      _client.rpc('create_challenge', params: {
        'p_opponent': opponentId,
        'p_metric': metric.api,
        'p_duration_hours': durationHours,
        'p_stake_xp': stakeXp,
      });

  @override
  Future<void> respondChallenge(String id, {required bool accept}) => _client
      .rpc('respond_challenge', params: {'p_id': id, 'p_accept': accept});

  @override
  Future<void> cancelChallenge(String id) =>
      _client.rpc('cancel_challenge', params: {'p_id': id});

  @override
  Future<void> touchLastSeen() => _client.rpc('touch_last_seen');

  @override
  Future<List<Trip>> tripsOf(String profileId,
      {DateTime? since, int limit = 30, bool withRoute = false}) async {
    var q = _client
        .from('trips')
        .select(withRoute ? '$_tripColumns, route_geojson' : _tripColumns)
        .eq('driver_id', profileId)
        .eq('status', 'completed');
    if (since != null) q = q.gte('started_at', since.toUtc().toIso8601String());
    final rows = await q.order('started_at', ascending: false).limit(limit);
    return [
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        TripModel.fromJson(r).toEntity(),
    ];
  }

  @override
  Future<List<XpRank>> xpRanking(DateTime from, DateTime to) async {
    final rows = await _client.rpc('xp_ranking_between', params: {
      'p_from': from.toUtc().toIso8601String(),
      'p_to': to.toUtc().toIso8601String(),
    });
    return [
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        XpRank(r['profile_id'] as String, (r['xp'] as num).toInt()),
    ];
  }

  @override
  Future<({int got, int lost})> territoryBetween(
      String me, DateTime from, DateTime to) async {
    final f = from.toUtc().toIso8601String();
    final t = to.toUtc().toIso8601String();
    final got = await _client
        .from('territory_claim_log')
        .select('id')
        .eq('claimant_id', me)
        .gte('claimed_at', f)
        .lt('claimed_at', t)
        .count(CountOption.exact);
    final lost = await _client
        .from('territory_claim_log')
        .select('id')
        .eq('previous_owner_id', me)
        .neq('claimant_id', me)
        .gte('claimed_at', f)
        .lt('claimed_at', t)
        .count(CountOption.exact);
    return (got: got.count, lost: lost.count);
  }
}
