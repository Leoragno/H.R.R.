import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Minimum splash duration for brand feel, plus real session check.
    final results = await Future.wait([
      ref.read(authRepositoryProvider).currentUser(),
      Future.delayed(const Duration(milliseconds: 1400)),
    ]);
    if (!mounted) return;

    final user = results[0];
    context.go(user != null ? AppRoutes.home : AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: AppColors.gradientPrimary,
              ).createShader(bounds),
              child: Text(
                'HRR',
                style: AppTheme.orbitron(
                  fontWeight: FontWeight.w900,
                  fontSize: 64,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
            ).animate().fadeIn(duration: 500.ms).scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: 12),
            const Text(
              'HEAT RACERS',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                letterSpacing: 6,
                fontWeight: FontWeight.w600,
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
            const SizedBox(height: 48),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                backgroundColor: AppColors.surfaceGlass,
                valueColor: const AlwaysStoppedAnimation(AppColors.neonCyan),
                minHeight: 3,
                borderRadius: BorderRadius.circular(4),
              ),
            ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }
}
