import 'package:flutter/material.dart';

/// HRR Design Tokens — Night Racing / Glassmorphism / Neon palette.
/// Single source of truth for color usage across the app.
class AppColors {
  AppColors._();

  // Base surfaces (carbon fiber / night mode)
  static const Color background = Color(0xFF06070B);
  static const Color surface = Color(0xFF0E1016);
  static const Color surfaceElevated = Color(0xFF161923);
  static const Color surfaceGlass =
      Color(0x1AFFFFFF); // white 10% for glass panels
  static const Color border = Color(0x33FFFFFF); // hairline on glass

  // Neon accents
  static const Color neonCyan = Color(0xFF00F0FF);
  static const Color neonMagenta = Color(0xFFFF2EC4);
  static const Color neonPurple = Color(0xFF8B5CF6);
  static const Color neonGreen = Color(0xFF39FF88);
  static const Color neonAmber = Color(0xFFFFB020);
  static const Color neonRed = Color(0xFFFF3B5C);

  // Gradients
  static const List<Color> gradientPrimary = [neonCyan, neonMagenta];
  static const List<Color> gradientXp = [neonPurple, neonCyan];
  static const List<Color> gradientRep = [neonAmber, neonMagenta];
  static const List<Color> gradientSpeed = [
    Color(0xFF00C6FF),
    Color(0xFF0072FF)
  ];

  // Text
  static const Color textPrimary = Color(0xFFF5F7FA);
  static const Color textSecondary = Color(0xFFA0A6B8);
  static const Color textDisabled = Color(0xFF565B6B);

  // Semantic
  static const Color success = neonGreen;
  static const Color warning = neonAmber;
  static const Color danger = neonRed;

  // Rarity tiers (Car Spotting) — palette dal design "HRR Car Spotting"
  // (COMUNE/NON COMUNE/RARA/MOLTO RARA/LEGGENDARIA), con tinte di sfondo
  // dedicate per le card rarità.
  static const Color rarityCommon = Color(0xFF9FB0C6);
  static const Color rarityUncommon = Color(0xFF7EE0A5);
  static const Color rarityRare = Color(0xFF7FC4FF);
  static const Color rarityEpic = Color(0xFFC79BFF);
  static const Color rarityLegendary = Color(0xFFFFB703);

  static const Color rarityCommonBg = Color(0xB8141C2C); // rgba(20,28,44,.72)
  static const Color rarityUncommonBg = Color(0xB80C2218); // rgba(12,34,24,.72)
  static const Color rarityRareBg = Color(0xB80C1A30); // rgba(12,26,48,.72)
  static const Color rarityEpicBg = Color(0xB81A102C); // rgba(26,16,44,.72)
  static const Color rarityLegendaryBg = Color(0xC7261804); // rgba(38,24,4,.78)

  // ---------------------------------------------------------------------
  // "Guida" design system — token aggiuntivi presi 1:1 dal Claude Design
  // handoff (componente_guida_driving_handoff/). Usati esplicitamente solo
  // dalle schermate riskinnate (auth, ride, mappa/guida, speedometer,
  // classifiche, spot, impostazioni): il tema globale sopra resta
  // invariato per non toccare le schermate fuori scope.
  static const Color guidaBg = Color(0xFF060810);
  static const Color guidaBg2 = Color(0xFF05070B);
  static const Color guidaCyan = Color(0xFF35E0FF);
  static const Color guidaBlue = Color(0xFF2F6BFF);
  static const Color guidaMagenta = Color(0xFFFF2FD0);
  static const Color guidaPurple = Color(0xFF7B3BFF);
  static const Color guidaTextSecondary = Color(0xFF8FA3BD);
  static const Color guidaOnAccent = Color(0xFF02121F);

  static const List<Color> guidaGradientCta = [
    guidaCyan,
    guidaBlue,
    guidaMagenta,
  ];
}
