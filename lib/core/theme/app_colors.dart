import 'package:flutter/material.dart';

/// SMOOTH — token di colore. Fonte unica per ogni colore usato nei widget.
/// Il nero non è mai #000000: vira al blu, così le superfici hanno profondità.
/// I due accenti hanno significati fissi e non intercambiabili:
///   ciano   = tuo, pulito, conquistato
///   magenta = perso, sporco, in scadenza
/// Non usarli mai per decorare. Se non significa niente, è grigio.
abstract final class AppColor {
  // Fondali, dal più profondo al più vicino
  static const void_ = Color(0xFF07080B); // sfondo mappa e schermate immersive
  static const base = Color(0xFF0A0B0F); // scaffold
  static const surface = Color(0xFF12141A); // card
  static const surfaceHigh = Color(0xFF1A1D26); // card sollevata, sheet
  static const line = Color(0xFF252A35); // bordi, divisori

  // Testo
  static const ink = Color(0xFFE8EAF0);
  static const inkMuted = Color(0xFF8A92A6);
  static const inkFaint = Color(0xFF4C5364);

  // Accenti semantici
  static const cyan = Color(0xFF00E5FF); // possesso, guida pulita, attivo
  static const magenta = Color(0xFFFF2D95); // perdita, strappo, decadimento
  static const amber = Color(0xFFFFB020); // scadenza imminente, wanted list

  // ---------------------------------------------------------------------
  // Alias semantici — leggibilità ai call site che ragionano in termini di
  // stato (errore/successo/avviso) invece che di colore. Nessun nuovo
  // significato: puntano sempre a uno dei tre accenti fissi sopra.
  static const danger = magenta;
  static const success = cyan;
  static const warning = amber;

  // ---------------------------------------------------------------------
  // Rampa rarità (Achievement, Car Spotting) — il grigio che si accende via
  // via che la rarità sale, fino all'ambra con glow per la fascia più alta.
  // Niente palette arcobaleno: resta dentro il vocabolario dei tre accenti.
  static const rarityCommon = inkFaint;
  static const rarityUncommon = inkMuted;
  static const rarityRare = Color(0xFF4FA8B8); // ciano smorzato
  static const rarityEpic = Color(0xFFB84F94); // magenta smorzato
  static const rarityLegendary = amber; // pieno, prende il glow (AppGlow.edge)
}

/// Palette identità delle mascotte-rivali — **non semantica**: distingue i
/// personaggi, non comunica stato. Non riusare questi colori per possesso,
/// perdita o scadenza: quel vocabolario resta di [AppColor.cyan]/[magenta]/
/// [amber].
abstract final class AppMascot {
  static const nitro = Color(0xFF2F6BFF);
  static const r3x = Color(0xFFFF3B5C);
  static const volt = Color(0xFF8B5CF6);
  static const spark = AppColor.magenta;
  static const dust = AppColor.amber;
}
