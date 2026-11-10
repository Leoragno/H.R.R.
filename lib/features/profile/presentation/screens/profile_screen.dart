import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';
import '../../../../core/theme/hrr_icons.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../../achievements/domain/entities/achievement.dart';
import '../../../achievements/presentation/providers/achievement_provider.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../missions/presentation/providers/economy_providers.dart';
import '../../../pilots/presentation/widgets/pilot_emblem.dart';
import '../../../progression/domain/bond.dart';
import '../../../progression/presentation/progression_providers.dart';
import '../../../rival/domain/entities/mascot.dart';
import '../../../rival/presentation/providers/active_mascot_provider.dart';
import '../../../rival/presentation/widgets/neon_skin.dart';
import '../../../trip/domain/driver_archetype.dart';

/// Profilo (handoff HEAT, schermata 17): hero con la mascotte, username,
/// statistiche, compagno, "Che pilota sei", ride, anteprima achievement e
/// collegamenti. Sola lettura: la modifica dei dati resta in Impostazioni.
///
/// Legame/bonus della mascotte arrivano con la fase economia XP: finché
/// non sono reali non vengono mostrati.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    if (profile == null) {
      return Scaffold(
        backgroundColor: AppColor.base,
        body: Center(child: CircularProgressIndicator(color: AppColor.accent)),
      );
    }
    final mascot = ref.watch(activeMascotProvider);
    final level = ref.watch(levelProgressProvider);
    final bond = ref.watch(activeBondProvider);
    final cosmetics = ref.watch(cosmeticsProvider);
    final pilots = ref.watch(pilotHistoryProvider);
    final achievements =
        ref.watch(myAchievementsProvider).valueOrNull ?? const <Achievement>[];

    var i = 0;
    return Scaffold(
      backgroundColor: AppColor.base,
      body: ListView(
        padding:
            EdgeInsets.only(bottom: 30 + MediaQuery.paddingOf(context).bottom),
        children: [
          _Hero(
            profile: profile,
            mascot: mascot,
            neon: cosmetics.neonSkin,
            title: cosmetics.title,
            levelLabel: level == null
                ? 'LV ${profile.level}'
                : 'LV ${level.level} · ${level.title}',
          ),
          HeatEnter(
            index: i++,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  for (final (k, s) in [
                    (profile.totalKm.toStringAsFixed(0), 'KM'),
                    ('${profile.totalTrips}', 'GUIDE'),
                    ('${profile.rep}', 'REP'),
                  ].indexed) ...[
                    if (k > 0) const SizedBox(width: 5),
                    Expanded(child: _StatTile(value: s.$1, label: s.$2)),
                  ],
                ],
              ),
            ),
          ),
          _Header(
            'IL TUO COMPAGNO',
            action: 'CAMBIA',
            actionIcon: Icons.sync_alt_rounded,
            onAction: () => context.push(AppRoutes.settings),
          ),
          HeatEnter(
            index: i++,
            child: _CompanionCard(
                mascot: mascot, bond: bond, neon: cosmetics.neonSkin),
          ),
          HeatEnter(
            index: i++,
            child: _BondUnlocks(mascot: mascot, bond: bond),
          ),
          _Header(
            'CHE PILOTA SEI',
            action: 'TUTTI I PILOTI',
            actionIcon: Icons.chevron_right_rounded,
            onAction: () => context.push(AppRoutes.pilots),
          ),
          HeatEnter(index: i++, child: _PilotCard(history: pilots)),
          const _Header('IL TUO RIDE'),
          HeatEnter(
            index: i++,
            child: _RideCard(
              profile: profile,
              onTap: () => context.push(AppRoutes.settings),
            ),
          ),
          _Header(
            'ACHIEVEMENT · ${achievements.where((a) => a.isEarned).length}',
            action: 'TUTTI',
            actionIcon: Icons.chevron_right_rounded,
            onAction: () => context.push(AppRoutes.achievements),
          ),
          HeatEnter(
            index: i++,
            child: _AchievementPreview(
              achievements: achievements,
              onTap: () => context.push(AppRoutes.achievements),
            ),
          ),
          const SizedBox(height: 16),
          for (final (icon, color, label, route) in [
            (Icons.group_rounded, AppColor.ink, 'AMICI', AppRoutes.friends),
            (
              Icons.sports_mma_rounded,
              AppColor.danger,
              'SFIDE 1 VS 1',
              AppRoutes.challenges
            ),
            (
              Icons.auto_stories_rounded,
              AppColor.ink,
              'LA TUA SETTIMANA',
              AppRoutes.week
            ),
            (Icons.flag_rounded, AppColor.gold, 'MISSIONI', AppRoutes.missions),
            (
              Icons.hexagon_outlined,
              AppColor.accent,
              'I MIEI TERRITORI',
              AppRoutes.myTerritories
            ),
            (
              Icons.settings_rounded,
              AppColor.inkMuted,
              'IMPOSTAZIONI',
              AppRoutes.settings
            ),
          ])
            HeatEnter(
              index: i++,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 5),
                child: _LinkRow(
                  icon: icon,
                  color: color,
                  label: label,
                  onTap: () => context.push(route),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.profile,
    required this.mascot,
    required this.levelLabel,
    this.neon = false,
    this.title,
  });
  final AppUser profile;
  final Mascot mascot;
  final String levelLabel;
  final bool neon;

  /// Titolo sbloccato ("LEGGENDA DI …" / "RE DELLA STAGIONE").
  final String? title;

  @override
  Widget build(BuildContext context) {
    final c = mascot.accentColor;
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: 342 + top,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(.6, -.1),
                  radius: .95,
                  colors: [c.withValues(alpha: .35), c.withValues(alpha: 0)],
                  stops: const [0, .7],
                ),
              ),
            ),
          ),
          Positioned(
            right: -30,
            bottom: 34,
            width: 250,
            height: 284,
            child: NeonSkin(
              on: neon,
              color: c,
              child: Image.asset(
                'assets/mascots/${mascot.id}_hero.png',
                fit: BoxFit.contain,
                alignment: Alignment.bottomRight,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ).animate(onPlay: (ctl) => ctl.repeat(reverse: true)).moveY(
                begin: 0, end: -8, duration: 2250.ms, curve: Curves.easeInOut),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 160,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x000B0912), AppColor.base],
                  stops: [0, .72],
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            top: top + 4,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go(AppRoutes.home),
                  icon:
                      const Icon(Icons.arrow_back_rounded, color: AppColor.ink),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => context.push(AppRoutes.settings),
                  icon: const Icon(Icons.settings_rounded, color: AppColor.ink),
                ),
              ],
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: ShapeDecoration(
                      color: c, shape: const SlantBorder.all(6)),
                  child: Text('PILOTA ${mascot.name}',
                      style: AppType.display(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.4,
                          color: AppColor.onAccent)),
                ),
                if (title != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.workspace_premium_rounded,
                          size: 16, color: AppColor.gold),
                      const SizedBox(width: 4),
                      Text(title!,
                          style: AppType.display(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1.4,
                              color: AppColor.gold)),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('@${profile.username}',
                      style: AppType.display(
                          fontWeight: FontWeight.w900,
                          fontSize: 56,
                          height: .85)),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    levelLabel,
                    if (profile.country != null && profile.country!.isNotEmpty)
                      profile.country!,
                  ].join(' · '),
                  style: AppType.body.copyWith(color: AppColor.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return HeatPanel(
      shape: const SlantBorder.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style:
                    AppType.display(fontWeight: FontWeight.w900, fontSize: 26)),
          ),
          Text(label,
              style: AppType.label.copyWith(fontSize: 12, letterSpacing: 1.4)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text, {this.action, this.actionIcon, this.onAction});
  final String text;
  final String? action;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final a = AppColor.accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: SectionLabel(text)),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(action!,
                        style: AppType.label.copyWith(
                            fontSize: 13, letterSpacing: 1.6, color: a)),
                    if (actionIcon != null)
                      Icon(actionIcon, size: 18, color: a),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompanionCard extends StatelessWidget {
  const _CompanionCard(
      {required this.mascot, required this.bond, required this.neon});
  final Mascot mascot;
  final BondProgress bond;
  final bool neon;

  @override
  Widget build(BuildContext context) {
    final c = mascot.accentColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: ClipPath(
        clipper: const ShapeBorderClipper(shape: ChamferBorder(cut: 14)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 130),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c.withValues(alpha: .35), AppColor.surface],
              stops: const [0, .62],
            ),
            border: Border(
              top: BorderSide(color: c, width: 2),
              left: const BorderSide(color: AppColor.line),
              right: const BorderSide(color: AppColor.line),
              bottom: const BorderSide(color: AppColor.line),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: -6,
                bottom: 0,
                width: 124,
                height: 140,
                child: NeonSkin(
                  on: neon,
                  color: c,
                  child: Image.asset(
                    'assets/mascots/${mascot.id}_hero.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomCenter,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(120, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(mascot.name,
                              style: AppType.display(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 24,
                                  height: 1)),
                        ),
                        Text('LEGAME LV ${bond.level}',
                            style: AppType.label.copyWith(
                                fontSize: 12, letterSpacing: 1.4, color: c)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SkewBar(
                      value: bond.fraction,
                      height: 6,
                      color: c,
                      track: AppColor.surfaceHigh,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        bond.maxed
                            ? 'legame massimo'
                            : '${bond.toNext} punti al livello ${bond.level + 1}',
                        '+${bond.bonusPercent}% bonus mascotte',
                      ].join(' · '),
                      style:
                          AppType.text(fontSize: 11, color: AppColor.inkMuted),
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 4),
                    Text(mascot.personalityTag.toUpperCase(),
                        style: AppType.label.copyWith(
                            fontSize: 12, letterSpacing: 1.4, color: c)),
                    const SizedBox(height: 8),
                    Text('"${mascot.tagline}"',
                        style: AppType.body.copyWith(height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _bondIcon(int lv) => switch (lv) {
      2 => Icons.sentiment_very_satisfied_rounded,
      3 => Icons.graphic_eq_rounded,
      5 => Icons.auto_awesome_rounded,
      7 => Icons.timeline_rounded,
      _ => Icons.military_tech_rounded,
    };

/// Sblocchi del legame (LV 2/3/5/7/10): accesi nel colore della mascotte,
/// gli altri spenti col lucchetto. Sotto, il prossimo sblocco.
class _BondUnlocks extends StatelessWidget {
  const _BondUnlocks({required this.mascot, required this.bond});
  final Mascot mascot;
  final BondProgress bond;

  @override
  Widget build(BuildContext context) {
    final c = mascot.accentColor;
    final next = bond.nextUnlock;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 5, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final (i, e) in kBondUnlocks.entries.indexed) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: _BondTile(
                    level: e.key,
                    label: e.key == 10 ? 'titolo' : e.value,
                    on: bond.unlocked(e.key),
                    color: c,
                  ),
                ),
              ],
            ],
          ),
          if (next != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 2),
              child: Text(
                'PROSSIMO SBLOCCO · a LV ${next.$1}: '
                '${next.$1 == 10 ? 'titolo «leggenda di ${mascot.name.toLowerCase()}»' : next.$2}',
                style: AppType.label.copyWith(
                    fontSize: 11, letterSpacing: 1.2, color: AppColor.gold),
              ),
            ),
        ],
      ),
    );
  }
}

