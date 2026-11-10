import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';
import '../../../../core/widgets/draggable_sheet_scaffold.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../rival/data/rivalry_tracker.dart';
import '../../../rival/presentation/providers/rival_controller_provider.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../providers/leaderboard_provider.dart';
import '../widgets/leaderboard_avatar.dart';

/// CLASSIFICA (HEAT, handoff §15): metrica a scelta da sheet, periodo
/// settimana/mese/sempre, hero del primo ("BLACKLIST #1"), righe con la
/// bandiera del paese e riga del distacco dal pilota sopra di te.
///
/// App privata e chiusa: tutti gli utenti sono già amici, quindi la
/// classifica globale È la classifica amici. Ordinamento e rank arrivano
/// dalla RPC `leaderboard_global` (vedi [LeaderboardMetric]).
///
/// Elemento acceso della schermata: la fascia del leader.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

/// Metriche e periodi esposti dal design (REP e OGGI restano nell'enum ma
/// non sono proposti qui).
const _metrics = [
  LeaderboardMetric.xp,
  LeaderboardMetric.avg,
  LeaderboardMetric.km,
  LeaderboardMetric.long,
  LeaderboardMetric.zero,
  LeaderboardMetric.speed,
];
const _periods = [
  LeaderboardPeriod.week,
  LeaderboardPeriod.month,
  LeaderboardPeriod.all,
];

IconData _metricIcon(LeaderboardMetric m) => switch (m) {
      LeaderboardMetric.xp => Icons.leaderboard_rounded,
      LeaderboardMetric.rep => Icons.military_tech_rounded,
      LeaderboardMetric.avg => Icons.speed_rounded,
      LeaderboardMetric.km => Icons.route_rounded,
      LeaderboardMetric.long => Icons.flag_rounded,
      LeaderboardMetric.zero => Icons.timer_rounded,
      LeaderboardMetric.speed => Icons.bolt_rounded,
    };

/// `12.840` per gli interi, `6,8` per lo 0-100.
String _fmt(LeaderboardEntry e, LeaderboardMetric m) {
  final v = e.valueFor(m);
  if (m == LeaderboardMetric.zero) {
    return v.toStringAsFixed(1).replaceAll('.', ',');
  }
  return _thousands(v.round());
}

