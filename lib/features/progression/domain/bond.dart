/// Legame con la mascotte (0041, tabella mascot_bond): ogni guida aggiunge
/// il 10% dei suoi XP alla mascotte attiva; il legame di ogni mascotte
/// resta quando si cambia. Soglie uguali a `bond_level` lato server.
const kBondThresholds = [0, 60, 160, 320, 540, 820, 1180, 1620, 2160, 2800];

/// Sblocchi per livello (handoff: LV2 esultanza, LV3 radio, LV5 skin neon,
/// LV7 scia, LV10 titolo).
const kBondUnlocks = <int, String>{
  2: 'emote esultanza',
  3: 'frasi nuove in radio',
  5: 'skin neon',
  7: 'scia colorata sulla mappa',
  10: 'titolo leggenda',
};

int bondLevel(int points) =>
    kBondThresholds.where((t) => t <= (points < 0 ? 0 : points)).length;

class BondProgress {
  const BondProgress(this.points);
  final int points;

  int get level => bondLevel(points);
  bool get maxed => level >= kBondThresholds.length;

  /// Punti mancanti al livello successivo (0 se massimo).
  int get toNext => maxed ? 0 : kBondThresholds[level] - points;

  double get fraction {
    if (maxed) return 1;
    final from = kBondThresholds[level - 1];
    final to = kBondThresholds[level];
    return ((points - from) / (to - from)).clamp(0.0, 1.0);
  }

  /// Bonus mascotte: +5% per livello sopra il primo.
  int get bonusPercent => (level - 1) * 5;

  /// Prossimo sblocco, es. (5, 'skin neon'); null se tutto sbloccato.
  (int, String)? get nextUnlock {
    for (final e in kBondUnlocks.entries) {
      if (e.key > level) return (e.key, e.value);
    }
    return null;
  }

  bool unlocked(int lv) => level >= lv;
}