class _BondTile extends StatelessWidget {
  const _BondTile({
    required this.level,
    required this.label,
    required this.on,
    required this.color,
  });
  final int level;
  final String label;
  final bool on;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = on ? color : AppColor.inkFaint;
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
      decoration: BoxDecoration(
        color: on ? color.withValues(alpha: .15) : AppColor.deep,
        border: Border.all(color: on ? color : AppColor.line),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -4,
            right: 1,
            child: Icon(on ? Icons.check_rounded : Icons.lock_rounded,
                size: 11, color: c),
          ),
          Column(
            children: [
              Icon(_bondIcon(level), size: 20, color: c),
              const SizedBox(height: 3),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.text(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: c,
                    height: 1.15),
              ),
              Text('LV $level',
                  style: AppType.label.copyWith(
                      fontSize: 10,
                      letterSpacing: 1,
                      color: AppColor.inkFaint)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PilotCard extends StatelessWidget {
  const _PilotCard({required this.history});
  final PilotHistory history;

  @override
  Widget build(BuildContext context) {
    final a = AppColor.accent;
    final main = history.main;
    final ready = history.ready && main != null;
    final count = history.lastTen.length;
    final mainCount = main == null ? 0 : (history.tally[main] ?? 0);
    final others = [
      for (final e in history.tally.entries)
        if (e.key != main) e,
    ]..sort((x, y) => y.value.compareTo(x.value));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: HeatPanel(
        shape: const ChamferBorder(cut: 14),
        borderColor: ready ? a : AppColor.line,
        glow: ready ? a : null,
        padding: const EdgeInsets.all(16),
        onTap: () => context.push(AppRoutes.pilots),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PilotEmblem(
                  monogram: main?.monogram ?? '?',
                  width: 62,
                  color: ready ? a : AppColor.line,
                  fill: ready ? const Color(0xFF1A0F18) : AppColor.deep,
                  textColor: ready ? a : AppColor.inkFaint,
                  locked: !ready,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ready
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(main.name,
                                style: AppType.display(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 30,
                                    height: .92)),
                            const SizedBox(height: 2),
                            Text(main.source, style: AppType.caption),
                          ],
                        )
                      : Text(
                          '$count viaggi su $kPilotWindow registrati. Guida '
                          'ancora per scoprire il tuo pilota.',
                          style: AppType.body.copyWith(height: 1.45),
                        ),
                ),
              ],
            ),
            if (ready) ...[
              const SizedBox(height: 14),
              Text(main.tagline, style: AppType.body.copyWith(height: 1.45)),
            ],
            const SizedBox(height: 14),
            if (main != null)
              Text(
                history.isTie
                    ? 'TESTA A TESTA CON ${history.tiedWith!.name.toUpperCase()}'
                    : '$mainCount SU $count VIAGGI',
                style: AppType.display(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var k = 0; k < kPilotWindow; k++) ...[
                  if (k > 0) const SizedBox(width: 3),
                  Expanded(
                    child: Transform(
                      transform: Matrix4.skewX(-.5),
                      child: Container(
                        height: 7,
                        color: k >= count
                            ? AppColor.surfaceHigh
                            : history.lastTen[count - 1 - k] == main
                                ? a
                                : AppColor.lineMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (others.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'anche: ${others.take(3).map((e) => '${e.key.name} ${e.value}').join(' · ')}',
                style: AppType.caption.copyWith(fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({required this.profile, required this.onTap});
  final AppUser profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final car = profile.vehicleBrand == null
        ? 'Nessun ride impostato'
        : '${profile.vehicleBrand} ${profile.vehicleModel ?? ''}'.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: HeatPanel(
        shape: const ChamferBorder(cut: 14),
        borderColor: AppColor.line,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Row(
          children: [
            ClipPath(
              clipper: const ShapeBorderClipper(
                  shape: SlantBorder(left: 0, right: 18)),
              child: Container(
                width: 120,
                height: 92,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.1,
                    colors: [Color(0xFF231F2E), AppColor.surface],
                  ),
                ),
                child: const Icon(Icons.directions_car_filled_rounded,
                    size: 44, color: AppColor.lineMuted),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(car,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.display(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            height: 1)),
                    const SizedBox(height: 4),
                    Text(
                        '${profile.totalKm.toStringAsFixed(0)} km con HRR · '
                        'tocca per cambiare',
                        style: AppType.caption),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _rarityColors = <AchievementRarity, Color>{
  AchievementRarity.common: AppColor.rarityCommon,
  AchievementRarity.uncommon: AppColor.rarityUncommon,
  AchievementRarity.rare: AppColor.rarityRare,
  AchievementRarity.epic: AppColor.rarityEpic,
  AchievementRarity.legendary: AppColor.rarityLegendary,
};

class _AchievementPreview extends StatelessWidget {
  const _AchievementPreview({required this.achievements, required this.onTap});
  final List<Achievement> achievements;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final earned = [
      for (final a in achievements)
        if (a.isEarned) a,
    ]..sort((x, y) => y.earnedAt!.compareTo(x.earnedAt!));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          for (var k = 0; k < 5; k++) ...[
            if (k > 0) const SizedBox(width: 5),
            Expanded(
              child: HeatPressable(
                onTap: onTap,
                child: Builder(builder: (context) {
                  final a = k < earned.length ? earned[k] : null;
                  final c = a == null
                      ? AppColor.lineMuted
                      : _rarityColors[a.rarity] ?? AppColor.ink;
                  return Container(
                    height: 64,
                    decoration: ShapeDecoration(
                      color:
                          a == null ? AppColor.deep : c.withValues(alpha: .12),
                      shape: SlantBorder.all(10,
                          side: BorderSide(
                              color: a == null
                                  ? AppColor.line
                                  : c.withValues(alpha: .6))),
                    ),
                    child: Icon(
                      a == null
                          ? Icons.lock_outline_rounded
                          : hrrIconByKey[a.icon] ?? Icons.emoji_events_rounded,
                      size: a == null ? 22 : 28,
                      color: c,
                    ),
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HeatPressable(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        color: AppColor.surface,
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: AppType.display(
                      fontSize: 17, italic: false, letterSpacing: 1.4)),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColor.inkFaint),
          ],
        ),
      ),
    );
  }
}
