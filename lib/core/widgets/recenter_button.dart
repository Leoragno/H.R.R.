import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Pulsante circolare "torna sulla mia posizione" — usato dalle mappe che
/// non seguono più automaticamente il GPS ad ogni fix (Guida live e Gioca),
/// per lasciare l'utente libero di guardarsi intorno/zoomare senza che la
/// camera si riagganci da sola.
class RecenterButton extends StatelessWidget {
  final VoidCallback onTap;
  const RecenterButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.surfaceHigh.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(AppSpace.md),
          child: Icon(Icons.my_location_rounded, color: AppColor.ink, size: 26),
        ),
      ),
    );
  }
}
