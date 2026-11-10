import 'package:flutter/material.dart';

import 'heat/heat_widgets.dart';

/// CTA primaria dell'app. Ora è un [HeatButton] (parallelogramma pieno
/// d'accento con glow): resta come nome storico per i call site esistenti.
/// È l'unico bottone acceso di una schermata — vedi regola 1 di DESIGN.md.
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
    this.minHeight = 60,
    this.fontSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return HeatButton(
      label: label,
      onPressed: onPressed,
      icon: icon ?? Icons.keyboard_double_arrow_right_rounded,
      height: minHeight,
      fontSize: fontSize,
    );
  }
}
