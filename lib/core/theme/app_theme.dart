// HEAT — design system
// Street racing notturno, sobrio: fondo inchiostro, un solo accento neon,
// pannelli inclinati/smussati, display condensato corsivo, accenti graffiti.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

// ---------------------------------------------------------------------------
// TIPOGRAFIA
// ---------------------------------------------------------------------------
//   display  Barlow Condensed 800/900 corsivo, MAIUSCOLO: titoli, numeri, label
//   body     Inter 400–700: tutto il testo corrente
//   graffiti Sedgwick Ave Display: voti S/A/B/C, "heat", frasi-firma (ruotato)
// I numeri corsivi grandi vogliono 4–14px di padding a destra, altrimenti
// l'inclinazione viene tagliata.

abstract final class AppType {
  static TextStyle _barlow({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w800,
    double? height,
    double? letterSpacing,
    Color color = AppColor.ink,
    bool italic = true,
    List<Shadow>? shadows,
  }) =>
      GoogleFonts.barlowCondensed(
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
        shadows: shadows,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Numero protagonista (FLOW, velocità): 104–132px.
  static TextStyle get score =>
      _barlow(fontSize: 112, height: 0.85, fontWeight: FontWeight.w900);

  /// Titolo di schermata (GUIDA, SPOTTING…): 48–50px.
  static TextStyle get screenTitle =>
      _barlow(fontSize: 50, height: 0.85, fontWeight: FontWeight.w900);

  static TextStyle get metric => _barlow(fontSize: 30, height: 1.0);

  /// Etichette di sezione: maiuscole, spaziate, mute.
  static TextStyle get label => _barlow(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: AppColor.inkMuted,
        italic: false,
      );

  static TextStyle get title => _barlow(fontSize: 20, height: 1.0);

  static TextStyle get body =>
      GoogleFonts.inter(fontSize: 14, height: 1.4, color: AppColor.ink);

  static TextStyle get caption =>
      GoogleFonts.inter(fontSize: 12, height: 1.4, color: AppColor.inkMuted);

  /// Accento graffiti — usalo ruotato di −4°/−8° (vedi `GraffitiText`).
  static TextStyle graffiti({double fontSize = 28, Color? color}) =>
      GoogleFonts.sedgwickAveDisplay(
        fontSize: fontSize,
        height: 1.0,
        color: color ?? AppColor.accent,
      );

  /// Accenti giapponesi dell'intro.
  static TextStyle jp({double fontSize = 14, Color color = AppColor.ink}) =>
      GoogleFonts.notoSansJp(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color,
      );

  /// Display con dimensioni/pesi custom (Barlow Condensed corsivo).
  static TextStyle display({
    FontWeight fontWeight = FontWeight.w800,
    double? fontSize,
    Color color = AppColor.ink,
    double? letterSpacing,
    double? height,
    bool italic = true,
    List<Shadow>? shadows,
  }) =>
      _barlow(
        fontWeight: fontWeight,
        fontSize: fontSize,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        italic: italic,
        shadows: shadows,
      );

  /// Testo Inter con dimensioni/pesi custom.
  static TextStyle text({
    FontWeight fontWeight = FontWeight.w400,
    double? fontSize,
    Color color = AppColor.ink,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
  }) =>
      GoogleFonts.inter(
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
  // HEAT usa forme inclinate/smussate (heat_shapes.dart); i raggi restano
  // minimi per ciò che non è ancora tagliato.
  static const card = 4.0;
  static const control = 3.0;
  static const pill = 999.0;
}

// ---------------------------------------------------------------------------
// GLOW
// ---------------------------------------------------------------------------
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
  }) =>
      BoxDecoration(
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
  static const sheet = Duration(milliseconds: 240); // bottom sheet
  static const enter = Duration(milliseconds: 380); // ingresso schermata
  static const title = Duration(milliseconds: 500); // titolo che scivola
  static const reveal = Duration(milliseconds: 620); // conteggio punteggio
  static const stagger = Duration(milliseconds: 50); // ritardo tra item
  static const toast = Duration(milliseconds: 2400);
  static const curve = Curves.easeOutCubic;

  /// cubic-bezier(.2,.8,.2,1) del prototipo per gli ingressi.
  static const enterCurve = Cubic(0.2, 0.8, 0.2, 1);
}

// ---------------------------------------------------------------------------
// THEME
// ---------------------------------------------------------------------------

ThemeData buildHeatTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: AppColor.base,
    colorScheme: ColorScheme.dark(
      surface: AppColor.base,
      surfaceContainer: AppColor.surface,
      surfaceContainerHigh: AppColor.surfaceHigh,
      primary: AppColor.accent,
      onPrimary: AppColor.onAccent,
      secondary: AppColor.night,
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
    // L'azione primaria è l'unico bottone pieno d'accento dello schermo.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColor.accent,
        foregroundColor: AppColor.onAccent,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        textStyle: AppType.display(fontSize: 18, fontWeight: FontWeight.w900),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColor.accent,
        foregroundColor: AppColor.onAccent,
        elevation: 0,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        textStyle: AppType.display(fontSize: 18, fontWeight: FontWeight.w900),
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
        borderSide: BorderSide(color: AppColor.accent, width: 1.5),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColor.surface,
      selectedItemColor: AppColor.accent,
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
