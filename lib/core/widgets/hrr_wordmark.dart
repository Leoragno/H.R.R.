import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Lockup "HRR" / "HEAT RACERS" — stesso trattamento grafico dello splash
/// screen (Orbitron + gradiente `AppColors.gradientPrimary`), riusato nelle
/// schermate riskinnate al posto del lockup HRR del nuovo design (che usa
/// Chakra Petch corsivo/skewed): l'utente ha chiesto di mantenere questo
/// logo perché "era meglio" di quello del mockup.
class HrrWordmark extends StatelessWidget {
  final double fontSize;
  final bool showTagline;

  const HrrWordmark({
    super.key,
    this.fontSize = 32,
    this.showTagline = true,
  });

  @override
  Widget build(BuildContext context) {
    final wordmark = ShaderMask(
      shaderCallback: (bounds) =>
          const LinearGradient(colors: AppColors.gradientPrimary)
              .createShader(bounds),
      child: Text(
        'HRR',
        style: AppTheme.orbitron(
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          color: Colors.white,
          letterSpacing: fontSize * 0.06,
        ),
      ),
    );

    if (!showTagline) return wordmark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        wordmark,
        SizedBox(height: fontSize * 0.18),
        Text(
          'HEAT RACERS',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: fontSize * 0.22,
            letterSpacing: fontSize * 0.1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
