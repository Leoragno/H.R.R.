import 'package:flutter/material.dart';

/// HEAT — token di colore. Fonte unica per ogni colore usato nei widget.
///
/// Notte da street racing: fondo inchiostro che vira al viola, **un solo**
/// accento neon (scelto dall'utente, default Corallo) e pochi colori
/// semantici a significato fisso. Se un colore non significa niente, è grigio.
abstract final class AppColor {
  // Fondali, dal più profondo al più vicino
  static const void_ = Color(0xFF06050A); // live, intro, schermate immersive
  static const base = Color(0xFF0B0912); // scaffold
  static const deep = Color(0xFF100E16); // incavi, track delle barre
  static const surface = Color(0xFF14121C); // pannelli
  static const surfaceHigh = Color(0xFF1C1926); // pannello sollevato, sheet
  static const line = Color(0xFF2C2838); // bordi, divisori
  static const lineMuted = Color(0xFF3A3550); // bordi su superfici sollevate

  // Testo
  static const ink = Color(0xFFF4F1FA);
  static const inkMuted = Color(0xFFA69CC0);
  static const inkFaint = Color(0xFF6A6187);

  // ---------------------------------------------------------------------
  // Accento — l'unico neon dell'app. È scelto dall'utente (Impostazioni),
  // quindi non è `const`: [setAccent] lo cambia e la radice dell'app si
  // ricostruisce (vedi `accentProvider`).
  static Color _accent = HeatAccent.corallo.color;
  static Color get accent => _accent;
  static void setAccent(Color c) => _accent = c;

  /// Testo/icone sopra un riempimento d'accento.
  static const onAccent = Color(0xFF0B0912);

  // Accento secondario del ciclo giorno/notte (toggle NOTTE/GIORNO, HEAT).
  static const night = Color(0xFF8A3DFF);
  static const day = Color(0xFFFF8A1F);

  // Semantici — significato fisso, mai decorativi.
  static const gold = Color(0xFFFFB020); // XP, avvisi, scade presto
  static const danger = Color(0xFFFF3B5C); // errore, rivale, perso
  static const info = Color(0xFF22E4FF); // velocità, informazione
  static const success = Color(0xFF3BE08A); // online, completato

  /// Alias storici: il vecchio "ambra" è l'oro semantico; il vecchio
  /// "magenta" (perso/strappo) è il rosso rivale.
  static const amber = gold;
  static const magenta = danger;
  static const warning = gold;

  // Rampa rarità (Achievement, Car Spotting, piloti).
  static const rarityCommon = inkFaint;
  static const rarityUncommon = inkMuted;
  static const rarityRare = Color(0xFF4FA8B8);
  static const rarityEpic = Color(0xFFB84F94);
  static const rarityLegendary = gold;
}

/// Accenti selezionabili. I primi quattro sono sempre disponibili; gli
/// altri si sbloccano con le ricompense "colore neon" del pass.
enum HeatAccent {
  corallo('Corallo', Color(0xFFFF2E6A)),
  turchese('Turchese', Color(0xFF22E4FF)),
  giallo('Giallo', Color(0xFFFFC93C)),
  viola('Viola', Color(0xFFC23DFF)),
  lime('Lime', Color(0xFFB6FF3B), locked: true),
  arancio('Arancio', Color(0xFFFF7A1F), locked: true),
  ghiaccio('Ghiaccio', Color(0xFF9FE8FF), locked: true);

  const HeatAccent(this.label, this.color, {this.locked = false});
  final String label;
  final Color color;

  /// Sbloccabile solo dal pass di guida.
  final bool locked;

  static HeatAccent byName(String? name) => HeatAccent.values.firstWhere(
        (a) => a.name == name,
        orElse: () => HeatAccent.corallo,
      );
}

/// Palette identità delle mascotte — **non semantica**: distingue i
/// personaggi, non comunica stato.
abstract final class AppMascot {
  static const nitro = Color(0xFF3B7BFF);
  static const r3x = Color(0xFFFF3B5C);
  static const volt = Color(0xFF8B5CF6);
  static const spark = Color(0xFFFF2E88);
  static const dust = Color(0xFFFFB020);
}
