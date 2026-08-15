import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/territory_standing.dart';
import '../../domain/territory_color.dart';
import '../providers/game_controller.dart';
import '../providers/territory_provider.dart';

/// Pannello trascinabile ancorato in basso, sempre visibile sopra la
/// mappa (mockup: righe 767-834 di Guida.dc.html). Da collassato mostra
/// solo i 4 tab metrica; espanso (tap sull'handle/su un tab, o uno swipe
/// verticale) rivela la classifica territorio scrollabile.
/// Altezza del pannello da collassato — riusata anche da [GameScreen] per
/// posizionare il FAB "Centra" appena sopra.
const kTerritoryPanelCollapsedHeight = 150.0;

class TerritoryPanel extends ConsumerWidget {
  const TerritoryPanel({super.key});

  static const _kSwipeVelocityThreshold = 200.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final expandedHeight = MediaQuery.of(context).size.height * 0.86;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -_kSwipeVelocityThreshold) {
            controller.setPanelExpanded(true);
          } else if (velocity > _kSwipeVelocityThreshold) {
            controller.setPanelExpanded(false);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          height: state.panelExpanded
              ? expandedHeight
              : kTerritoryPanelCollapsedHeight,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xF20D1222), Color(0xF9060810)],
            ),
            border: Border(
              top: BorderSide(color: Color(0x29A0C8FF)),
              left: BorderSide(color: Color(0x29A0C8FF)),
              right: BorderSide(color: Color(0x29A0C8FF)),
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 44,
                  offset: Offset(0, -18)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => controller.setPanelExpanded(!state.panelExpanded),
                child: const Padding(
                  padding: EdgeInsets.only(top: 10, bottom: 12),
                  child: Center(child: _DragHandle()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    for (var i = 0; i < TerritoryMetric.values.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: _MetricTabButton(
                          metric: TerritoryMetric.values[i],
                          selected: state.panelTab == TerritoryMetric.values[i],
                          onTap: () {
                            controller.setPanelTab(TerritoryMetric.values[i]);
                            if (!state.panelExpanded) {
                              controller.setPanelExpanded(true);
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (state.panelExpanded)
                const Expanded(child: _ExpandedContent()),
            ],
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 6,
      decoration: BoxDecoration(
        color: const Color(0xFF2A3450),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _MetricTabButton extends StatelessWidget {
  final TerritoryMetric metric;
  final bool selected;
  final VoidCallback onTap;

  const _MetricTabButton({
    required this.metric,
    required this.selected,
    required this.onTap,
  });

  IconData get _icon => switch (metric) {
        TerritoryMetric.general => Icons.bar_chart_rounded,
        TerritoryMetric.topThieves => Icons.gps_fixed_rounded,
        TerritoryMetric.topGrowth => Icons.rocket_launch_rounded,
        TerritoryMetric.topDecline => Icons.trending_down_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColor.cyan : const Color(0xFFCFDCEC);
    return Material(
      color: selected ? const Color(0x332F6BFF) : const Color(0xFF131313),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, color: color, size: 22),
              const SizedBox(height: 8),
              Text(
                metric.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: AppType.text(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.04,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

num _valueFor(TerritoryStanding s, TerritoryMetric metric) => switch (metric) {
      TerritoryMetric.general => s.cellCount,
      TerritoryMetric.topThieves => s.stolen,
      TerritoryMetric.topGrowth => s.growth,
      TerritoryMetric.topDecline => s.decline,
    };

const _kBoardTitles = {
  TerritoryMetric.general: 'Classifica territorio',
  TerritoryMetric.topThieves: 'Top ladri',
  TerritoryMetric.topGrowth: 'Top in crescita',
  TerritoryMetric.topDecline: 'Top in calo',
};

const _kBoardSubtitles = {
  TerritoryMetric.general: 'Area totale posseduta',
  TerritoryMetric.topThieves: 'Celle sottratte ad altri (ultimi 30gg)',
  TerritoryMetric.topGrowth: 'Celle guadagnate (ultimi 30gg)',
  TerritoryMetric.topDecline: 'Celle perse (ultimi 30gg)',
};

class _ExpandedContent extends ConsumerWidget {
  const _ExpandedContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final standingsAsync = ref.watch(territoryStandingsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: standingsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
              child: CircularProgressIndicator(color: AppColor.cyan)),
        ),
        error: (err, st) => Center(
          child: Text('Errore: $err',
              style: AppType.text(color: AppColor.inkMuted)),
        ),
        data: (list) {
          final sorted = List<TerritoryStanding>.of(list)
            ..sort((a, b) => _valueFor(b, state.panelTab)
                .compareTo(_valueFor(a, state.panelTab)));
          final mineIndex = sorted.indexWhere((s) => s.profileId == myId);
          final topValue = sorted.isEmpty
              ? 1
              : _valueFor(sorted.first, state.panelTab)
                  .clamp(1, double.infinity);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _kBoardTitles[state.panelTab]!,
                            style: AppType.display(
                                fontWeight: FontWeight.w900, fontSize: 22),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _kBoardSubtitles[state.panelTab]!,
                            style: AppType.text(
                                fontSize: 13,
                                color: AppColor.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('LA TUA POSIZIONE',
                            style: AppType.text(
                                fontSize: 11,
                                letterSpacing: 0.1,
                                color: AppColor.inkMuted)),
                        const SizedBox(height: 4),
                        Text(
                          mineIndex >= 0
                              ? '#${mineIndex + 1} di ${sorted.length}'
                              : 'fuori classifica',
                          style: AppType.text(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColor.cyan),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => context.push(AppRoutes.myTerritories),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('I miei territori',
                          style: AppType.text(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColor.cyan)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded,
                          size: 16, color: AppColor.cyan),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (sorted.isEmpty)
                  const _EmptyTerritoryStandings()
                else
                  for (var i = 0; i < sorted.length; i++)
                    _StandingRow(
                      rank: i + 1,
                      standing: sorted[i],
                      metric: state.panelTab,
                      isMe: sorted[i].profileId == myId,
                      maxValue: topValue.toDouble(),
                      identityColor: territoryIdentityColor(
                        ownerId: sorted[i].profileId,
                        myProfileId: myId,
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  final int rank;
  final TerritoryStanding standing;
  final TerritoryMetric metric;
  final bool isMe;
  final double maxValue;
  final Color identityColor;

  const _StandingRow({
    required this.rank,
    required this.standing,
    required this.metric,
    required this.isMe,
    required this.maxValue,
    required this.identityColor,
  });

  static const _medals = {1: '🥇', 2: '🥈', 3: '🥉'};

  (String, String) get _valueAndUnit => switch (metric) {
        TerritoryMetric.general => (
            standing.areaKm2 < 0.1
                ? standing.areaKm2.toStringAsFixed(3)
                : standing.areaKm2.toStringAsFixed(2),
            'KM²'
          ),
        TerritoryMetric.topThieves => ('${standing.stolen}', 'RUBATI'),
        TerritoryMetric.topGrowth => ('${standing.growth}', '+CELLE'),
        TerritoryMetric.topDecline => ('${standing.decline}', '-CELLE'),
      };

  @override
  Widget build(BuildContext context) {
    final value = _valueFor(standing, metric);
    final delta = metric == TerritoryMetric.topDecline ? -value : value;
    final deltaColor = delta == 0
        ? AppColor.inkMuted
        : delta > 0
            ? AppColor.success
            : AppColor.danger;
    final rankColor = rank == 1
        ? const Color(0xFFFFC93C)
        : rank == 2
            ? const Color(0xFFDFE4EA)
            : rank == 3
                ? const Color(0xFFFF8A1F)
                : const Color(0xFF68788F);
    final (valueText, unit) = _valueAndUnit;
    final barWidth = (value.abs() / maxValue).clamp(0.02, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isMe
            ? AppColor.cyan.withValues(alpha: 0.08)
            : rank == 1
                ? const Color(0xFF1D1A08)
                : const Color(0xFF131313),
        border: Border.all(
          color: isMe
              ? AppColor.cyan.withValues(alpha: 0.6)
              : rank == 1
                  ? const Color(0xFF7A6A1E)
                  : const Color(0xFF232323),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$rank',
                          style: AppType.display(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              color: rankColor)),
                      if (_medals[rank] != null)
                        Text(_medals[rank]!,
                            style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                _StandingAvatar(standing: standing),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: identityColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              standing.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.text(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: isMe
                                    ? AppColor.cyan
                                    : AppColor.ink,
                              ),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    AppColor.cyan.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text('TU',
                                  style: AppType.text(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColor.cyan)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            delta == 0
                                ? '—'
                                : (delta > 0 ? '▲ $delta' : '▼ ${delta.abs()}'),
                            style: AppType.text(
                                fontSize: 12, color: deltaColor),
                          ),
                          const SizedBox(width: 6),
                          Text('${standing.cellCount} celle',
                              style: AppType.text(
                                  fontSize: 12,
                                  color: const Color(0xFF68788F))),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(valueText,
                        style: AppType.display(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: rank == 1
                              ? const Color(0xFFFFC93C)
                              : rank == 3
                                  ? const Color(0xFFFF8A1F)
                                  : AppColor.ink,
                        )),
                    Text(unit,
                        style: AppType.text(
                            fontSize: 10.5,
                            letterSpacing: 0.06,
                            color: AppColor.inkMuted)),
                  ],
                ),
                const SizedBox(width: 10),
              ],
            ),
          ),
          Positioned(
            left: 48,
            right: 0,
            bottom: 0,
            child: FractionallySizedBox(
              widthFactor: barWidth,
              child: Container(
                height: 3,
                color: isMe
                    ? AppColor.cyan
                    : rank == 1
                        ? const Color(0xFFFFC93C)
                        : rankColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StandingAvatar extends StatelessWidget {
  final TerritoryStanding standing;
  const _StandingAvatar({required this.standing});

  @override
  Widget build(BuildContext context) {
    final url = standing.avatarUrl;
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: url == null
                ? Container(
                    color: AppColor.surfaceHigh,
                    child: const Icon(Icons.person_rounded,
                        color: AppColor.inkFaint, size: 22),
                  )
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (c, u) =>
                        Container(color: AppColor.surfaceHigh),
                    errorWidget: (c, u, e) => Container(
                        color: AppColor.surfaceHigh,
                        child: const Icon(Icons.person_rounded,
                            color: AppColor.inkFaint, size: 22)),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTerritoryStandings extends StatelessWidget {
  const _EmptyTerritoryStandings();

  @override
  Widget build(BuildContext context) {
    const message =
        'Nessun territorio conquistato ancora. Guida per rivendicare i primi esagoni!';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hexagon_outlined,
                size: 40, color: AppColor.inkFaint),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppType.text(
                  fontSize: 13, color: AppColor.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
