import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';
import '../../../../core/theme/hrr_icons.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../../progression/presentation/progression_providers.dart';
import '../../../rival/presentation/providers/active_mascot_provider.dart';
import '../../domain/entities/drive_pass.dart';
import '../../domain/entities/mission.dart';
import '../../domain/entities/mission_progress.dart';
import '../../domain/entities/mission_reward.dart';
import '../providers/economy_providers.dart';
import '../providers/mission_controller.dart';
import '../providers/mission_provider.dart';

enum _Tab {
  today('OGGI', MissionType.daily),
  week('SETTIMANA', MissionType.weekly),
  season('STAGIONE', MissionType.seasonal),
  secret('SEGRETE', MissionType.secret);

  const _Tab(this.label, this.type);
  final String label;
  final MissionType type;
}

/// MISSIONI E PASS (HEAT, handoff §23): testata con mascotte e alone oro,
/// tier del pass di guida, pista premi con PRENDI / RISCUOTI TUTTO, tab
/// OGGI / SETTIMANA / (STAGIONE) / SEGRETE, righe con barra e RISCUOTI,
/// un cambio missione al giorno (↻) e il forziere del periodo.
/// Le segrete non ancora scoperte restano "???".
///
/// Senza pass (migrazione 0041 assente) la testata mostra il livello.
///
/// Colori: oro per XP e riscatti; l'accento solo sul prossimo tier.
class MissionsScreen extends ConsumerStatefulWidget {
  const MissionsScreen({super.key});

