import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';
import '../../../../core/theme/hrr_icons.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../car_spotting/presentation/providers/car_spotting_provider.dart';
import '../../../game/presentation/providers/territory_provider.dart';
import '../../domain/entities/achievement.dart';
import '../providers/achievement_provider.dart';

const _rarityColors = <AchievementRarity, Color>{
  AchievementRarity.common: AppColor.rarityCommon,
  AchievementRarity.uncommon: AppColor.rarityUncommon,
  AchievementRarity.rare: AppColor.rarityRare,
  AchievementRarity.epic: AppColor.rarityEpic,
  AchievementRarity.legendary: AppColor.rarityLegendary,
};

const _rarityLabels = <AchievementRarity, String>{
  AchievementRarity.common: 'COMUNE',
  AchievementRarity.uncommon: 'NON COMUNE',
  AchievementRarity.rare: 'RARO',
  AchievementRarity.epic: 'EPICO',
  AchievementRarity.legendary: 'LEGGENDARIO',
};

/// Limite della query "i miei spot": oltre, il conteggio non è affidabile.
const _spotsQueryLimit = 50;

/// Valore attuale di ogni metrica achievement calcolabile dal client
/// (stessa definizione di `evaluate_achievements`, migrazione 0033).
/// Le metriche sommate sullo storico intero (salite, curve, soste, cambi
/// corsia) non sono disponibili qui: quelle card non mostrano la barra.
final achievementMetricsProvider = Provider<Map<String, double>>((ref) {
  final p = ref.watch(myProfileProvider).valueOrNull;
  final cells = ref.watch(myTerritoriesProvider).valueOrNull;
  final spots = ref.watch(mySpotsProvider).valueOrNull;
  return {
    if (p != null) ...{
      'total_km': p.totalKm,
      'total_trips': p.totalTrips.toDouble(),
      'rep': p.rep.toDouble(),
      'level': p.level.toDouble(),
      'xp': p.xp.toDouble(),
      'driving_score': p.drivingScore,
    },
    if (cells != null) 'territory_cells_owned': cells.length.toDouble(),
    if (spots != null) 'cars_spotted': spots.length.toDouble(),
  };
});

/// Avanzamento 0..1 verso un achievement non ancora ottenuto; null se la
/// metrica non è nota al client.
double? achievementProgress(Achievement a, Map<String, double> metrics) {
  if (a.isEarned) return 1;
  final v = metrics[a.targetMetric];
  if (v == null || a.targetValue <= 0) return null;
  if (a.targetMetric == 'cars_spotted' &&
      v >= _spotsQueryLimit &&
      a.targetValue > _spotsQueryLimit) {
    return null;
  }
  return (v / a.targetValue).clamp(0, 1).toDouble();
}

/// ACHIEVEMENT (HEAT, handoff §23): griglia a due colonne di card
/// smussate. Ottenuti: icona e rarità nel colore della rarità; bloccati:
/// grigi con la barra di avanzamento. Tocca per i dettagli (premio e
/// avanzamento). In cima, collegamento alle Missioni.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myAchievementsProvider);
    final metrics = ref.watch(achievementMetricsProvider);
    final list = async.valueOrNull ?? const <Achievement>[];
    final earned = list.where((a) => a.isEarned).length;

    // Ottenuti prima (i più recenti in cima), poi i più vicini al traguardo.
    final sorted = [...list]..sort((a, b) {
        if (a.isEarned != b.isEarned) return a.isEarned ? -1 : 1;
        if (a.isEarned) return b.earnedAt!.compareTo(a.earnedAt!);
        final pa = achievementProgress(a, metrics) ?? -1;
        final pb = achievementProgress(b, metrics) ?? -1;
        return pb.compareTo(pa);
      });

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
              ref.invalidate(myAchievementsProvider);
              await ref.read(myAchievementsProvider.future);
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 14, 0),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => context.canPop()
                                  ? context.pop()
                                  : context.go(AppRoutes.profile),
                              icon: const Icon(Icons.arrow_back_rounded,
                                  color: AppColor.ink),
                            ),
                            const Spacer(),
                            HeatChip(
                              label: 'MISSIONI',
                              leading: const Icon(Icons.flag_rounded,
                                  size: 16, color: AppColor.gold),
                              onTap: () => context.push(AppRoutes.missions),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Expanded(
                              child: ScreenTitle('Achievement', fontSize: 48),
                            ),
                            if (list.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '$earned/${list.length}',
                                  style: AppType.display(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: AppColor.gold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                ...async.when(
                  loading: () => const [
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 200,
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: AppColor.inkMuted),
                          ),
                        ),
                      ),
                    ),
                  ],
                  error: (e, _) => const [
                    SliverToBoxAdapter(
                      child: _Message('achievement non disponibili. '
                          'trascina giù per riprovare.'),
                    ),
                  ],
                  data: (_) => sorted.isEmpty
                      ? const [
                          SliverToBoxAdapter(
                            child: _Message('nessun achievement disponibile.'),
                          ),
                        ]
                      : [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 30),
                            sliver: SliverGrid.builder(
                              itemCount: sorted.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 6,
                                crossAxisSpacing: 6,
                                mainAxisExtent: 168,
                              ),
                              itemBuilder: (context, i) => AchievementCard(
                                achievement: sorted[i],
                                progress:
                                    achievementProgress(sorted[i], metrics),
                                onTap: () => _showDetail(context, sorted[i],
                                    achievementProgress(sorted[i], metrics)),
                              ),
                            ),
                          ),
                        ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _showDetail(BuildContext context, Achievement a, double? p) {
    final reward = [
      if (a.rewardXp > 0) '+${a.rewardXp} XP',
      if (a.rewardRep > 0) '+${a.rewardRep} REP',
    ].join(' · ');
    final d = a.earnedAt;
    final status = a.isEarned
        ? 'ottenuto il ${d!.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/${d.year}'
        : p == null
            ? 'ancora bloccato'
            : 'avanzamento ${(p * 100).floor()}%';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content:
            Text([a.name, status, if (reward.isNotEmpty) reward].join(' · ')),
      ));
  }
}

class AchievementCard extends StatelessWidget {
  const AchievementCard({
    super.key,
    required this.achievement,
    required this.progress,
    required this.onTap,
  });

  final Achievement achievement;
  final double? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final earned = a.isEarned;
    final rarity = _rarityColors[a.rarity] ?? AppColor.inkMuted;
    final c = earned ? rarity : AppColor.inkFaint;

    return HeatPanel(
      onTap: onTap,
      shape: ChamferBorder(
        cut: 14,
        side: BorderSide(
          color: earned ? rarity.withValues(alpha: .45) : AppColor.line,
        ),
      ),
      color: earned
          ? Color.alphaBlend(rarity.withValues(alpha: .08), AppColor.surface)
          : AppColor.surface,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                earned
                    ? (hrrIconByKey[a.icon] ?? Icons.emoji_events_rounded)
                    : Icons.lock_rounded,
                size: 30,
                color: c,
              ),
              const Spacer(),
              Text(
                _rarityLabels[a.rarity] ?? '',
                style: AppType.display(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  italic: false,
                  letterSpacing: 1.4,
                  color: c,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            a.name.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.display(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1,
              color: earned ? AppColor.ink : AppColor.inkMuted,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              a.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppType.text(
                  fontSize: 12, color: AppColor.inkMuted, height: 1.35),
            ),
          ),
          if (!earned && progress != null)
            SkewBar(value: progress!, height: 4, color: AppColor.inkMuted),
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
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style:
            AppType.text(fontSize: 14, color: AppColor.inkMuted, height: 1.45),
      ),
    );
  }
}
