/// Regole di progressione HEAT (handoff "HRR · Heat", sezione "Update ·
/// tutorial, XP, piloti, mascotte"). Logica pura, nessuna dipendenza
/// Flutter: la usano Home, Risultato e Profilo, e la migration
/// 0037_heat_levels.sql replica la stessa curva lato server.
library;

import 'dart:math' as math;

/// XP necessari per passare dal livello [level] al successivo.
int xpNeededForLevel(int level) => 1500 + 150 * level;

class LevelProgress {
  final int level;

  /// XP accumulati dentro il livello corrente.
  final int xpInLevel;

  /// XP necessari per chiudere il livello corrente.
  final int xpNeeded;

  const LevelProgress(this.level, this.xpInLevel, this.xpNeeded);

  double get fraction => xpNeeded == 0 ? 0 : xpInLevel / xpNeeded;
  String get title => levelTitle(level);
}

/// Il profilo salva gli XP **totali**: qui si scompongono in livello +
/// avanzamento dentro il livello.
LevelProgress levelProgressFromTotalXp(int totalXp) {
  var level = 1;
  var rest = math.max(0, totalXp);
  while (rest >= xpNeededForLevel(level)) {
    rest -= xpNeededForLevel(level);
    level++;
  }
  return LevelProgress(level, rest, xpNeededForLevel(level));
}

String levelTitle(int level) {
  if (level < 5) return 'ROOKIE';
  if (level < 10) return 'STREET';
  if (level < 20) return 'PRO';
  if (level < 30) return 'ELITE';
  if (level < 45) return 'LEGGENDA';
  return 'MITO';
}

// ---------------------------------------------------------------------------
// NOTTE / HEAT
// ---------------------------------------------------------------------------

/// Guida notturna: partenza dalle 22:00 alle 05:59 (ora locale).
bool isNightTime(DateTime t) => t.hour >= 22 || t.hour < 6;

const int kHeatMin = 1;
const int kHeatMax = 5;

/// HEAT corrente ricostruito dallo storico: parte da 1, ogni guida notturna
/// +1, ogni guida diurna −1 (VOLT: ±2), sempre fra 1 e 5.
/// [startsOldestFirst] = orari di partenza in ordine cronologico.
int heatFromTripStarts(Iterable<DateTime> startsOldestFirst,
    {bool volt = false}) {
  final step = volt ? 2 : 1;
  var heat = kHeatMin;
  for (final s in startsOldestFirst) {
    heat = (isNightTime(s) ? heat + step : heat - step)
        .clamp(kHeatMin, kHeatMax);
  }
  return heat;
}

/// Moltiplicatore XP delle guide notturne.
double heatMultiplier(int heat) => 1 + (heat - 1) * 0.25;

// ---------------------------------------------------------------------------
// SERIE DI GIORNI
// ---------------------------------------------------------------------------

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// Giorni consecutivi con almeno una guida, fino a oggi o ieri (se l'ultima
/// guida è di ieri la serie è ancora salvabile). 0 se la serie è rotta.
int streakDays(Iterable<DateTime> tripStarts, DateTime now) {
  final days = tripStarts.map(_day).toSet();
  if (days.isEmpty) return 0;
  final today = _day(now);
  var cursor = days.contains(today)
      ? today
      : today.subtract(const Duration(days: 1));
  var count = 0;
  while (days.contains(cursor)) {
    count++;
    // DateTime(...) con day-1 gestisce mesi e cambi d'ora meglio di
    // subtract(24h).
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return count;
}

/// Bonus XP della serie: 10 al giorno, massimo 70.
int streakBonusXp(int streak) => math.min(70, streak * 10);

// ---------------------------------------------------------------------------
// FLOW
// ---------------------------------------------------------------------------

/// Voto graffiti del Risultato.
String flowGrade(int flow) {
  if (flow >= 85) return 'S';
  if (flow >= 75) return 'A';
  if (flow >= 65) return 'B';
  return 'C';
}
