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

  // Rarity tiers (Car Spotting)
  static const Color rarityCommon = Color(0xFF9CA3AF);
  static const Color rarityUncommon = Color(0xFF39FF88);
  static const Color rarityRare = Color(0xFF00F0FF);
  static const Color rarityEpic = Color(0xFF8B5CF6);
  static const Color rarityLegendary = Color(0xFFFFB020);
}