  @override
  ConsumerState<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends ConsumerState<MissionsScreen> {
  _Tab _tab = _Tab.today;
  final _claiming = <String>{};
  String? _rerolling;
  bool _passBusy = false;
  bool _chestBusy = false;

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Toglie "Exception: " e il prefisso di Postgres dai messaggi RPC.
  String _err(Object e) {
    final m = RegExp(r'message: ([^,]+)').firstMatch(e.toString());
    return (m?.group(1) ?? 'non riuscito. riprova.').toLowerCase();
  }

  Future<void> _reroll(Mission m) async {
    setState(() => _rerolling = m.id);
    try {
      await ref.read(missionRemoteDatasourceProvider).rerollDailyMission(m.id);
      ref.invalidate(activeMissionsProvider);
      ref.invalidate(missionSwapDaysProvider);
      if (mounted) _say('missione cambiata');
    } catch (e) {
      if (mounted) _say(_err(e));
    } finally {
      if (mounted) setState(() => _rerolling = null);
    }
  }

  Future<void> _claimPass({int? tier}) async {
    setState(() => _passBusy = true);
    try {
      final got =
          await ref.read(missionRemoteDatasourceProvider).claimPass(tier: tier);
      ref.invalidate(drivePassProvider);
      ref.invalidate(unlocksProvider);
      if (!mounted) return;
      final xp =
          got.fold<int>(0, (a, r) => a + ((r['xp'] as num?)?.toInt() ?? 0));
      final items = got.where((r) => r['item'] != null).length;
      _say([
        if (got.length == 1) 'tier ${got.first['tier']}',
        if (got.length > 1) '${got.length} tier riscossi',
        if (xp > 0) '+$xp XP',
        if (items > 0) items == 1 ? '1 sblocco' : '$items sblocchi',
      ].join(' · '));
    } catch (e) {
      if (mounted) _say(_err(e));
    } finally {
      if (mounted) setState(() => _passBusy = false);
    }
  }

  Future<void> _openChest(String kind) async {
    setState(() => _chestBusy = true);
    try {
      final xp = await ref
          .read(missionRemoteDatasourceProvider)
          .claimMissionChest(kind);
      ref.invalidate(openedChestsProvider);
      ref.invalidate(drivePassProvider);
      if (mounted) _say('forziere aperto · +$xp XP');
    } catch (e) {
      if (mounted) _say(_err(e));
    } finally {
      if (mounted) setState(() => _chestBusy = false);
    }
  }

  Future<void> _claim(Mission m) async {
    setState(() => _claiming.add(m.id));
    final claim =
        await ref.read(missionControllerProvider.notifier).claim(m.id);
    if (!mounted) return;
    ref.invalidate(drivePassProvider);
    setState(() => _claiming.remove(m.id));
    final xp = claim?.rewards
            .where((r) => r.type == MissionRewardType.xp)
            .fold<int>(
                0, (s, r) => s + ((r.value['amount'] as num?)?.toInt() ?? 0)) ??
        0;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(claim == null
            ? 'riscatto non riuscito. riprova.'
            : xp > 0
                ? 'missione riscattata · +$xp XP'
                : 'missione riscattata'),
      ));
  }

  Future<void> _refresh() async {
    ref.invalidate(ensureMissionPeriodsProvider);
    ref.invalidate(activeMissionsProvider);
    ref.invalidate(myClaimedMissionIdsProvider);
    ref.invalidate(drivePassProvider);
    ref.invalidate(openedChestsProvider);
    ref.invalidate(missionSwapDaysProvider);
    await ref.read(activeMissionsProvider(type: _tab.type).future);
  }

  @override
  Widget build(BuildContext context) {
    // La tab STAGIONE compare solo se ci sono missioni stagionali.
    final seasonal =
        ref.watch(activeMissionsProvider(type: MissionType.seasonal));
    final tabs = [
      _Tab.today,
      _Tab.week,
      if ((seasonal.valueOrNull ?? const []).isNotEmpty) _Tab.season,
      _Tab.secret,
    ];
    final tab = tabs.contains(_tab) ? _tab : _Tab.today;

    return Scaffold(
      backgroundColor: AppColor.base,
      body: RefreshIndicator(
        color: AppColor.accent,
        backgroundColor: AppColor.surfaceHigh,
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 30),
          children: [
            const _Header(),
            _PassTrack(
              busy: _passBusy,
              onClaim: (t) => _claimPass(tier: t),
              onClaimAll: () => _claimPass(),
            ),
            const SizedBox(height: 18),
            _Tabs(
              tabs: tabs,
              selected: tab,
              onSelect: (t) => setState(() => _tab = t),
            ),
            _MissionList(
              tab: tab,
              claiming: _claiming,
              onClaim: _claim,
              rerolling: _rerolling,
              onReroll: _reroll,
              chestBusy: _chestBusy,
              onOpenChest: _openChest,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.paddingOf(context).top;
    final mascot = ref.watch(activeMascotProvider);
    final season = ref.watch(activeSeasonProvider).valueOrNull;
    final level = ref.watch(levelProgressProvider);
    final pass = ref.watch(drivePassProvider).valueOrNull;
    final daysLeft =
        season?.endsAt.difference(DateTime.now()).inDays.clamp(0, 999);
    final kicker = pass != null
        ? 'PASS DI GUIDA · −${pass.daysLeft(DateTime.now())} GIORNI'
        : season != null
            ? '${season.name.toUpperCase()} · −$daysLeft GIORNI'
            : null;

    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(.8, -.8),
          radius: 1.1,
          colors: [Color(0x3DFFB020), Color(0x00FFB020)],
        ),
        border: Border(bottom: BorderSide(color: AppColor.line)),
      ),
      padding: const EdgeInsets.only(bottom: 14),
      child: Stack(
        children: [
          Positioned(
            right: -26,
            top: top + 46,
            width: 170,
            height: 194,
            child: Image.asset(
              'assets/mascots/${mascot.id}_hero.png',
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(4, top + 4, 0, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go(AppRoutes.home),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppColor.ink),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 150, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (kicker != null)
                      Text(
                        kicker,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.display(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          italic: false,
                          letterSpacing: 2,
                          color: AppColor.gold,
                        ),
                      ),
                    ScreenTitle(pass != null ? 'Missioni\ne pass' : 'Missioni',
                        fontSize: 46),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColor.surface.withValues(alpha: .94),
                  border: Border.all(color: AppColor.line),
                ),
                child: pass != null
                    ? _PassCard(pass: pass)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                level == null
                                    ? 'LIVELLO –'
                                    : 'LIVELLO ${level.level}',
                                style: AppType.display(
                                    fontSize: 26, fontWeight: FontWeight.w900),
                              ),
                              const Spacer(),
                              if (level != null)
                                Text(
                                  '${level.xpInLevel} / ${level.xpNeeded} XP',
                                  style: AppType.display(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    italic: false,
                                    color: AppColor.inkMuted,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SkewBar(
                            value: level?.fraction ?? 0,
                            segments: 20,
                            gap: 2,
                            height: 7,
                            color: AppColor.gold,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'ogni missione riscattata ti avvicina al prossimo livello.',
                            style: AppType.text(
                                fontSize: 13, color: AppColor.inkMuted),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _fmt(int n) {
  final s = n.toString();
  return s.length > 3
      ? '${s.substring(0, s.length - 3)}.${s.substring(s.length - 3)}'
      : s;
}

class _PassCard extends StatelessWidget {
  const _PassCard({required this.pass});
  final DrivePass pass;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('TIER ${pass.tier}',
                style:
                    AppType.display(fontSize: 26, fontWeight: FontWeight.w900)),
            const Spacer(),
            Text(
              '${_fmt(pass.xpInTier)} / ${_fmt(kPassXpPerTier)} XP',
              style: AppType.display(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                italic: false,
                color: AppColor.inkMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SkewBar(
          value: pass.xpInTier / kPassXpPerTier,
          segments: 20,
          gap: 2,
          height: 7,
          color: AppColor.gold,
        ),
        const SizedBox(height: 10),
        Text(
          '${pass.nextRewardLabel()}. ogni XP che guadagni riempie anche il pass.',
          style: AppType.text(fontSize: 13, color: AppColor.inkMuted),
        ),
      ],
    );
  }
}

IconData _rewardIcon(PassRewardKind k) => switch (k) {
      PassRewardKind.xp150 => Icons.military_tech_rounded,
      PassRewardKind.xp250 => Icons.bolt_rounded,
      PassRewardKind.accent => Icons.palette_rounded,
      PassRewardKind.emote => Icons.sentiment_very_satisfied_rounded,
      PassRewardKind.skin => Icons.auto_awesome_rounded,
      PassRewardKind.title => Icons.workspace_premium_rounded,
    };

/// PREMI DEL PASS: 12 tier intorno a quello attuale. Pronti = oro con
/// PRENDI, presi = spenti con ✓, bloccati = lucchetto; il prossimo tier ha
/// il bordo accento (unico accento della schermata).
class _PassTrack extends ConsumerWidget {
  const _PassTrack({
    required this.busy,
    required this.onClaim,
    required this.onClaimAll,
  });

  final bool busy;
  final ValueChanged<int> onClaim;
  final VoidCallback onClaimAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pass = ref.watch(drivePassProvider).valueOrNull;
    if (pass == null) return const SizedBox.shrink();
    final toClaim = pass.toClaim;
    final tiers = pass.trackTiers();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'PREMI DEL PASS',
                  style: AppType.display(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    italic: false,
                    letterSpacing: 2,
                    color: AppColor.inkMuted,
                  ),
                ),
              ),
              if (toClaim > 0)
                HeatPressable(
                  onTap: busy ? null : onClaimAll,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: const ShapeDecoration(
                      color: AppColor.gold,
                      shape: SlantBorder(left: 7, right: 7),
                    ),
                    child: Text(
                      'RISCUOTI TUTTO · $toClaim',
                      style: AppType.display(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: AppColor.onAccent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: tiers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final t = tiers[i];
              return _TierTile(
                tier: t,
                got: pass.claimed.contains(t),
                can: pass.canClaim(t),
                next: t == pass.tier + 1,
                busy: busy,
                onClaim: () => onClaim(t),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TierTile extends StatelessWidget {
  const _TierTile({
    required this.tier,
    required this.got,
    required this.can,
    required this.next,
    required this.busy,
    required this.onClaim,
  });

  final int tier;
  final bool got;
  final bool can;
  final bool next;
  final bool busy;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final kind = passRewardKind(tier);
    final locked = !got && !can;
    final c = got
        ? AppColor.inkFaint
        : can
            ? AppColor.gold
            : AppColor.inkMuted;
    final border = can
        ? AppColor.gold
        : next
            ? AppColor.accent
            : AppColor.line;

    return Container(
      width: 88,
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
      decoration: ShapeDecoration(
        color: can
            ? AppColor.gold.withValues(alpha: .14)
            : got
                ? AppColor.deep
                : AppColor.surface,
        shape: ChamferBorder(cut: 10, side: BorderSide(color: border)),
      ),
      child: Stack(
        children: [
          if (got || locked)
            Positioned(
              top: 0,
              right: 2,
              child: Icon(got ? Icons.check_rounded : Icons.lock_rounded,
                  size: 13, color: c),
            ),
          Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    '$tier',
                    style: AppType.display(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColor.inkMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Icon(_rewardIcon(kind), size: 28, color: c),
              const SizedBox(height: 6),
              Text(
                passRewardLabel(kind),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: AppType.text(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c,
                  height: 1.2,
                ),
              ),
              const Spacer(),
              if (can)
                GestureDetector(
                  onTap: busy ? null : onClaim,
                  child: Container(
                    height: 24,
                    width: double.infinity,
                    alignment: Alignment.center,
                    color: AppColor.gold,
                    child: Text(
                      'PRENDI',
                      style: AppType.display(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        italic: false,
                        letterSpacing: 1,
                        color: AppColor.onAccent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  final List<_Tab> tabs;
  final _Tab selected;
  final ValueChanged<_Tab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColor.line)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in tabs) ...[
              if (t != tabs.first) const SizedBox(width: 22),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(t),
                child: Container(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 3,
                        color: t == selected
                            ? AppColor.ink
                            : const Color(0x00000000),
                      ),
                    ),
                  ),
                  child: Text(
                    t.label,
                    style: AppType.display(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      italic: false,
                      letterSpacing: 1.4,
                      color: t == selected ? AppColor.ink : AppColor.inkMuted,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "nuove tra 5h 12m" / "reset tra 3 giorni" dalla scadenza più vicina.
String _resetLabel(_TabKind kind, DateTime? endsAt, [DateTime? now]) {
  if (kind == _TabKind.secret) return 'si svelano quando le completi';
  if (endsAt == null) return 'sempre attive';
  final d = endsAt.difference(now ?? DateTime.now());
  if (d.isNegative) return 'in aggiornamento…';
  if (d.inHours < 24) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return kind == _TabKind.daily
        ? 'nuove tra ${h}h ${m}m'
        : 'reset tra ${h}h ${m}m';
  }
  final days = d.inDays + (d.inHours % 24 > 0 ? 1 : 0);
  return 'reset tra $days giorni';
}

enum _TabKind { daily, other, secret }

class _MissionList extends ConsumerWidget {
  const _MissionList({
    required this.tab,
    required this.claiming,
    required this.onClaim,
    required this.rerolling,
    required this.onReroll,
    required this.chestBusy,
    required this.onOpenChest,
  });

  final _Tab tab;
  final Set<String> claiming;
  final ValueChanged<Mission> onClaim;
  final String? rerolling;
  final ValueChanged<Mission> onReroll;
  final bool chestBusy;
  final ValueChanged<String> onOpenChest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionsAsync = ref.watch(activeMissionsProvider(type: tab.type));
    final progress = {
      for (final p in ref.watch(myMissionProgressProvider).valueOrNull ??
          const <MissionProgress>[])
        p.missionId: p,
    };
    final claimed =
        (ref.watch(myClaimedMissionIdsProvider).valueOrNull ?? const [])
            .toSet();
    final swapDays = ref.watch(missionSwapDaysProvider).valueOrNull;
    final chests = ref.watch(openedChestsProvider).valueOrNull;
    final secretSlots = tab == _Tab.secret
        ? ref.watch(secretMissionSlotCountProvider).valueOrNull ?? 0
        : 0;

    return missionsAsync.when(
      loading: () => const SizedBox(
        height: 160,
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColor.inkMuted),
          ),
        ),
      ),
      error: (e, _) => const _Message('missioni non disponibili. '
          'trascina giù per riprovare.'),
      data: (missions) {
        final kind = switch (tab) {
          _Tab.today => _TabKind.daily,
          _Tab.secret => _TabKind.secret,
          _ => _TabKind.other,
        };
        final ends = missions
            .map((m) => m.endsAt)
            .whereType<DateTime>()
            .fold<DateTime?>(
                null, (a, b) => a == null || b.isBefore(a) ? b : a);

        // Da riscattare in cima, poi in corso, poi già riscattate.
        int order(Mission m) {
          if (claimed.contains(m.id)) return 2;
          return (progress[m.id]?.completed ?? false) ? 0 : 1;
        }

        final sorted = [...missions]
          ..sort((a, b) => order(a).compareTo(order(b)));
        final hiddenSecrets = (secretSlots - missions.length).clamp(0, 20);

        // Cambio missione: solo OGGI, uno al giorno, solo se la tabella
        // esiste (swapDays != null dopo il caricamento).
        final dayStart = missions
            .map((m) => m.startsAt)
            .whereType<DateTime>()
            .fold<DateTime?>(null, (a, b) => a ?? b);
        final rerollUsed = dayStart != null &&
            (swapDays ?? const {}).contains(dayKey(dayStart.toUtc()));
        final canReroll =
            tab == _Tab.today && swapDays != null && dayStart != null;

        // Forziere del periodo (OGGI / SETTIMANA).
        final chestKind = switch (tab) {
          _Tab.today => 'daily',
          _Tab.week => 'weekly',
          _ => null,
        };
        final done = missions.where((m) => claimed.contains(m.id)).length;
        final chestOpen = chestKind != null &&
            dayStart != null &&
            (chests ?? const {}).contains(chestPeriodKey(chestKind, dayStart));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 15, color: AppColor.inkMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _resetLabel(kind, ends).toUpperCase(),
                      style: AppType.display(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        italic: false,
                        letterSpacing: 1.6,
                        color: AppColor.inkMuted,
                      ),
                    ),
                  ),
                  if (canReroll)
                    Text(
                      rerollUsed
                          ? 'cambio usato · torna domani'
                          : '1 cambio missione disponibile oggi',
                      style:
                          AppType.text(fontSize: 11, color: AppColor.inkFaint),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (sorted.isEmpty && hiddenSecrets == 0)
              _Message(tab == _Tab.secret
                  ? 'nessuna missione segreta in gioco.'
                  : 'nessuna missione per ora. guida per sbloccarne di nuove.'),
            for (final (i, m) in sorted.indexed)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 5),
                child: HeatEnter(
                  index: i.clamp(0, 10),
                  child: MissionRow(
                    mission: m,
                    current: progress[m.id]?.currentValue ?? 0,
                    completed: progress[m.id]?.completed ?? false,
                    claimed: claimed.contains(m.id),
                    busy: claiming.contains(m.id),
                    onClaim: () => onClaim(m),
                    rerolling: rerolling == m.id,
                    onReroll: canReroll &&
                            !rerollUsed &&
                            rerolling == null &&
                            !(progress[m.id]?.completed ?? false) &&
                            !claimed.contains(m.id)
                        ? () => onReroll(m)
                        : null,
                  ),
                ),
              ),
            for (var i = 0; i < hiddenSecrets; i++)
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 5),
                child: _SecretRow(),
              ),
            if (chestKind != null && chests != null && missions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 5, 14, 0),
                child: _ChestCard(
                  daily: chestKind == 'daily',
                  done: done,
                  total: missions.length,
                  open: chestOpen,
                  busy: chestBusy,
                  onOpen: () => onOpenChest(chestKind),
                ),
              ),
          ],
        );
      },
    );
  }
}

String _num(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// Riga missione: icona, titolo, avanzamento e barra; a destra RISCUOTI
/// (oro) se completata, ✓ se già riscattata, altrimenti +XP.
class MissionRow extends StatelessWidget {
  const MissionRow({
    super.key,
    required this.mission,
    required this.current,
    required this.completed,
    required this.claimed,
    required this.onClaim,
    this.busy = false,
    this.onReroll,
    this.rerolling = false,
  });

  final Mission mission;
  final double current;
  final bool completed;
  final bool claimed;
  final bool busy;
  final VoidCallback onClaim;

  /// Cambio missione (↻); null = non disponibile.
  final VoidCallback? onReroll;
  final bool rerolling;

  @override
  Widget build(BuildContext context) {
    final target = mission.targetValue <= 0 ? 1.0 : mission.targetValue;
    final done = completed || claimed;
    final value = done ? target : current.clamp(0, target).toDouble();
    final claimable = completed && !claimed;
    final bar = claimed
        ? AppColor.inkFaint
        : claimable
            ? AppColor.gold
            : AppColor.ink;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
      decoration: BoxDecoration(
        color: AppColor.surface,
        border: Border(left: BorderSide(color: bar, width: 3)),
      ),
      child: Row(
        children: [
          Icon(
            hrrIconByKey[mission.icon] ?? Icons.flag_rounded,
            size: 22,
            color: claimed ? AppColor.inkFaint : AppColor.inkMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        mission.title,
                        style: AppType.text(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: claimed ? AppColor.inkFaint : AppColor.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_num(value)}/${_num(target)}',
                      style: AppType.display(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        italic: false,
                        color: AppColor.inkMuted,
                      ),
                    ),
                  ],
                ),
                if (mission.description.trim().isNotEmpty &&
                    mission.description.trim() != mission.title.trim())
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      mission.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppType.text(fontSize: 12, color: AppColor.inkMuted),
                    ),
                  ),
                const SizedBox(height: 6),
                SkewBar(value: value / target, height: 4, color: bar),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (claimable)
            _ClaimButton(busy: busy, onTap: onClaim)
          else if (claimed)
            const SizedBox(
              width: 50,
              child:
                  Icon(Icons.check_rounded, color: AppColor.inkFaint, size: 22),
            )
          else
            SizedBox(
              width: 56,
              child: Text(
                '+${mission.rewardXp}',
                textAlign: TextAlign.right,
                style: AppType.display(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: AppColor.gold,
                ),
              ),
            ),
          if (onReroll != null || rerolling) ...[
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'cambia missione',
              child: GestureDetector(
                onTap: onReroll,
                child: Container(
                  width: 34,
                  height: 34,
                  color: AppColor.surfaceHigh,
                  alignment: Alignment.center,
                  child: rerolling
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColor.inkMuted),
                        )
                      : const Icon(Icons.autorenew_rounded,
                          size: 18, color: AppColor.inkMuted),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// FORZIERE DEL GIORNO / DELLA SETTIMANA: si apre quando tutte le missioni
/// del periodo sono riscosse.
class _ChestCard extends StatelessWidget {
  const _ChestCard({
    required this.daily,
    required this.done,
    required this.total,
    required this.open,
    required this.busy,
    required this.onOpen,
  });

  final bool daily;
  final int done;
  final int total;
  final bool open;
  final bool busy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ready = !open && total > 0 && done >= total;
    final xp = daily ? 200 : 600;
    final c = open
        ? AppColor.inkFaint
        : ready
            ? AppColor.gold
            : AppColor.inkMuted;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: ShapeDecoration(
        color: ready ? AppColor.gold.withValues(alpha: .12) : AppColor.surface,
        shape: ChamferBorder(
          side: BorderSide(color: ready ? AppColor.gold : AppColor.line),
        ),
      ),
      child: Row(
        children: [
          Icon(open ? Icons.inventory_2_rounded : Icons.redeem_rounded,
              size: 36, color: c),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  daily ? 'FORZIERE DEL GIORNO' : 'FORZIERE DELLA SETTIMANA',
                  style: AppType.display(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .6,
                  ),
                ),
                Text(
                  'completa e riscuoti tutte le missioni · $done/$total riscosse',
                  style: AppType.text(fontSize: 12, color: AppColor.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (ready)
            HeatPressable(
              onTap: busy ? null : onOpen,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: const ShapeDecoration(
                  color: AppColor.gold,
                  shape: SlantBorder(left: 7, right: 7),
                ),
                child: Text(
                  'APRI +$xp XP',
                  style: AppType.display(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColor.onAccent,
                  ),
                ),
              ),
            )
          else if (open)
            Text(
              'APERTO',
              style: AppType.display(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                italic: false,
                letterSpacing: 1.2,
                color: AppColor.inkFaint,
              ),
            )
          else
            Text(
              '+$xp XP',
              style: AppType.display(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColor.inkFaint,
              ),
            ),
        ],
      ),
    );
  }
}

class _ClaimButton extends StatelessWidget {
  const _ClaimButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HeatPressable(
      onTap: busy ? null : onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: const ShapeDecoration(
          color: AppColor.gold,
          shape: SlantBorder(left: 6, right: 6),
        ),
        child: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColor.onAccent),
              )
            : Text(
                'RISCUOTI',
                style: AppType.display(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColor.onAccent,
                ),
              ),
      ),
    );
  }
}

class _SecretRow extends StatelessWidget {
  const _SecretRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: const BoxDecoration(
        color: AppColor.surface,
        border: Border(left: BorderSide(color: AppColor.line, width: 3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, size: 22, color: AppColor.inkFaint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '??? · missione segreta',
              style: AppType.text(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColor.inkFaint,
              ),
            ),
          ),
          Text(
            '???',
            style: AppType.display(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: AppColor.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 30, 32, 20),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style:
            AppType.text(fontSize: 14, color: AppColor.inkMuted, height: 1.45),
      ),
    );
  }
}
