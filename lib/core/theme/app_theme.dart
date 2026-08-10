import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Central Material 3 theme for HRR. Dark-only by design (racing HUD aesthetic).
///
/// Orbitron/Inter sono serviti via google_fonts (scaricati e messi in cache
/// al primo utilizzo) invece di file .ttf committati nel repo.
class AppTheme {
  AppTheme._();

  /// Stile HUD/branding (contachilometri, titoli schermo, logo "HRR").
  static TextStyle orbitron({
    FontWeight fontWeight = FontWeight.w700,
    double? fontSize,
    Color color = AppColors.textPrimary,
    double? letterSpacing,
  }) =>
      GoogleFonts.orbitron(
        fontWeight: fontWeight,
        fontSize: fontSize,
        color: color,
        letterSpacing: letterSpacing,
      );

  /// Titoli/numeri grandi delle schermate riskinnate col nuovo design
  /// "Guida" (componente_guida_driving_handoff/) — non sostituisce Orbitron,
  /// riservato al logo HRR e ai contesti HUD già esistenti.
  static TextStyle chakraPetch({
    FontWeight fontWeight = FontWeight.w700,
    double? fontSize,
    Color color = AppColors.textPrimary,
    double? letterSpacing,
    FontStyle? fontStyle,
  }) =>
      GoogleFonts.chakraPetch(
        fontWeight: fontWeight,
        fontSize: fontSize,
        color: color,
        letterSpacing: letterSpacing,
        fontStyle: fontStyle,
      );

  /// Body/testo delle schermate riskinnate col nuovo design "Guida".
  static TextStyle archivo({
    FontWeight fontWeight = FontWeight.w400,
    double? fontSize,
    Color color = AppColors.textPrimary,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
  }) =>
      GoogleFonts.archivo(
        fontWeight: fontWeight,
        fontSize: fontSize,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontStyle: fontStyle,
      );

  static ThemeData get dark {
    final baseTextTheme = GoogleFonts.interTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme);

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: baseTextTheme,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.neonCyan,
        secondary: AppColors.neonMagenta,
        surface: AppColors.surface,
        error: AppColors.danger,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: AppColors.textPrimary,
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: orbitron(letterSpacing: 0.5),
        headlineMedium: orbitron(),
        titleLarge: GoogleFonts.inter(
            fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        bodyMedium:
            GoogleFonts.inter(color: AppColors.textSecondary, height: 1.4),
        labelLarge: GoogleFonts.inter(
            fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: orbitron(fontSize: 20),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceGlass,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.neonCyan,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceGlass,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.neonCyan, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.textDisabled),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.neonCyan,
        unselectedItemColor: AppColors.textSecondary,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme:
          const DividerThemeData(color: AppColors.border, thickness: 1),
    );
  }
}
