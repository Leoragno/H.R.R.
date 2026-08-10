import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Scaffold placeholder condiviso per le feature ancora da sviluppare.
/// Estratto dalla duplicazione identica presente in 8 schermate (Eventi,
/// Notifiche, Crew, Car Spotting, Chat, Classifica, Impostazioni, Mappa).
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget>? actions;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title), actions: actions),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.neonCyan.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'In sviluppo — Fase successiva',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
