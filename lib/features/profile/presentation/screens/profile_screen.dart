import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';

/// Scaffold reale (non mock) pronto per essere sviluppato in dettaglio
/// nella prossima fase. Mantiene coerenza visiva col tema HRR.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profilo')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_rounded,
                size: 56, color: AppColors.neonCyan.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(
              'Profilo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'In sviluppo — Fase successiva',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.achievements),
              icon: const Icon(Icons.emoji_events_rounded),
              label: const Text('Achievement'),
            ),
          ],
        ),
      ),
    );
  }
}
