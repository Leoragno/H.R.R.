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
import '../../../pilots/presentation/widgets/pilot_emblem.dart';
import '../../../progression/presentation/progression_providers.dart';
import '../../../rival/domain/entities/mascot.dart';
import '../../../rival/presentation/providers/active_mascot_provider.dart';
import '../../../trip/domain/driver_archetype.dart';

/// Profilo (handoff HEAT, schermata 17): hero con la mascotte, username,
/// statistiche, compagno, "Che pilota sei", ride, anteprima achievement e
/// collegamenti. Sola lettura: la modifica dei dati resta in Impostazioni.
///
/// Legame/bonus della mascotte e link Amici/Sfide arrivano con le fasi
/// economia XP e social: finché non sono reali non vengono mostrati.
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
    final pilots = ref.watch(pilotHistoryProvider);
    final achievements =
        ref.watch(myAchievementsProvider).valueOrNull ?? const <Achievement>[];

    var i = 0;
    return Scaffold(
      backgroundColor: AppColor.base,
      body: ListView(
        padding: EdgeInsets.only(
            bottom: 30 + MediaQuery.paddingOf(context).bottom),
        children: [
          _Hero(
            profile: profile,
            mascot: mascot,
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
          HeatEnter(index: i++, child: _CompanionCard(mascot: mascot)),
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
            (Icons.flag_rounded, AppColor.gold, 'MISSIONI',
                AppRoutes.missions),
            (Icons.hexagon_outlined, AppColor.accent, 'I MIEI TERRITORI',
                AppRoutes.myTerritories),
            (Icons.settings_rounded, AppColor.inkMuted, 'IMPOSTAZIONI',
                AppRoutes.settings),
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
  const _Hero(
      {required this.profile, required this.mascot, required this.levelLabel});
  final AppUser profile;
  final Mascot mascot;
  final String levelLabel;

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
            child: Image.asset(
              'assets/mascots/${mascot.id}_hero.png',
              fit: BoxFit.contain,
              alignment: Alignment.bottomRight,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            )
                .animate(onPlay: (ctl) => ctl.repeat(reverse: true))
                .moveY(begin: 0, end: -8, duration: 2250.ms,
                    curve: Curves.easeInOut),
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
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: AppColor.ink),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => context.push(AppRoutes.settings),
                  icon:
                      const Icon(Icons.settings_rounded, color: AppColor.ink),
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
                style: AppType.display(
                    fontWeight: FontWeight.w900, fontSize: 26)),
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
  const _CompanionCard({required this.mascot});
  final Mascot mascot;

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
                child: Image.asset(
                  'assets/mascots/${mascot.id}_hero.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(120, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mascot.name,
                        style: AppType.display(
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            height: 1)),
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
                      color: a == null
                          ? AppColor.deep
                          : c.withValues(alpha: .12),
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
