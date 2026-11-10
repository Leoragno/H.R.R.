import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/territory_standing.dart';
import '../providers/game_controller.dart';
import '../providers/territory_provider.dart';

/// Altezza del pannello da collassato (maniglia + riga di tile). Riusata da
/// [GameScreen] per posizionare il resto sopra.
const kTerritoryPanelCollapsedHeight = 104.0;

/// Metriche proposte dal design (TOP IN CALO resta nell'enum, non qui).
const _metrics = [
  TerritoryMetric.general,
  TerritoryMetric.topThieves,
  TerritoryMetric.topGrowth,
];

/// Pannello a scomparsa di Gioca (HEAT): maniglia inclinata, tile
/// GENERALE / TOP LADRI / IN CRESCITA + MIEI, e da aperto la classifica
/// territorio. Si apre con tap sulla maniglia o su una tile, o con uno
/// swipe verticale.
class TerritoryPanel extends ConsumerWidget {
  const TerritoryPanel({super.key});

  static const _kSwipeVelocityThreshold = 200.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final expandedHeight = MediaQuery.sizeOf(context).height * .62;

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
          curve: AppMotion.enterCurve,
          height: state.panelExpanded
              ? expandedHeight
              : kTerritoryPanelCollapsedHeight,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xF714121C), Color(0xFC0B0912)],
            ),
            border: Border(top: BorderSide(color: AppColor.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => controller.setPanelExpanded(!state.panelExpanded),
                child: const SizedBox(
                  height: 22,
                  child: Center(
                    child: SizedBox(
                      width: 44,
                      child: SkewBar(value: 0, height: 4),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (final m in _metrics) ...[
                      Expanded(
                        child: _MetricTile(
                          icon: _icon(m),
                          label: m == TerritoryMetric.topGrowth
                              ? 'IN CRESCITA'
                              : m.label,
                          selected: state.panelTab == m,
                          onTap: () {
                            controller.setPanelTab(m);
                            if (!state.panelExpanded) {
                              controller.setPanelExpanded(true);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    SizedBox(
                      width: 64,
                      child: _MetricTile(
                        icon: Icons.list_rounded,
                        label: 'MIEI',
                        selected: false,
                        chamfer: false,
                        onTap: () => context.push(AppRoutes.myTerritories),
                      ),
                    ),
                  ],
                ),
              ),
              if (state.panelExpanded)
                const Expanded(child: _Standings()),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _icon(TerritoryMetric m) => switch (m) {
        TerritoryMetric.general => Icons.bar_chart_rounded,
        TerritoryMetric.topThieves => Icons.my_location_rounded,
        TerritoryMetric.topGrowth => Icons.rocket_launch_rounded,
        TerritoryMetric.topDecline => Icons.trending_down_rounded,
      };
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.chamfer = true,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool chamfer;

  @override
  Widget build(BuildContext context) {
    // Selezione in inchiostro: l'accento sulla mappa è dei miei esagoni.
    final c = selected ? AppColor.ink : AppColor.inkMuted;
    return HeatPanel(
      onTap: onTap,
      shape: chamfer
          ? const ChamferBorder(cut: 10)
          : const SlantBorder(left: 0, right: 0),
      color: selected ? AppColor.surfaceHigh : AppColor.surface,
      borderColor: selected ? AppColor.ink : AppColor.line,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: c),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.display(
                fontSize: 12,
                italic: false,
                letterSpacing: 1.2,
                color: c,
              ),
            ),
          ],
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

String _valueLabel(TerritoryStanding s, TerritoryMetric metric) =>
    switch (metric) {
      TerritoryMetric.general => '${s.cellCount} esagoni',
      TerritoryMetric.topThieves => '${s.stolen} rubati',
      TerritoryMetric.topGrowth => '+${s.growth} in 30 gg',
      TerritoryMetric.topDecline => '-${s.decline} in 30 gg',
    };

class _Standings extends ConsumerWidget {
  const _Standings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(gameControllerProvider.select((s) => s.panelTab));
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final standingsAsync = ref.watch(territoryStandingsProvider);

    return standingsAsync.when(
      loading: () => const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: AppColor.inkMuted),
        ),
      ),
      error: (err, st) => const _Empty(
        text: 'classifica territorio non disponibile.',
        icon: Icons.cloud_off_rounded,
      ),
      data: (list) {
        final sorted = List<TerritoryStanding>.of(list)
          ..sort((a, b) => _valueFor(b, tab).compareTo(_valueFor(a, tab)));
        if (sorted.isEmpty) {
          return const _Empty(
            text: 'nessun territorio conquistato ancora.\n'
                'guida per rivendicare i primi esagoni.',
            icon: Icons.hexagon_outlined,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          itemCount: sorted.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, i) => HeatEnter(
            index: i.clamp(0, 12),
            child: _StandingRow(
              rank: i + 1,
              standing: sorted[i],
              value: _valueLabel(sorted[i], tab),
              isMe: sorted[i].profileId == myId,
            ),
          ),
        );
      },
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.rank,
    required this.standing,
    required this.value,
    required this.isMe,
  });

  final int rank;
  final TerritoryStanding standing;
  final String value;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isMe ? AppColor.surfaceHigh : AppColor.surface,
        border: Border(
          left: BorderSide(
            width: 3,
            color: isMe ? AppColor.ink : const Color(0x00000000),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: AppType.display(
                  fontSize: 22, fontWeight: FontWeight.w900, height: 1),
            ),
          ),
          const SizedBox(width: 6),
          _Avatar(url: standing.avatarUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isMe ? 'TU · ${standing.displayName}' : standing.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.text(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: AppType.display(
              fontSize: 16,
              italic: false,
              color: AppColor.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    const fallback = ColoredBox(
      color: AppColor.surfaceHigh,
      child: Icon(Icons.person_rounded, color: AppColor.inkFaint, size: 20),
    );
    return SizedBox(
      width: 34,
      height: 34,
      child: url == null
          ? fallback
          : CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  const ColoredBox(color: AppColor.surfaceHigh),
              errorWidget: (_, __, ___) => fallback,
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColor.inkFaint),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: AppType.text(
                  fontSize: 13, color: AppColor.inkMuted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
