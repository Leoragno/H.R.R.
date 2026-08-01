import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/hrr_icons.dart';
import '../../domain/entities/achievement.dart';
import '../providers/achievement_provider.dart';

const _rarityColors = <AchievementRarity, Color>{
  AchievementRarity.common: AppColors.rarityCommon,
  AchievementRarity.uncommon: AppColors.rarityUncommon,
  AchievementRarity.rare: AppColors.rarityRare,
  AchievementRarity.epic: AppColors.rarityEpic,
  AchievementRarity.legendary: AppColors.rarityLegendary,
};

/// Lista Achievement del profilo — permanenti, assegnati automaticamente
/// lato server (nessun pulsante di riscatto, a differenza delle Missioni).
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementsAsync = ref.watch(myAchievementsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Achievement')),
      body: achievementsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.neonCyan)),
        error: (e, _) => Center(
          child: Text('Errore caricamento achievement',
              style: TextStyle(color: AppColors.danger)),
        ),
        data: (achievements) {
          if (achievements.isEmpty) {
            return const Center(
              child: Text('Nessun achievement disponibile',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          final earnedCount = achievements.where((a) => a.isEarned).length;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'SBLOCCATI $earnedCount / ${achievements.length}',
                    style: AppTheme.orbitron(
                        fontSize: 13, color: AppColors.neonCyan),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                sliver: SliverList.separated(
                  itemCount: achievements.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) =>
                      _AchievementTile(achievement: achievements[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;
  const _AchievementTile({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final earned = achievement.isEarned;
    final color = earned
        ? (_rarityColors[achievement.rarity] ?? AppColors.neonCyan)
        : AppColors.textDisabled;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: earned ? color.withOpacity(0.1) : AppColors.surfaceGlass,
        border: Border.all(
            color: earned ? color.withOpacity(0.4) : AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: color.withOpacity(0.16),
            ),
            child: Icon(
                hrrIconByKey[achievement.icon] ?? Icons.emoji_events_rounded,
                color: color,
                size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.name,
                  style: AppTheme.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: earned ? Colors.white : AppColors.textDisabled,
                  ),
                ),
                const SizedBox(height: 2),
                Text(achievement.description,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary)),
                if (earned) ...[
                  const SizedBox(height: 6),
                  Text(
                    'REP +${achievement.rewardRep} · XP +${achievement.rewardXp}',
                    style: TextStyle(
                        fontFamily: 'monospace', fontSize: 9.5, color: color),
                  ),
                ],
              ],
            ),
          ),
          if (!earned)
            const Icon(Icons.lock_rounded,
                size: 18, color: AppColors.textDisabled),
        ],
      ),
    );
  }
}
