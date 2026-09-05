import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Voce della sheet "Segnala qui" (long-press sulla mappa) — condivisa fra
/// home_map_background.dart e trip_live_screen.dart, stesso stile.
class ReportOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const ReportOptionTile(
      {super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.surfaceHigh,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md, vertical: AppSpace.md),
          child: Row(
            children: [
              Icon(icon, color: AppColor.cyan),
              const SizedBox(width: AppSpace.sm),
              Text(label,
                  style: AppType.text(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: AppColor.ink)),
            ],
          ),
        ),
      ),
    );
  }
}
