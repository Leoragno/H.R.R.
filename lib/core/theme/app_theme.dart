// SMOOTH — design system
// Regola unica: il neon è LUCE, non colore di riempimento.
// Se un elemento non è attivo, non brilla.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

// ---------------------------------------------------------------------------
// TIPOGRAFIA
// ---------------------------------------------------------------------------
// Due ruoli, contrasto netto:
//   display  Rajdhani condensato, maiuscolo, per numeri e label tecniche
//   body     Inter, per tutto il resto
// Il contrasto tra i due fa metà del lavoro estetico. Non aggiungere un terzo font.

abstract final class AppType {
  static TextStyle get score => GoogleFonts.rajdhani(
    fontSize: 88,
    height: 0.9,
    fontWeight: FontWeight.w700,
    letterSpacing: -2,
    color: AppColor.ink,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle get metric => GoogleFonts.rajdhani(
    fontSize: 32,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: AppColor.ink,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Etichette sopra i dati: sempre maiuscole, sempre spaziate, sempre mute.
  static TextStyle get label => GoogleFonts.rajdhani(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
    color: AppColor.inkMuted,
  );

  static TextStyle get title => GoogleFonts.inter(
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: AppColor.ink,
  );

  static TextStyle get body => GoogleFonts.inter(
    fontSize: 15,
    height: 1.5,
    color: AppColor.ink,
  );

  static TextStyle get caption => GoogleFonts.inter(
    fontSize: 13,
    height: 1.4,
    color: AppColor.inkMuted,
  );

  /// Ponte per call site ereditati dal vecchio tema con dimensioni/pesi
  /// custom (ex `AppTheme.orbitron`/`chakraPetch`). UI nuova: usa i ruoli
  /// fissi sopra, non questo.
  static TextStyle display({
    FontWeight fontWeight = FontWeight.w700,
    double? fontSize,
    Color color = AppColor.ink,
    double? letterSpacing,
  }) => GoogleFonts.rajdhani(
    fontWeight: fontWeight,
    fontSize: fontSize,
    color: color,
    letterSpacing: letterSpacing,
  );

  /// Ponte per call site ereditati dal vecchio tema (ex `AppTheme.archivo`).
  /// UI nuova: usa `body`/`caption`/`title` sopra, non questo.
  static TextStyle text({
    FontWeight fontWeight = FontWeight.w400,
    double? fontSize,
    Color color = AppColor.ink,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
  }) => GoogleFonts.inter(
    fontWeight: fontWeight,
    fontSize: fontSize,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    fontStyle: fontStyle,
  );
}

// ---------------------------------------------------------------------------
// SPAZIO E FORMA
// ---------------------------------------------------------------------------

abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 40.0;
  static const xxl = 64.0;
}

abstract final class AppRadius {
  static const card = 14.0;
  static const control = 10.0;
  static const pill = 999.0;
}

// ---------------------------------------------------------------------------
// GLOW
// ---------------------------------------------------------------------------
// L'errore che rende il neon "template": glow su tutto.
// Regola: un solo elemento acceso per schermata. Il resto vive di bordi grigi.

abstract final class AppGlow {
  /// Alone morbido per l'elemento attivo. blur alto, opacità bassa, zero spread.
  static List<BoxShadow> soft(Color c, {double opacity = 0.35}) => [
    BoxShadow(color: c.withValues(alpha: opacity), blurRadius: 24),
  ];

  /// Solo per il momento di rivelazione del punteggio o della conquista.
  static List<BoxShadow> peak(Color c) => [
    BoxShadow(color: c.withValues(alpha: 0.50), blurRadius: 40),
    BoxShadow(color: c.withValues(alpha: 0.20), blurRadius: 90),
  ];

  /// Bordo acceso: 1px pieno + alone. Più credibile del bordo spesso colorato.
  static BoxDecoration edge(
    Color c, {
    Color fill = AppColor.surface,
    double radius = AppRadius.card,
  }) => BoxDecoration(
    color: fill,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: c.withValues(alpha: 0.55), width: 1),
    boxShadow: soft(c, opacity: 0.22),
  );

  /// Card normale: nessun neon. È il 90% dell'interfaccia.
  static BoxDecoration get card => BoxDecoration(
    color: AppColor.surface,
    borderRadius: BorderRadius.circular(AppRadius.card),
    border: Border.all(color: AppColor.line, width: 1),
  );
}

// ---------------------------------------------------------------------------
// MOTION
// ---------------------------------------------------------------------------
// Veloce e secco. Niente elastic, niente bounce: il riferimento è un cluster
// digitale d'auto, non un'app per bambini.

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 140); // tap, stati
  static const base = Duration(milliseconds: 220); // transizioni
  static const reveal = Duration(milliseconds: 620); // conteggio punteggio
  static const curve = Curves.easeOutCubic;
}

// ---------------------------------------------------------------------------
// THEME
// ---------------------------------------------------------------------------

ThemeData buildSmoothTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: AppColor.base,
    colorScheme: const ColorScheme.dark(
      surface: AppColor.base,
      surfaceContainer: AppColor.surface,
      surfaceContainerHigh: AppColor.surfaceHigh,
      primary: AppColor.cyan,
      onPrimary: AppColor.void_,
      secondary: AppColor.magenta,
      error: AppColor.danger,
      outline: AppColor.line,
      onSurface: AppColor.ink,
      onSurfaceVariant: AppColor.inkMuted,
    ),
    textTheme: base.textTheme.copyWith(
      displayLarge: AppType.score,
      headlineMedium: AppType.metric,
      titleMedium: AppType.title,
      bodyMedium: AppType.body,
      bodySmall: AppType.caption,
      labelSmall: AppType.label,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColor.base,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppType.label.copyWith(
        color: AppColor.ink,
        fontSize: 14,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColor.line,
      thickness: 1,
      space: 1,
    ),
    cardTheme: CardThemeData(
      color: AppColor.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColor.line, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    // L'azione primaria è l'unico bottone pieno di ciano dello schermo.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColor.cyan,
        foregroundColor: AppColor.void_,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        textStyle: GoogleFonts.rajdhani(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColor.cyan,
        foregroundColor: AppColor.void_,
        elevation: 0,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        textStyle: GoogleFonts.rajdhani(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    ),
    // Tutte le azioni secondarie sono contorni grigi. Mai neon.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColor.ink,
        side: const BorderSide(color: AppColor.line),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColor.surface,
      hintStyle: AppType.body.copyWith(color: AppColor.inkFaint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColor.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColor.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColor.cyan, width: 1.5),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColor.surface,
      selectedItemColor: AppColor.cyan,
      unselectedItemColor: AppColor.inkFaint,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      showUnselectedLabels: true,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColor.surfaceHigh,
      contentTextStyle: AppType.body,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// ESEMPIO DI APPLICAZIONE — la card di un dato
// Da usare come riferimento di densità e gerarchia per tutte le altre.
// ---------------------------------------------------------------------------

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.accent,
  });

  final String label;
  final String value;
  final String? unit;

  /// Passa un accento solo se questo dato è il punto focale della schermata.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final a = accent;
    return AnimatedContainer(
      duration: AppMotion.base,
      curve: AppMotion.curve,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: a == null ? AppGlow.card : AppGlow.edge(a),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppType.label),
          const SizedBox(height: AppSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppType.metric.copyWith(color: a ?? AppColor.ink),
              ),
              if (unit != null) ...[
                const SizedBox(width: AppSpace.xs),
                Text(unit!, style: AppType.caption),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
