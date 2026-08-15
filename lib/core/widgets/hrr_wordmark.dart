import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Lockup "HRR" / "HEAT RACERS" — stesso trattamento grafico dello splash
/// screen (Rajdhani + gradiente ciano→magenta), riusato nelle schermate
/// riskinnate al posto del lockup HRR del nuovo design (che usa Chakra
/// Petch corsivo/skewed): l'utente ha chiesto di mantenere questo logo
/// perché "era meglio" di quello del mockup. Unica eccezione dichiarata
/// alla regola "niente gradienti" di DESIGN.md: è il marchio, non un
/// indicatore di stato.
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
          const LinearGradient(colors: [AppColor.cyan, AppColor.magenta])
              .createShader(bounds),
      child: Text(
        'HRR',
        style: AppType.display(
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
            color: AppColor.inkMuted,
            fontSize: fontSize * 0.22,
            letterSpacing: fontSize * 0.1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
