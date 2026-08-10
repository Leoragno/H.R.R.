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
      backgroundColor: AppColors.guidaBg,
      body: SafeArea(
        child: profile == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.guidaCyan))
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
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
                  const SizedBox(height: 18),
                  _ProfileHeader(profile: profile),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: 'XP',
                          value: '${profile.xp}',
                          color: AppColors.guidaCyan,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatTile(
                          label: 'REP',
                          value: '${profile.rep}',
                          color: AppColors.guidaMagenta,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatTile(
                          label: 'Livello',
                          value: '${profile.level}',
                          color: AppColors.guidaPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: 'Km totali',
                          value: profile.totalKm.toStringAsFixed(0),
                          color: AppColors.guidaBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatTile(
                          label: 'Viaggi',
                          value: '${profile.totalTrips}',
                          color: AppColors.guidaBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatTile(
                          label: 'Driving Score',
                          value: profile.drivingScore.toStringAsFixed(1),
                          color: AppColors.guidaBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    icon: Icons.directions_car_rounded,
                    iconBg: const Color(0xFF6B21A8),
                    iconColor: const Color(0xFFE879F9),
                    title: 'Il tuo ride',
                    subtitle: profile.vehicleBrand == null
                        ? 'Nessun veicolo impostato'
                        : '${profile.vehicleBrand} ${profile.vehicleModel ?? ''}'
                            .trim(),
                    onTap: () => context.push(AppRoutes.settings),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    icon: Icons.emoji_events_rounded,
                    iconBg: const Color(0xFF7C4A10),
                    iconColor: const Color(0xFFF59E0B),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xDB141B30), Color(0xEB0A0E18)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1AA0C8FF)),
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: profile.avatarUrl != null
                ? ClipOval(
                    child: Image.network(profile.avatarUrl!, fit: BoxFit.cover),
                  )
                : const Icon(Icons.person_rounded,
                    color: AppColors.guidaCyan, size: 44),
          ),
          const SizedBox(height: 14),
          Text(
            profile.displayName,
            style: AppTheme.archivo(
              fontWeight: FontWeight.w900,
              fontSize: 24,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '@${profile.username}',
            style: AppTheme.archivo(
              fontSize: 15,
              color: AppColors.guidaTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.guidaCyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border:
                  Border.all(color: AppColors.guidaCyan.withValues(alpha: 0.4)),
            ),
            child: Text(
              profile.title,
              style: AppTheme.archivo(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.guidaCyan,
              ),
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
  final Color color;
  const _StatTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xDB141B30), Color(0xEB0A0E18)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1AA0C8FF)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.archivo(
                fontWeight: FontWeight.w900, fontSize: 20, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.archivo(
                fontSize: 11.5, color: AppColors.guidaTextSecondary),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SectionCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xDB141B30), Color(0xEB0A0E18)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x1AA0C8FF)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTheme.archivo(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: AppTheme.archivo(
                            fontSize: 13.5,
                            color: AppColors.guidaTextSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.guidaTextSecondary),
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
      color: const Color(0xF0131A2D),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: AppColors.textPrimary, size: 20),
        ),
      ),
    );
  }
}
