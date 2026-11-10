import 'package:flutter_test/flutter_test.dart';
import 'package:hrr_app/features/game/domain/territory_decay.dart';
import 'package:hrr_app/features/missions/domain/entities/drive_pass.dart';

DrivePass pass({int xp = 0, Set<int> claimed = const {}}) => DrivePass(
      season: '2026-Q4',
      startsAt: DateTime.utc(2026, 9, 30, 22),
      endsAt: DateTime.utc(2026, 12, 31, 23),
      seasonXp: xp,
      tier: (xp ~/ kPassXpPerTier).clamp(0, kPassMaxTier),
      claimed: claimed,
    );

void main() {
  test('premi del pass come pass_reward_kind lato server', () {
    expect(passRewardKind(1), PassRewardKind.xp250);
    expect(passRewardKind(2), PassRewardKind.accent);
    expect(passRewardKind(3), PassRewardKind.emote);
    expect(passRewardKind(4), PassRewardKind.xp150);
    expect(passRewardKind(5), PassRewardKind.skin);
    expect(passRewardKind(10), PassRewardKind.skin);
    expect(passRewardKind(30), PassRewardKind.title);
  });

  test('tier, XP nel tier e premi da riscuotere', () {
    final p = pass(xp: 3420, claimed: {1});
    expect(p.tier, 3);
    expect(p.xpInTier, 420);
    expect(p.toClaim, 2);
    expect(p.canClaim(1), isFalse);
    expect(p.canClaim(3), isTrue);
    expect(p.canClaim(4), isFalse);
    expect(p.nextRewardLabel(), 'al tier 4: +150 XP · mancano 580 XP');
  });

  test('pista di 12 tier intorno a quello attuale', () {
    expect(pass().trackTiers().first, 1);
    expect(pass(xp: 10000).trackTiers().first, 7);
    expect(pass(xp: 40000).trackTiers().last, 30);
    expect(pass(xp: 40000).maxed, isTrue);
  });

  test('parse di my_pass', () {
    final p = DrivePass.fromJson(const {
      'season': '2026-Q4',
      'starts_at': '2026-09-30T22:00:00+00:00',
      'ends_at': '2026-12-31T23:00:00+00:00',
      'season_xp': 2500,
      'tier': 2,
      'claimed': [1],
    });
    expect(p.tier, 2);
    expect(p.claimed, {1});
  });

  test('R3X: territori decadono un giorno prima', () {
    expect(territoryDecayDaysForMascot('r3x'), 13);
    expect(territoryDecayDaysForMascot('nitro'), 14);
    expect(territoryDecayDaysForMascot(null), 14);
  });
}
