import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../achievements/presentation/providers/achievement_provider.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Vetrina del profilo — sola lettura (avatar, titolo, statistiche guida,
/// veicolo, scorciatoia Achievement). La modifica dei dati (username,
/// veicolo, paese, account/logout) resta in Impostazioni, raggiungibile
/// da qui con l'icona ingranaggio: non duplichiamo i flussi di editing.
///
/// Il protagonista è l'header identità (avatar + titolo, ciano): le
/// statistiche e le sezioni sotto restano grigie su superficie, nessun
/// accento concorrente (DESIGN.md, regola 1).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final earnedAchievements = ref
        .watch(myAchievementsProvider)
        .valueOrNull
        ?.where((a) => a.isEarned)
        .length;

    return Scaffold(
      backgroundColor: AppColor.void_,
      body: SafeArea(
        child: profile == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColor.cyan))
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.lg),
                children: [
                  Row(
                    children: [
                      _RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.pop(),
                      ),
                      const Spacer(),
                      _RoundIconButton(
                        icon: Icons.settings_rounded,
                        onTap: () => context.push(AppRoutes.settings),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  _ProfileHeader(profile: profile),
                  const SizedBox(height: AppSpace.lg),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(label: 'XP', value: '${profile.xp}'),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child:
                            _StatTile(label: 'REP', value: '${profile.rep}'),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: _StatTile(
                            label: 'Livello', value: '${profile.level}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: 'Km totali',
                          value: profile.totalKm.toStringAsFixed(0),
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: _StatTile(
                          label: 'Viaggi',
                          value: '${profile.totalTrips}',
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: _StatTile(
                          label: 'Driving Score',
                          value: profile.drivingScore.toStringAsFixed(1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  _SectionCard(
                    icon: Icons.directions_car_rounded,
                    title: 'Il tuo ride',
                    subtitle: profile.vehicleBrand == null
                        ? 'Nessun veicolo impostato'
                        : '${profile.vehicleBrand} ${profile.vehicleModel ?? ''}'
                            .trim(),
                    onTap: () => context.push(AppRoutes.settings),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  _SectionCard(
                    icon: Icons.emoji_events_rounded,
                    title: 'Achievement',
                    subtitle: earnedAchievements == null
                        ? 'Sbloccati —'
                        : 'Sbloccati $earnedAchievements',
                    onTap: () => context.push(AppRoutes.achievements),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final AppUser profile;
  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: AppGlow.edge(AppColor.cyan),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: AppColor.surfaceHigh,
              shape: BoxShape.circle,
            ),
            child: profile.avatarUrl != null
                ? ClipOval(
                    child: Image.network(profile.avatarUrl!, fit: BoxFit.cover),
                  )
                : const Icon(Icons.person_rounded,
                    color: AppColor.cyan, size: 44),
          ),
          const SizedBox(height: AppSpace.md),
          Text(profile.displayName, style: AppType.title.copyWith(fontSize: 24)),
          const SizedBox(height: 2),
          Text('@${profile.username}', style: AppType.caption),
          const SizedBox(height: AppSpace.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md, vertical: AppSpace.xs),
            decoration: BoxDecoration(
              color: AppColor.cyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border:
                  Border.all(color: AppColor.cyan.withValues(alpha: 0.4)),
            ),
            child: Text(
              profile.title,
              style: AppType.label.copyWith(color: AppColor.cyan, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
      decoration: AppGlow.card,
      child: Column(
        children: [
          Text(value, style: AppType.metric.copyWith(fontSize: 20)),
          const SizedBox(height: 2),
          Text(label, style: AppType.label),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SectionCard({
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
              const Icon(Icons.chevron_right_rounded,
                  color: AppColor.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.surfaceHigh.withValues(alpha: 0.94),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: AppColor.ink, size: 20),
        ),
      ),
    );
  }
}
