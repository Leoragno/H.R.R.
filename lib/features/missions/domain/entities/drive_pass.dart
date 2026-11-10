import 'package:equatable/equatable.dart';

/// Pass di guida (0041_xp_economy.sql): stagione = trimestre, un tier ogni
/// 1000 XP stagionali, massimo 30. I premi si riscuotono a mano.
const kPassXpPerTier = 1000;
const kPassMaxTier = 30;

enum PassRewardKind { xp150, xp250, accent, emote, skin, title }

/// Stessa tabella di `pass_reward_kind` lato server.
PassRewardKind passRewardKind(int tier) {
  if (tier == 30) return PassRewardKind.title;
  if (tier % 5 == 0) return PassRewardKind.skin;
  return switch (tier % 4) {
    0 => PassRewardKind.xp150,
    1 => PassRewardKind.xp250,
    2 => PassRewardKind.accent,
    _ => PassRewardKind.emote,
  };
}

String passRewardLabel(PassRewardKind k) => switch (k) {
      PassRewardKind.xp150 => '+150 XP',
      PassRewardKind.xp250 => '+250 XP',
      PassRewardKind.accent => 'colore neon',
      PassRewardKind.emote => 'emote esultanza',
      PassRewardKind.skin => 'skin mascotte',
      PassRewardKind.title => 'titolo stagione',
    };

class DrivePass extends Equatable {
  const DrivePass({
    required this.season,
    required this.startsAt,
    required this.endsAt,
    required this.seasonXp,
    required this.tier,
    required this.claimed,
  });

  /// es. "2026-Q4".
  final String season;
  final DateTime startsAt;
  final DateTime endsAt;
  final int seasonXp;
  final int tier;
  final Set<int> claimed;

  bool get maxed => tier >= kPassMaxTier;

  /// XP dentro il tier in corso (0–999).
  int get xpInTier => maxed ? kPassXpPerTier : seasonXp % kPassXpPerTier;

  int get toClaim => [
        for (var t = 1; t <= tier; t++)
          if (!claimed.contains(t)) t
      ].length;

  bool canClaim(int t) => t <= tier && !claimed.contains(t);

  int daysLeft(DateTime now) =>
      endsAt.difference(now).inDays.clamp(0, 999).toInt();

  /// "al tier 8: colore neon · mancano 420 XP".
  String nextRewardLabel() {
    if (maxed) return 'pass completato';
    final next = tier + 1;
    return 'al tier $next: ${passRewardLabel(passRewardKind(next))} · '
        'mancano ${kPassXpPerTier - xpInTier} XP';
  }

  /// I 12 tier mostrati nella pista: si parte da 3 prima di quello attuale.
  List<int> trackTiers() {
    final start = (tier - 3).clamp(1, kPassMaxTier - 11).toInt();
    return [for (var i = 0; i < 12; i++) start + i];
  }

  factory DrivePass.fromJson(Map<String, dynamic> j) => DrivePass(
        season: j['season'] as String,
        startsAt: DateTime.parse(j['starts_at'] as String),
        endsAt: DateTime.parse(j['ends_at'] as String),
        seasonXp: (j['season_xp'] as num).toInt(),
        tier: (j['tier'] as num).toInt(),
        claimed: {
          for (final t in (j['claimed'] as List? ?? const []))
            (t as num).toInt()
        },
      );

  @override
  List<Object?> get props =>
      [season, startsAt, endsAt, seasonXp, tier, claimed];
}

/// Cosmetici sbloccati (tabella profile_unlocks).
class Unlocks {
  const Unlocks(this.items);
  final Set<String> items;

  bool has(String item) => items.contains(item);
  bool accent(String name) => items.contains('accent:$name');
  bool get emote => items.contains('emote:esultanza');
  bool get neonSkin => items.contains('skin:neon');
  bool get seasonTitle => items.contains('title:re_della_stagione');
}
