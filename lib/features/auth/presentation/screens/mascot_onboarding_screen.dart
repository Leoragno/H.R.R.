import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/neon_cta_button.dart';
import '../../../rival/domain/entities/mascot.dart';
import '../../../rival/presentation/widgets/mascot_avatar.dart';
import '../providers/auth_provider.dart';

/// Onboarding "scegli la tua mascotte": mostrata una volta dopo la
/// registrazione (gate nel router — vedi app_router.dart), dopo lo step
/// veicolo. Stesso pattern di RideOnboardingScreen: nessuna navigazione
/// esplicita al termine, il router osserva myProfileProvider e ci porta
/// via da qui appena mascot_id è valorizzato.
class MascotOnboardingScreen extends ConsumerStatefulWidget {
  const MascotOnboardingScreen({super.key});

  @override
  ConsumerState<MascotOnboardingScreen> createState() =>
      _MascotOnboardingScreenState();
}

class _MascotOnboardingScreenState
    extends ConsumerState<MascotOnboardingScreen> {
  String? _selectedId;

  Future<void> _continue() async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    final selected = _selectedId;
    if (userId == null || selected == null) return;
    await ref
        .read(authControllerProvider.notifier)
        .updateProfileSettings(userId: userId, mascotId: selected);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.guidaBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Scegli la tua mascotte',
                textAlign: TextAlign.center,
                style: AppTheme.archivo(
                  fontWeight: FontWeight.w900,
                  fontSize: 30,
                  color: AppColors.textPrimary,
                ),
              ).animate().fadeIn().slideY(begin: 0.1, end: 0),
              const SizedBox(height: 12),
              Text(
                'Ti accompagnerà e ti provocherà lungo la strada',
                textAlign: TextAlign.center,
                style: AppTheme.archivo(
                  fontSize: 16,
                  color: AppColors.guidaTextSecondary,
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.85,
                  children: [
                    for (final m in kMascotCatalog)
                      _MascotOption(
                        mascot: m,
                        selected: m.id == _selectedId,
                        onTap: () => setState(() => _selectedId = m.id),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              NeonCtaButton(
                label: 'Continua',
                onPressed:
                    _selectedId != null && !isLoading ? _continue : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MascotOption extends StatelessWidget {
  final Mascot mascot;
  final bool selected;
  final VoidCallback onTap;

  const _MascotOption({
    required this.mascot,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? mascot.accentColor.withValues(alpha: 0.12)
          : const Color(0xF00A0E1A),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? mascot.accentColor
                  : const Color(0x29A0C8FF),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MascotAvatar(mascot: mascot, size: 84),
              const SizedBox(height: 10),
              Text(mascot.name,
                  style: AppTheme.orbitron(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: mascot.accentColor)),
              const SizedBox(height: 4),
              Text(mascot.tagline,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.archivo(
                      fontSize: 12, color: AppColors.guidaTextSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
