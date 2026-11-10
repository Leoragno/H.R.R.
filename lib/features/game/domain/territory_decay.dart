import 'entities/territory_cell.dart';

/// Giorni dopo cui una cella non ripassata decade. Allineato a
/// territory_decay_days() in 0026_territory_decay_counterattack.sql: qui
/// serve solo per la UI, la scadenza reale la decide il server.
const kTerritoryDecayDays = 14;

/// R3X: i suoi territori decadono un giorno prima (0041, territory_decay_days(owner)).
int territoryDecayDaysForMascot(String? mascotId) =>
    mascotId == 'r3x' ? kTerritoryDecayDays - 1 : kTerritoryDecayDays;

/// Sotto questa soglia la cella è "a rischio" (sbiadisce sulla mappa).
const kTerritoryWarningDays = 3;

/// Giorni (frazionari) che restano prima del decadimento; può essere < 0.
double territoryDaysLeft(TerritoryCell cell,
        [DateTime? now, int decayDays = kTerritoryDecayDays]) =>
    decayDays - (now ?? DateTime.now()).difference(cell.claimedAt).inHours / 24;

/// "OGGI" / "1 GIORNO" / "5 GIORNI".
String territoryDaysLabel(double daysLeft) {
  if (daysLeft < 1) return 'OGGI';
  final d = daysLeft.floor();
  return d == 1 ? '1 GIORNO' : '$d GIORNI';
}
