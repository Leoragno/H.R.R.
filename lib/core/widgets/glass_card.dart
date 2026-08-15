import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Card "vetro" ricorrente nel design "Guida": sfondo scuro semi-trasparente
/// a gradiente, bordo hairline chiaro, ombra morbida e blur di sfondo.
/// Trattamento invariato dal design originale (componente_guida_driving_
/// handoff/), solo tokenizzato — la revisione verso `AppGlow.card` piatto
/// di DESIGN.md è una scelta per-schermata, non di questo widget condiviso.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final List<Color>? gradientColors;
  final Color borderColor;
  final VoidCallback? onTap;
  final bool blur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.md),
    this.radius = AppRadius.card,
    this.gradientColors,
    this.borderColor = AppColor.line,
    this.onTap,
    this.blur = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ??
        [
          AppColor.surface.withValues(alpha: 0.90),
          AppColor.void_.withValues(alpha: 0.94),
        ];

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColor.void_.withValues(alpha: 0.5),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );

    final clipped = blur
        ? ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: content,
            ),
          )
        : content;

    if (onTap == null) return clipped;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: clipped,
      ),
    );
  }
}
