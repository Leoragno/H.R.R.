import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/neon_cta_button.dart';
import '../../../rival/presentation/providers/active_mascot_provider.dart';
import '../../../rival/presentation/widgets/mascot_avatar.dart';
import '../../domain/entities/leaderboard_entry.dart';
import 'leaderboard_avatar.dart';

/// Confronto "VS" tra l'utente e il rivale immediatamente sopra di lui
/// nella classifica canonica (xp/settimana/globale) — l'unica per cui
/// esiste tracking del sorpasso (vedi rivalry_tracker.dart e il listener
/// in leaderboard_screen.dart). Non fa alcuna chiamata di rete propria:
/// [entries] è la lista già ottenuta da leaderboardProvider, questo
/// widget si limita a derivarne il confronto.
class RivalryCard extends ConsumerWidget {
  final List<LeaderboardEntry> entries;
  final String myId;
  const RivalryCard({super.key, required this.entries, required this.myId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myIndex = entries.indexWhere((e) => e.profileId == myId);
    if (myIndex == -1) return const SizedBox.shrink();

    final mascot = ref.watch(activeMascotProvider);

    if (myIndex == 0) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xE50A0E1A),
          border: Border.all(color: mascot.accentColor.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            MascotAvatar(mascot: mascot, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Sei primo in classifica 👑',
                      style: AppType.text(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColor.ink)),
                  const SizedBox(height: 2),
                  Text('Nessun rivale sopra di te — per ora.',
                      style: AppType.text(
                          fontSize: 13, color: AppColor.inkMuted)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final me = entries[myIndex];
    final rival = entries[myIndex - 1];
    final gap = rival.periodXp - me.periodXp;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xE50A0E1A),
        border: Border.all(color: const Color(0x29A0C8FF)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    MascotAvatar(mascot: mascot, size: 56),
                    const SizedBox(height: 6),
                    Text('TU · #${me.rank}',
                        style: AppType.text(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: mascot.accentColor)),
                  ],
                ),
              ),
              Text('VS',
                  style: AppType.display(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: AppColor.inkMuted)),
              Expanded(
                child: Column(
                  children: [
                    LeaderboardAvatar(url: rival.avatarUrl, size: 56),
                    const SizedBox(height: 6),
                    Text('${rival.displayName} · #${rival.rank}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.text(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColor.ink)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            gap <= 0
                ? 'Sei alla pari, sorpasso a un passo!'
                : '$gap XP ti separano da ${rival.displayName}.',
            textAlign: TextAlign.center,
            style: AppType.text(
                fontSize: 13, color: AppColor.inkMuted),
          ),
          const SizedBox(height: 14),
          NeonCtaButton(
            label: 'SFIDALO',
            minHeight: 44,
            fontSize: 15,
            onPressed: () => context.go(AppRoutes.home),
          ),
        ],
      ),
    );
  }
}
