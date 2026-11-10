import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/domain/entities/app_user.dart';

/// Un altro pilota. L'app è privata e chiusa (migrazione 0027): tutti gli
/// iscritti sono già amici, quindi "amico" = ogni altro profilo.
class Friend {
  const Friend({required this.user, this.lastSeenAt});

  final AppUser user;

  /// `profiles.last_seen_at` (0039); null se mai visto o colonna assente.
  final DateTime? lastSeenAt;

  String get id => user.id;
  String get username => user.username;
}

/// Stato mostrato accanto a un amico: etichetta + colore.
class FriendStatus {
  const FriendStatus(this.label, this.color, {this.live = false});
  final String label;
  final Color color;

  /// In guida adesso (riga con stato pulsante).
  final bool live;
}

/// IN GUIDA (canale realtime) > ONLINE (visto negli ultimi 5 minuti) >
/// "visto N fa".
FriendStatus friendStatus(Friend f,
    {required bool driving, required DateTime now}) {
  if (driving) {
    return const FriendStatus('IN GUIDA', AppColor.success, live: true);
  }
  final seen = f.lastSeenAt;
  if (seen == null) return const FriendStatus('—', AppColor.inkFaint);
  final d = now.difference(seen);
  if (d.inMinutes < 5) return const FriendStatus('ONLINE', AppColor.success);
  return FriendStatus(agoLabel(seen, now), AppColor.inkFaint);
}

/// "12 MIN FA", "3 H FA", "IERI", "4 G FA", "dd/mm".
String agoLabel(DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.inMinutes < 1) return 'ADESSO';
  if (d.inMinutes < 60) return '${d.inMinutes} MIN FA';
  if (d.inHours < 24) return '${d.inHours} H FA';
  if (d.inDays < 2) return 'IERI';
  if (d.inDays < 7) return '${d.inDays} G FA';
  return '${at.day.toString().padLeft(2, '0')}/'
      '${at.month.toString().padLeft(2, '0')}';
}

enum ChallengeMetric {
  flow('flow', 'FLOW', Icons.auto_graph_rounded),
  topSpeed('top_speed', 'TOP SPEED', Icons.speed_rounded),
  km('km', 'KM', Icons.route_rounded),
  hexes('hexes', 'ESAGONI', Icons.hexagon_rounded);

  const ChallengeMetric(this.api, this.label, this.icon);
  final String api;
  final String label;
  final IconData icon;

  static ChallengeMetric fromApi(String v) =>
      values.firstWhere((m) => m.api == v, orElse: () => ChallengeMetric.flow);

  /// Valore formattato per la card (FLOW 0-100, km/h, km con una cifra).
  String format(num v) => switch (this) {
        ChallengeMetric.flow || ChallengeMetric.hexes => v.round().toString(),
        ChallengeMetric.topSpeed => v.round().toString(),
        ChallengeMetric.km => v.toStringAsFixed(1).replaceAll('.', ','),
      };
}

enum ChallengeStatus {
  pending,
  declined,
  cancelled,
  expired,
  active,
  finished;

  static ChallengeStatus fromApi(String v) => values
      .firstWhere((s) => s.name == v, orElse: () => ChallengeStatus.expired);
}

enum ChallengeOutcome { won, lost, draw }

class Challenge {
  const Challenge({
    required this.id,
    required this.challengerId,
    required this.opponentId,
    required this.metric,
    required this.durationHours,
    required this.stakeXp,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.endsAt,
    this.challengerScore = 0,
    this.opponentScore = 0,
    this.winnerId,
  });

  final String id;
  final String challengerId;
  final String opponentId;
  final ChallengeMetric metric;
  final int durationHours;
  final int stakeXp;
  final ChallengeStatus status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? endsAt;
  final num challengerScore;
  final num opponentScore;
  final String? winnerId;

  factory Challenge.fromJson(Map<String, dynamic> j) => Challenge(
        id: j['id'] as String,
        challengerId: j['challenger_id'] as String,
        opponentId: j['opponent_id'] as String,
        metric: ChallengeMetric.fromApi(j['metric'] as String),
        durationHours: (j['duration_hours'] as num).toInt(),
        stakeXp: (j['stake_xp'] as num).toInt(),
        status: ChallengeStatus.fromApi(j['status'] as String),
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        acceptedAt: _date(j['accepted_at']),
        endsAt: _date(j['ends_at']),
        challengerScore: (j['challenger_score'] as num?) ?? 0,
        opponentScore: (j['opponent_score'] as num?) ?? 0,
        winnerId: j['winner_id'] as String?,
      );

  bool iAmChallenger(String me) => challengerId == me;
  String otherId(String me) => iAmChallenger(me) ? opponentId : challengerId;
  num myScore(String me) => iAmChallenger(me) ? challengerScore : opponentScore;
  num theirScore(String me) =>
      iAmChallenger(me) ? opponentScore : challengerScore;

  /// Richiesta ricevuta a cui devo rispondere.
  bool incomingFor(String me) =>
      status == ChallengeStatus.pending && opponentId == me;

  /// Richiesta lanciata da me, in attesa dell'altro.
  bool outgoingFor(String me) =>
      status == ChallengeStatus.pending && challengerId == me;

  ChallengeOutcome? outcomeFor(String me) {
    if (status != ChallengeStatus.finished) return null;
    if (winnerId == null) return ChallengeOutcome.draw;
    return winnerId == me ? ChallengeOutcome.won : ChallengeOutcome.lost;
  }

  String get durationLabel => durationHours >= 72 ? '3 GIORNI' : '24 H';
}

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toLocal();

/// "5 H 12 MIN", "2 G 4 H", "32 MIN".
String timeLeftLabel(DateTime end, DateTime now) {
  final d = end.difference(now);
  if (d.isNegative) return 'FINITA';
  if (d.inDays >= 1) return '${d.inDays} G ${d.inHours % 24} H';
  if (d.inHours >= 1) return '${d.inHours} H ${d.inMinutes % 60} MIN';
  return '${d.inMinutes.clamp(1, 59)} MIN';
}

/// Vinte/perse in una lista di sfide.
({int won, int lost}) recordOf(Iterable<Challenge> list, String me) {
  var w = 0, l = 0;
  for (final c in list) {
    switch (c.outcomeFor(me)) {
      case ChallengeOutcome.won:
        w++;
      case ChallengeOutcome.lost:
        l++;
      default:
    }
  }
  return (won: w, lost: l);
}

/// Riga della classifica XP di un periodo (RPC `xp_ranking_between`).
class XpRank {
  const XpRank(this.profileId, this.xp);
  final String profileId;
  final int xp;
}

/// Posizione (1-based) di [me] in [ranking]; null se assente.
int? positionOf(List<XpRank> ranking, String me) {
  final i = ranking.indexWhere((r) => r.profileId == me);
  return i < 0 ? null : i + 1;
}