String _thousands(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  LeaderboardPeriod _period = LeaderboardPeriod.week;
  LeaderboardMetric _metric = LeaderboardMetric.xp;
  final _rivalryTracker = RivalryTracker();

  bool get _isCanonicalRivalry =>
      _metric == LeaderboardMetric.xp && _period == LeaderboardPeriod.week;

  /// Rileva un sorpasso confrontando il rivale tracciato con la fetch
  /// fresca — solo alla visita della schermata (leaderboardProvider è già
  /// one-shot per visita, nessun polling/realtime aggiunto). Aggiorna
  /// comunque il tracker anche quando non scatta un festeggiamento, per
  /// evitare falsi positivi futuri.
  Future<void> _checkOvertake(List<LeaderboardEntry> list, String myId) async {
    final myIndex = list.indexWhere((e) => e.profileId == myId);
    if (myIndex == -1) return;

    final tracked = await _rivalryTracker.read(myId);
    if (tracked != null) {
      LeaderboardEntry? trackedNow;
      for (final e in list) {
        if (e.profileId == tracked.profileId) {
          trackedNow = e;
          break;
        }
      }
      final stillAbove =
          myIndex > 0 && list[myIndex - 1].profileId == tracked.profileId;
      if (!stillAbove &&
          trackedNow != null &&
          list[myIndex].rank < trackedNow.rank) {
        ref.read(rivalControllerProvider.notifier).announceOvertake(
              rivalName: trackedNow.displayName,
              newRank: trackedNow.rank,
            );
        unawaited(ref.read(supabaseClientProvider).rpc(
          'notify_leaderboard_overtake',
          params: {'p_victim_id': trackedNow.profileId},
        ));
      }
    }

    final newRivalAbove = myIndex > 0 ? list[myIndex - 1] : null;
    await _rivalryTracker.write(
      myId,
      newRivalAbove == null
          ? null
          : RivalrySnapshot(
              profileId: newRivalAbove.profileId,
              displayName: newRivalAbove.displayName,
              rank: newRivalAbove.rank,
            ),
    );
  }

  Future<void> _pickMetric() async {
    final selected = await DraggableSheetScaffold.show<LeaderboardMetric>(
      context,
      title: 'Classifica per',
      builder: (ctx) => _MetricSheet(selected: _metric),
    );
    if (selected != null && mounted) setState(() => _metric = selected);
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(leaderboardProvider(_metric, _period));
    final myId = ref.watch(authStateProvider).valueOrNull?.id;

    if (_isCanonicalRivalry && myId != null) {
      ref.listen<AsyncValue<List<LeaderboardEntry>>>(
        leaderboardProvider(_metric, _period),
        (previous, next) => next.whenData((list) => _checkOvertake(list, myId)),
      );
    }

    return Scaffold(
      backgroundColor: AppColor.base,
      body: HeatBackground(
        glow: false,
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppColor.accent,
            backgroundColor: AppColor.surfaceHigh,
            onRefresh: () =>
                ref.refresh(leaderboardProvider(_metric, _period).future),
            child: ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 120),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: ScreenTitle('Classifica'),
                ),
                const SizedBox(height: 14),
                _Filters(
                  metric: _metric,
                  onMetric: _pickMetric,
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      for (final p in _periods) ...[
                        if (p != _periods.first) const SizedBox(width: 4),
                        Expanded(
                          child: _PeriodTab(
                            label: p.label,
                            selected: p == _period,
                            onTap: () => setState(() => _period = p),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ...entries.when(
                  loading: () => const [
                    SizedBox(
                      height: 260,
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColor.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                  error: (err, st) => [
                    const _Message(
                      icon: Icons.cloud_off_rounded,
                      text: 'classifica non disponibile.\n'
                          'trascina giù per riprovare.',
                    ),
                  ],
                  data: (list) => _board(list, myId),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _board(List<LeaderboardEntry> list, String? myId) {
    if (list.isEmpty) {
      return const [
        _Message(
          icon: Icons.emoji_events_rounded,
          text: 'nessun pilota in classifica per questo periodo.\n'
              'guida e torna a vedere chi comanda.',
        ),
      ];
    }
    final leader = list.first;
    final rest = list.skip(1).toList();
    return [
      _LeaderHero(
        entry: leader,
        metric: _metric,
        isMe: leader.profileId == myId,
      ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            for (var i = 0; i < rest.length; i++) ...[
              if (i > 0) const SizedBox(height: 4),
              HeatEnter(
                index: i.clamp(0, 12),
                child: _BoardRow(
                  entry: rest[i],
                  metric: _metric,
                  isMe: rest[i].profileId == myId,
                ),
              ),
            ],
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
        child: Text(
          _gapLine(list, myId),
          style:
              AppType.text(fontSize: 13, color: AppColor.inkMuted, height: 1.4),
        ),
      ),
    ];
  }

  /// "ti mancano 240 XP per superare giulia.v." / "sei in testa…".
  String _gapLine(List<LeaderboardEntry> list, String? myId) {
    final i = list.indexWhere((e) => e.profileId == myId);
    if (i == -1)
      return 'non sei ancora in questa classifica. guida per entrarci.';
    if (i == 0) return 'sei in testa. difendi il primo posto.';
    final me = list[i].valueFor(_metric);
    final above = list[i - 1].valueFor(_metric);
    final String gap;
    if (_metric == LeaderboardMetric.zero) {
      final d = (me - above).abs();
      gap = '${d.toStringAsFixed(1).replaceAll('.', ',')}${_metric.unit}';
    } else {
      gap = '${_thousands((above - me).abs().round() + 1)}${_metric.unit}';
    }
    final who = list[i - 1].displayName;
    return _metric == LeaderboardMetric.zero
        ? 'ti mancano $gap sullo 0-100 per superare $who.'
        : 'ti mancano $gap per superare $who.';
  }
}

// ---------------------------------------------------------------------------
// FILTRI
// ---------------------------------------------------------------------------

class _Filters extends StatelessWidget {
  const _Filters({required this.metric, required this.onMetric});

  final LeaderboardMetric metric;
  final VoidCallback onMetric;

  @override
  Widget build(BuildContext context) {
    final label = AppType.display(
      fontSize: 15,
      italic: false,
      letterSpacing: 1.2,
    );
    const shape = SlantBorder.all(8);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          HeatPanel(
            shape: shape,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  const Icon(Icons.group_rounded,
                      size: 18, color: AppColor.inkMuted),
                  const SizedBox(width: 6),
                  Text('AMICI', style: label),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: HeatPanel(
              shape: shape,
              onTap: onMetric,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded,
                        size: 18, color: AppColor.inkMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        metric.label,
                        style: label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.expand_more_rounded,
                        size: 18, color: AppColor.ink),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodTab extends StatelessWidget {
  const _PeriodTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HeatPanel(
      onTap: onTap,
      shape: const SlantBorder.all(8),
      // Selezionato = inchiostro pieno (non accento: l'accento è del leader).
      color: selected ? AppColor.ink : AppColor.surface,
      borderColor: null,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 36,
        child: Center(
          child: Text(
            label,
            style: AppType.display(
              fontSize: 14,
              italic: false,
              letterSpacing: 1.2,
              color: selected ? AppColor.onAccent : AppColor.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricSheet extends StatelessWidget {
  const _MetricSheet({required this.selected});

  final LeaderboardMetric selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final m in _metrics)
          InkWell(
            onTap: () => Navigator.of(context).pop(m),
            child: SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(_metricIcon(m),
                        size: 22,
                        color: m == selected ? AppColor.accent : AppColor.ink),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        m.label,
                        style: AppType.display(
                          fontSize: 18,
                          italic: false,
                          letterSpacing: 1.2,
                          color: m == selected ? AppColor.accent : AppColor.ink,
                        ),
                      ),
                    ),
                    if (m == selected)
                      Icon(Icons.check_rounded,
                          size: 22, color: AppColor.accent),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// LEADER
// ---------------------------------------------------------------------------

class _LeaderHero extends StatelessWidget {
  const _LeaderHero({
    required this.entry,
    required this.metric,
    required this.isMe,
  });

  final LeaderboardEntry entry;
  final LeaderboardMetric metric;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final a = AppColor.accent;
    final reduce = MediaQuery.disableAnimationsOf(context);
    Widget hero = Image.asset(
      'assets/mascots/${entry.mascotId ?? 'nitro'}_hero.png',
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
    if (!reduce) {
      hero = hero
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: 0, end: -8, duration: 2250.ms, curve: Curves.easeInOut);
    }

    return Container(
      height: 210,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-1, -.18),
          end: const Alignment(1, .18),
          colors: [a.withValues(alpha: .30), a.withValues(alpha: 0)],
          stops: const [0, .75],
        ),
        border: Border.symmetric(
          horizontal: BorderSide(color: a.withValues(alpha: .5)),
        ),
      ),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(.76, -1),
                    radius: .9,
                    colors: [a.withValues(alpha: .15), a.withValues(alpha: 0)],
                    stops: const [0, .7],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -6,
              bottom: -14,
              width: 200,
              height: 228,
              child: hero,
            ),
            Positioned(
              left: 18,
              top: 14,
              child: Text(
                'BLACKLIST #1 · ${isMe ? 'SEI TU' : 'DA BATTERE'}',
                style: AppType.display(
                  fontSize: 14,
                  italic: false,
                  letterSpacing: 2,
                  color: a,
                ),
              ),
            ),
            const Positioned(
              left: 16,
              top: 40,
              child: GraffitiText('01', fontSize: 84, angle: -.105),
            ),
            Positioned(
              left: 18,
              right: 170,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      isMe ? 'TU · ${entry.displayName}' : entry.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.display(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                  Text(
                    '${_fmt(entry, metric)}${metric.unit} · LV ${entry.level}',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: AppType.display(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      italic: false,
                      color: AppColor.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// RIGHE
// ---------------------------------------------------------------------------

/// Tre bande (35% / 20% / 30%) dei colori della bandiera, poi trasparente.
const _flags = <String, List<Color>>{
  'IT': [Color(0xFF1F9D55), Color(0xFFF4F1FA), Color(0xFFE23B3B)],
  'CH': [Color(0xFFE23B3B), Color(0xFFE23B3B), Color(0xFFE23B3B)],
  'FR': [Color(0xFF2B4BCF), Color(0xFFF4F1FA), Color(0xFFE23B3B)],
  'DE': [Color(0xFF111111), Color(0xFFE23B3B), Color(0xFFFFC93C)],
  'ES': [Color(0xFFE23B3B), Color(0xFFFFC93C), Color(0xFFE23B3B)],
  'AT': [Color(0xFFE23B3B), Color(0xFFF4F1FA), Color(0xFFE23B3B)],
  'BE': [Color(0xFF111111), Color(0xFFFFC93C), Color(0xFFE23B3B)],
  'NL': [Color(0xFFE23B3B), Color(0xFFF4F1FA), Color(0xFF2B4BCF)],
  'GB': [Color(0xFF2B4BCF), Color(0xFFF4F1FA), Color(0xFFE23B3B)],
  'PT': [Color(0xFF1F9D55), Color(0xFF1F9D55), Color(0xFFE23B3B)],
};

LinearGradient? _flagGradient(String? country) {
  final f = _flags[country?.toUpperCase()];
  if (f == null) return null;
  const begin = Alignment(-1, -.18), end = Alignment(1, .18);
  return LinearGradient(
    begin: begin,
    end: end,
    colors: [
      f[0].withValues(alpha: .35),
      f[0].withValues(alpha: .35),
      f[1].withValues(alpha: .20),
      f[1].withValues(alpha: .20),
      f[2].withValues(alpha: .30),
      f[2].withValues(alpha: .30),
      const Color(0x00000000),
    ],
    stops: const [0, .10, .10, .20, .20, .30, .46],
  );
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({
    required this.entry,
    required this.metric,
    required this.isMe,
  });

  final LeaderboardEntry entry;
  final LeaderboardMetric metric;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final flag = _flagGradient(entry.country);
    return Container(
      decoration: BoxDecoration(
        color: isMe ? AppColor.surfaceHigh : AppColor.surface,
        border: Border(
          left: BorderSide(
            width: 3,
            color: isMe ? AppColor.ink : const Color(0x00000000),
          ),
        ),
      ),
      child: Stack(
        children: [
          if (flag != null)
            Positioned.fill(
              child: DecoratedBox(decoration: BoxDecoration(gradient: flag)),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    '${entry.rank}',
                    style: AppType.display(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _Face(entry: entry),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMe ? 'TU · ${entry.displayName}' : entry.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.text(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'LV ${entry.level}',
                        style: AppType.display(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          italic: false,
                          letterSpacing: 1,
                          color: AppColor.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _fmt(entry, metric),
                        style: AppType.display(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(
                        text: metric.unit,
                        style: AppType.text(
                          fontSize: 12,
                          color: AppColor.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Volto quadrato della mascotte; se manca, l'avatar del profilo.
class _Face extends StatelessWidget {
  const _Face({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final id = entry.mascotId;
    return SizedBox(
      width: 38,
      height: 38,
      child: ColoredBox(
        color: AppColor.surfaceHigh,
        child: id == null
            ? LeaderboardAvatar(url: entry.avatarUrl, size: 38)
            : Image.asset(
                'assets/faces/$id.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    LeaderboardAvatar(url: entry.avatarUrl, size: 38),
              ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColor.inkFaint),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppType.text(
                fontSize: 13, color: AppColor.inkMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
