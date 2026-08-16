import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notification_bell_button.dart';
import '../../../../core/widgets/profile_avatar_button.dart';
import '../../../trip/presentation/widgets/trip_stat_card.dart' show formatStoppedTime;
import '../../domain/entities/user_statistics.dart';
import '../providers/statistics_provider.dart';

/// Tab "Statistiche": tutte le statistiche personali dell'utente, in
/// sostituzione del vecchio tab "Crew" (app privata e chiusa, nessun
/// gruppo — esiste già un'unica classifica in Classifica).
///
/// Protagonista unico (DESIGN.md, regola 1): il Livello, in testa, con
/// l'unico accento/glow ciano della schermata. Tutto il resto — Guida,
/// Territorio, Spotting, Achievement — resta su `AppGlow.card` grigio, per
/// quanto ogni numero "vorrebbe" farsi notare.
///
/// Missioni volutamente assente: il motore missioni lato server resta
/// attivo (mission_event_bridge_provider continua ad assegnare XP/REP),
/// solo l'accesso da UI è stato rimosso su richiesta ("non serve").
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(myStatisticsProvider);

    return Scaffold(
      backgroundColor: AppColor.void_,
      body: SafeArea(
        child: statsAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColor.cyan)),
          error: (err, st) => Center(
            child: Text('Impossibile caricare le statistiche',
                style: AppType.body.copyWith(color: AppColor.inkMuted)),
          ),
          data: (stats) => ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.lg),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Statistiche', style: AppType.title.copyWith(fontSize: 28)),
                  const Row(
                    children: [
                      NotificationBellButton(size: 40),
                      SizedBox(width: 10),
                      ProfileAvatarButton(),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              _LevelHero(stats: stats),
              const SizedBox(height: AppSpace.lg),
              _StatSection(
                title: 'GUIDA',
                tiles: [
                  _StatTile(label: 'Km totali', value: stats.totalKm.toStringAsFixed(0)),
                  _StatTile(label: 'Viaggi', value: '${stats.totalTrips}'),
                  _StatTile(
                      label: 'Velocità max',
                      value: stats.topSpeedKmh.toStringAsFixed(0),
                      unit: 'km/h'),
                  _StatTile(
                      label: 'Driving score',
                      value: stats.drivingScore.toStringAsFixed(1)),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              _StatSection(
                title: 'DETTAGLI DI GUIDA',
                tiles: [
                  _StatTile(
                      label: 'Dislivello totale',
                      value: stats.elevationGainTotalM.round().toString(),
                      unit: 'm'),
                  _StatTile(
                      label: 'Altitudine max',
                      value: stats.maxAltitudeM.round().toString(),
                      unit: 'm'),
                  _StatTile(
                      label: 'Picco G',
                      value: stats.peakGForce.toStringAsFixed(2),
                      unit: 'G'),
                  _StatTile(
                      label: 'Miglior 0-100',
                      value: stats.bestZeroToHundredSeconds != null
                          ? stats.bestZeroToHundredSeconds!.toStringAsFixed(2)
                          : '—',
                      unit: stats.bestZeroToHundredSeconds != null ? 's' : null),
                  _StatTile(
                      label: 'Vel. max in curva',
                      value: stats.maxCorneringSpeedKmh.toStringAsFixed(0),
                      unit: 'km/h'),
                  _StatTile(
                      label: 'Accelerazione max',
                      value: stats.maxAccelerationMs2.toStringAsFixed(1),
                      unit: 'm/s²'),
                  _StatTile(
                      label: 'Decelerazione max',
                      value: stats.maxDecelerationMs2.toStringAsFixed(1),
                      unit: 'm/s²'),
                  _StatTile(label: 'Svolte totali', value: '${stats.turnsTotal}'),
                  _StatTile(
                      label: 'Cambi corsia', value: '${stats.laneChangesTotal}'),
                  _StatTile(label: 'Frenate totali', value: '${stats.brakingEventsTotal}'),
                  _StatTile(label: 'Soste totali', value: '${stats.totalStopsTotal}'),
                  _StatTile(
                      label: 'Tempo da fermo',
                      value: formatStoppedTime(
                          Duration(seconds: stats.stoppedSecondsTotal))),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              _StatSection(
                title: 'TERRITORIO',
                tiles: [
                  _StatTile(label: 'Esagoni', value: '${stats.territoryCellCount}'),
                  _StatTile(
                      label: 'Area',
                      value: stats.territoryAreaKm2 < 0.1
                          ? stats.territoryAreaKm2.toStringAsFixed(3)
                          : stats.territoryAreaKm2.toStringAsFixed(2),
                      unit: 'km²'),
                  _StatTile(label: 'Rubati', value: '${stats.territoryStolen}'),
                  _StatTile(
                      label: 'Bilancio (30gg)',
                      value:
                          '${stats.territoryGrowth - stats.territoryDecline >= 0 ? '+' : ''}'
                          '${stats.territoryGrowth - stats.territoryDecline}'),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              _StatSection(
                title: 'COMMUNITY',
                tiles: [
                  _StatTile(label: 'Avvistamenti', value: '${stats.spotsCount}'),
                  _StatTile(label: 'Reputazione', value: '${stats.rep}'),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              _NavCard(
                icon: Icons.emoji_events_rounded,
                title: 'Achievement',
                subtitle:
                    'Sbloccati ${stats.achievementsEarned} / ${stats.achievementsTotal}',
                onTap: () => context.push(AppRoutes.achievements),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelHero extends StatelessWidget {
  final UserStatistics stats;
  const _LevelHero({required this.stats});

  @override
  Widget build(BuildContext context) {
    final xpIntoLevel = stats.xp % 1000;
    final progress = (xpIntoLevel / 1000).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: AppGlow.edge(AppColor.cyan),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LIVELLO', style: AppType.label),
          const SizedBox(height: AppSpace.xs),
          Text('${stats.level}',
              style: AppType.score.copyWith(fontSize: 64, color: AppColor.cyan)),
          const SizedBox(height: AppSpace.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColor.line,
              valueColor: const AlwaysStoppedAnimation(AppColor.cyan),
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text('${stats.xp} XP', style: AppType.caption),
        ],
      ),
    );
  }
}

class _StatSection extends StatelessWidget {
  final String title;
  final List<_StatTile> tiles;
  const _StatSection({required this.title, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppType.label),
        const SizedBox(height: AppSpace.sm),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpace.sm,
          crossAxisSpacing: AppSpace.sm,
          childAspectRatio: 1.9,
          children: tiles,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  const _StatTile({required this.label, required this.value, this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: AppGlow.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppType.metric.copyWith(fontSize: 22)),
              if (unit != null) ...[
                const SizedBox(width: AppSpace.xs),
                Text(unit!, style: AppType.caption),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: AppType.label),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: AppGlow.card,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColor.surfaceHigh,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Icon(icon, color: AppColor.inkMuted, size: 22),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppType.title.copyWith(fontSize: 17)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppType.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColor.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
