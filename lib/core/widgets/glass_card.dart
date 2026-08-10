import 'dart:ui';

import 'package:flutter/material.dart';

/// Card "vetro" ricorrente nel design "Guida": sfondo scuro semi-trasparente
/// a gradiente, bordo hairline chiaro, ombra morbida e blur di sfondo.
/// Vedi componente_guida_driving_handoff/ per i valori originali.
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
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.gradientColors,
    this.borderColor = const Color(0x29A0C8FF), // rgba(120,150,255,0.16)
    this.onTap,
    this.blur = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ??
        const [Color(0xE6101624), Color(0xF0080C14)]; // ~0.9 / 0.94 alpha

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
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 34,
            offset: Offset(0, 16),
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
