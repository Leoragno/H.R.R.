import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../../progression/presentation/progression_providers.dart';
import '../../../rival/domain/entities/mascot.dart';
import '../../../rival/presentation/providers/active_mascot_provider.dart';
import '../../../trip/presentation/providers/trip_provider.dart';
import '../../../trip/presentation/widgets/trip_stat_card.dart'
    show formatStoppedTime;
import '../../domain/entities/user_statistics.dart';
import '../providers/statistics_provider.dart';

/// STATISTICHE (HEAT, handoff §16): driving score in testa, tre totali,
/// livello con barra XP (→ profilo), tab GUIDA / TERRITORIO / COMMUNITY e
/// accesso agli achievement.
///
/// Elemento acceso della schermata: la card DRIVING SCORE. La barra XP
/// usa l'accento solo come riempimento, senza glow.
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

enum _Tab {
  guida('GUIDA'),
  territorio('TERRITORIO'),
  community('COMMUNITY');

  const _Tab(this.label);
  final String label;
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  _Tab _tab = _Tab.guida;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(myStatisticsProvider);
    final mascot = ref.watch(activeMascotProvider);

    return Scaffold(
      backgroundColor: AppColor.base,
      body: HeatBackground(
        glow: false,
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppColor.accent,
            backgroundColor: AppColor.surfaceHigh,
            onRefresh: () async {
              ref.invalidate(recentTripsProvider);
              ref.invalidate(myStatisticsProvider);
              await ref.read(myStatisticsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 120),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: ScreenTitle('Statistiche'),
                ),
                const SizedBox(height: 16),
                ...statsAsync.when(
                  loading: () => const [
                    SizedBox(
                      height: 300,
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
                  error: (err, st) => const [_ErrorMessage()],
                  data: (stats) => _content(stats, mascot),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(UserStatistics stats, Mascot mascot) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: _ScoreCard(score: _drivingScore(stats), mascot: mascot),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Expanded(
              child: _TopStat(
                  value: _int(stats.totalKm.round()), label: 'KM TOTALI'),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: _TopStat(value: _int(stats.totalTrips), label: 'VIAGGI'),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: _TopStat(
                value: stats.topSpeedKmh.round().toString(),
                label: 'KM/H MAX',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: _LevelRow(),
      ),
      const SizedBox(height: 18),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: _Tabs(
          selected: _tab,
          onSelect: (t) => setState(() => _tab = t),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          key: ValueKey(_tab),
          children: [
            for (final (i, r) in _rows(stats).indexed)
              HeatEnter(index: i, child: _StatRow(row: r)),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: HeatPressable(
          onTap: () => context.push(AppRoutes.achievements),
          child: Container(
            height: 52,
            decoration: BoxDecoration(border: Border.all(color: AppColor.line)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.workspace_premium_rounded,
                    size: 20, color: AppColor.gold),
                const SizedBox(width: 8),
                Text(
                  'ACHIEVEMENT · ${stats.achievementsEarned}'
                  '/${stats.achievementsTotal}',
                  style: AppType.display(
                    fontSize: 17,
                    italic: false,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  /// Media FLOW delle ultime 10 guide (handoff); se non ci sono guide con
  /// punteggio si ricade sul driving score del profilo.
  int _drivingScore(UserStatistics stats) {
    final trips = ref.watch(recentTripsProvider).valueOrNull ?? const [];
    final flows = [
      for (final t in trips.take(10))
        if (t.drivingScore != null) t.drivingScore!,
    ];
    if (flows.isEmpty) return stats.drivingScore.round();
    return (flows.reduce((a, b) => a + b) / flows.length).round();
  }

  List<_Row> _rows(UserStatistics s) {
    switch (_tab) {
      case _Tab.guida:
        final zero = s.bestZeroToHundredSeconds;
        return [
          _Row(Icons.terrain_rounded, 'dislivello totale',
              '${_int(s.elevationGainTotalM.round())} m'),
          _Row(Icons.vertical_align_top_rounded, 'altitudine max',
              '${_int(s.maxAltitudeM.round())} m'),
          _Row(Icons.airline_seat_recline_extra_rounded, 'picco G',
              '${_dec(s.peakGForce, 2)} G'),
          _Row(Icons.timer_rounded, 'miglior 0-100',
              zero == null ? '—' : '${_dec(zero, 1)} s'),
          _Row(Icons.u_turn_left_rounded, 'vel. max in curva',
              '${s.maxCorneringSpeedKmh.round()} km/h'),
          _Row(Icons.north_east_rounded, 'accelerazione max',
              '${_dec(s.maxAccelerationMs2, 1)} m/s²'),
          _Row(Icons.south_east_rounded, 'decelerazione max',
              '${_dec(s.maxDecelerationMs2, 1)} m/s²'),
          _Row(Icons.turn_right_rounded, 'svolte totali', _int(s.turnsTotal)),
          _Row(Icons.swap_horiz_rounded, 'cambi corsia',
              _int(s.laneChangesTotal)),
          _Row(Icons.do_not_disturb_on_rounded, 'frenate totali',
              _int(s.brakingEventsTotal)),
          _Row(Icons.pause_circle_rounded, 'soste totali',
              _int(s.totalStopsTotal)),
          _Row(Icons.hourglass_bottom_rounded, 'tempo da fermo',
              formatStoppedTime(Duration(seconds: s.stoppedSecondsTotal))),
        ];
      case _Tab.territorio:
        final balance = s.territoryGrowth - s.territoryDecline;
        final area = s.territoryAreaKm2;
        return [
          _Row(Icons.hexagon_rounded, 'esagoni tuoi', _int(s.territoryCellCount)),
          _Row(Icons.square_foot_rounded, 'area',
              '${_dec(area, area < .1 ? 3 : 2)} km²'),
          _Row(Icons.my_location_rounded, 'rubati agli altri',
              _int(s.territoryStolen)),
          _Row(Icons.trending_up_rounded, 'conquistati (30 giorni)',
              _int(s.territoryGrowth)),
          _Row(Icons.heart_broken_rounded, 'persi (30 giorni)',
              _int(s.territoryDecline)),
          _Row(Icons.balance_rounded, 'bilancio 30 giorni',
              '${balance >= 0 ? '+' : ''}$balance'),
        ];
      case _Tab.community:
        return [
          _Row(Icons.photo_camera_rounded, 'avvistamenti', _int(s.spotsCount)),
          _Row(Icons.military_tech_rounded, 'reputazione', _int(s.rep)),
          _Row(Icons.workspace_premium_rounded, 'achievement',
              '${s.achievementsEarned}/${s.achievementsTotal}'),
        ];
    }
  }
}

String _int(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

String _dec(double v, int digits) =>
    v.toStringAsFixed(digits).replaceAll('.', ',');

class _Row {
  const _Row(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
}

// ---------------------------------------------------------------------------

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score, required this.mascot});

  final int score;
  final Mascot mascot;

  @override
  Widget build(BuildContext context) {
    final a = AppColor.accent;
    final shape = ChamferBorder(
      cut: 20,
      bottomLeft: true,
      side: BorderSide(color: a.withValues(alpha: .5)),
    );
    Widget hero = Image.asset(
      'assets/mascots/${mascot.id}_hero.png',
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
    if (!MediaQuery.disableAnimationsOf(context)) {
      hero = hero
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(
              begin: 0, end: -8, duration: 2250.ms, curve: Curves.easeInOut);
    }

    return Container(
      height: 186,
      decoration: ShapeDecoration(
        shape: shape,
        gradient: LinearGradient(
          begin: const Alignment(-1, -.35),
          end: const Alignment(1, .35),
          colors: [a.withValues(alpha: .30), AppColor.surface],
          stops: const [0, .65],
        ),
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
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
              right: -16,
              bottom: -26,
              width: 170,
              height: 194,
              child: hero,
            ),
            Positioned(
              left: 18,
              top: 14,
              right: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DRIVING SCORE',
                    style: AppType.display(
                      fontSize: 14,
                      italic: false,
                      letterSpacing: 2,
                      color: AppColor.inkMuted,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _CountUp(
                      value: score,
                      style: AppType.display(
                        fontSize: 108,
                        fontWeight: FontWeight.w900,
                        height: .82,
                        letterSpacing: -2,
                        color: a,
                        shadows: [
                          Shadow(color: a.withValues(alpha: .5), blurRadius: 22),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'media FLOW delle ultime 10 guide',
                    style: AppType.text(
                        fontSize: 13, color: AppColor.inkMuted, height: 1.35),
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

/// Conteggio 0 → valore in 620ms ease-out (come il FLOW del Risultato).
class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.style});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text('$value', style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: AppMotion.reveal,
      curve: AppMotion.curve,
      builder: (_, v, __) => Text('${v.round()}', style: style),
    );
  }
}

class _TopStat extends StatelessWidget {
  const _TopStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return HeatPanel(
      shape: const SlantBorder.all(8),
      borderColor: null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                value,
                style: AppType.display(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            style: AppType.display(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              italic: false,
              letterSpacing: 1.4,
              color: AppColor.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelRow extends ConsumerWidget {
  const _LevelRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = ref.watch(levelProgressProvider);
    if (lp == null) return const SizedBox.shrink();
    return HeatPressable(
      onTap: () => context.push(AppRoutes.profile),
      child: Container(
        color: AppColor.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                'LV ${lp.level}',
                style: AppType.display(fontSize: 26, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: SkewBar(value: lp.fraction, height: 6)),
            const SizedBox(width: 12),
            Text(
              '${_int(lp.xpInLevel)} / ${_int(lp.xpNeeded)}',
              style: AppType.display(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                italic: false,
                color: AppColor.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelect});

  final _Tab selected;
  final ValueChanged<_Tab> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColor.line)),
      ),
      child: Row(
        children: [
          for (final t in _Tab.values) ...[
            if (t != _Tab.values.first) const SizedBox(width: 22),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(t),
              child: Container(
                padding: const EdgeInsets.only(bottom: 8, top: 6),
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
                    italic: false,
                    letterSpacing: 1.4,
                    color: t == selected ? AppColor.ink : AppColor.inkFaint,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.row});

  final _Row row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColor.surfaceHigh)),
      ),
      child: Row(
        children: [
          Icon(row.icon, size: 19, color: AppColor.inkFaint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              row.label,
              style: AppType.text(fontSize: 14, color: AppColor.inkMuted),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              row.value,
              style: AppType.display(fontSize: 21, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 44, color: AppColor.inkFaint),
          const SizedBox(height: 14),
          Text(
            'statistiche non disponibili.\ntrascina giù per riprovare.',
            textAlign: TextAlign.center,
            style: AppType.text(
                fontSize: 13, color: AppColor.inkMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
