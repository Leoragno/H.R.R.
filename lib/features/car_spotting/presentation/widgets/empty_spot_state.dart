import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class EmptySpotState extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptySpotState({
    super.key,
    this.message =
        'Nessuna auto avvistata ancora.\nSii il primo a pubblicare uno spot!',
    this.icon = Icons.camera_alt_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColor.inkFaint),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppColor.inkMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
