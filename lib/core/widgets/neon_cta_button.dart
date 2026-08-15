import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// CTA primaria dell'app: pill piena di ciano con un solo glow morbido,
/// nessun gradiente. È l'unico bottone acceso di una schermata — vedi
/// regola 1 di DESIGN.md.
class NeonCtaButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double minHeight;
  final double fontSize;

  const NeonCtaButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.minHeight = 58,
    this.fontSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: AppGlow.soft(AppColor.cyan, opacity: 0.3),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Material(
            color: AppColor.cyan,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                height: minHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: AppColor.void_, size: 22),
                        const SizedBox(width: AppSpace.sm),
                      ],
                      Text(
                        label.toUpperCase(),
                        style: AppType.text(
                          fontWeight: FontWeight.w800,
                          fontSize: fontSize,
                          color: AppColor.void_,
                          letterSpacing: fontSize * 0.05,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
