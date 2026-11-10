import 'entities/trip.dart';

/// "Che pilota sei" — abbina lo stile di un viaggio a un pilota famoso di
/// film/serie. Logica pura di dominio (nessuna dipendenza Flutter):
/// stesse metriche già mostrate nel report, nessun dato inventato.
///
/// Regole di onestà/sicurezza:
/// - Niente abbinamento se il viaggio è troppo corto o senza telemetria
///   (viaggi precedenti a 0030_persist_trip_motion_stats.sql): meglio
///   nessun personaggio che uno a caso.
/// - La velocità massima non entra mai nel calcolo (come per il punteggio
///   di guida, 0024_drive_score.sql): non si "sblocca" nessun personaggio
///   andando più forte.
/// - I personaggi "sportivi" (Toretto, Han) richiedono una guida comunque
///   pulita: con punteggio basso o un picco G da impatto si finisce su
///   Mr. Bean, non su Toretto. Così la feature non premia la guida
///   pericolosa.
enum DriverArchetype {
  brianOConner(
    name: "Brian O'Conner",
    source: 'Fast & Furious',
    tagline: 'Equilibrato in tutto: niente eccessi, niente punti deboli.',
    monogram: 'BO',
    howToGet:
        'vince quando nessun altro stile emerge con chiarezza: guida equilibrata.',
  ),
  theDriver(
    name: 'Il Driver',
    source: 'Drive',
    tagline: 'Freddo e fluido. Ogni manovra sembra già decisa.',
    monogram: 'D',
    howToGet:
        'punteggio di guida sopra 75, media sostenuta (40–70 km/h) e poche frenate per km.',
  ),
  hokeColburn(
    name: 'Hoke Colburn',
    source: 'A spasso con Daisy',
    tagline:
        'Andatura tranquilla, zero scossoni. I passeggeri si addormentano.',
    monogram: 'HC',
    howToGet: 'punteggio sopra 70, media sotto i 45 km/h e nessuno scossone.',
  ),
  dominicToretto(
    name: 'Dominic Toretto',
    source: 'Fast & Furious',
    tagline: "Partenze brucianti, ma l'auto resta sotto controllo.",
    monogram: 'DT',
    howToGet:
        'accelerazioni decise o uno 0-100 rapido, ma solo con guida pulita (punteggio da 55 in su).',
  ),
  hanLue(
    name: 'Han Lue',
    source: 'Fast & Furious: Tokyo Drift',
    tagline: 'Le curve sono il tuo terreno: entri deciso ed esci pulito.',
    monogram: 'HL',
    howToGet:
        'almeno 4 curve prese decise e pulite: G laterale e velocità in curva alte, mai picchi da impatto.',
  ),
  frankMartin(
    name: 'Frank Martin',
    source: 'The Transporter',
    tagline: 'Veloce quando serve, pulito sempre.',
    monogram: 'FM',
    howToGet:
        'punteggio sopra 70 con accelerazioni decise: veloce quando serve, pulito sempre.',
  ),
  saettaMcQueen(
    name: 'Saetta McQueen',
    source: 'Cars',
    tagline: 'Crociera alta e costante, quasi nessuna sosta.',
    monogram: 'SM',
    howToGet: 'media alta e costante con pochissime soste per km.',
  ),
  baby(
    name: 'Baby',
    source: 'Baby Driver',
    tagline: 'Agile nel traffico: svolte e cambi di corsia a ritmo.',
    monogram: 'B',
    howToGet: 'tante svolte e cambi di corsia per km, a velocità cittadina.',
  ),
  maxRockatansky(
    name: 'Max Rockatansky',
    source: 'Mad Max',
    tagline: 'Strada lunga, salite, niente ti ferma.',
    monogram: 'MR',
    howToGet: 'viaggi lunghi, oltre i 60 km, o con tanto dislivello.',
  ),
  ugoFantozzi(
    name: 'Ugo Fantozzi',
    source: 'Fantozzi',
    tagline: 'Più tempo fermo che in movimento. Il traffico ce l\'ha con te.',
    monogram: 'UF',
    howToGet: 'tanto tempo da fermo e tante soste per km.',
  ),
  mrBean(
    name: 'Mr. Bean',
    source: 'Mr. Bean',
    tagline:
        'Frenate a sorpresa e guida a scatti. Simpatico, ma il punteggio ne soffre.',
    monogram: 'MB',
    howToGet: 'punteggio basso e tante frenate per km.',
  );

  final String name;
  final String source;
  final String tagline;

  /// Sigla nell'emblema esagonale (DT, HL, …).
  final String monogram;

  /// "COME SI OTTIENE" — descrive le regole reali di [archetypeAffinities].
  final String howToGet;
  const DriverArchetype({
    required this.name,
    required this.source,
    required this.tagline,
    required this.monogram,
    required this.howToGet,
  });
}

/// Input normalizzato: si costruisce sia dal [Trip] persistito (storico)
/// sia dalle statistiche live di fine corsa (TripSummaryScreen).
class DrivingStyleInput {
  final double distanceKm;
  final int durationSeconds;
  final double? avgSpeedKmh;
  final int? drivingScore;
  final double? maxAccelerationMs2;
  final double? zeroToHundredSeconds;
  final double peakGForce;
  final double? maxCorneringSpeedKmh;
  final int turns;
  final int laneChanges;
  final int brakingEvents;
  final int totalStops;
  final int stoppedSeconds;
  final double elevationGainM;

  const DrivingStyleInput({
    required this.distanceKm,
    required this.durationSeconds,
    this.avgSpeedKmh,
    this.drivingScore,
    this.maxAccelerationMs2,
    this.zeroToHundredSeconds,
    required this.peakGForce,
    this.maxCorneringSpeedKmh,
    required this.turns,
    required this.laneChanges,
    required this.brakingEvents,
    required this.totalStops,
    required this.stoppedSeconds,
    required this.elevationGainM,
  });

  /// `null` se il viaggio non ha telemetria persistita (viaggi vecchi).
  static DrivingStyleInput? fromTrip(Trip trip) {
    final peakG = trip.peakGForce;
    if (peakG == null || trip.brakingEvents == null) return null;
    return DrivingStyleInput(
      distanceKm: trip.distanceKm,
      durationSeconds: trip.durationSeconds,
      avgSpeedKmh: trip.avgSpeedKmh,
      drivingScore: trip.drivingScore,
      maxAccelerationMs2: trip.maxAccelerationMs2,
      zeroToHundredSeconds: trip.zeroToHundredSeconds,
      peakGForce: peakG,
      maxCorneringSpeedKmh: trip.maxCorneringSpeedKmh,
      turns: (trip.turnsLeft ?? 0) + (trip.turnsRight ?? 0),
      laneChanges: trip.laneChanges ?? 0,
      brakingEvents: trip.brakingEvents ?? 0,
      totalStops: trip.totalStops ?? 0,
      stoppedSeconds: trip.stoppedSeconds ?? 0,
      elevationGainM: trip.elevationGainM ?? 0,
    );
  }
}

class DriverArchetypeMatch {
  final DriverArchetype archetype;

  /// 1-2 motivi leggibili, presi dai dati reali del viaggio
  /// (es. "0-100 in 7.8 s") — così l'utente vede perché.
  final List<String> reasons;

  /// Affinità 0..1 con ogni pilota candidato, ordinate dalla più alta
  /// (il primo è [archetype]). Le prime tre vanno nelle barre "AFFINITÀ".
  final List<MapEntry<DriverArchetype, double>> affinities;
  const DriverArchetypeMatch(this.archetype, this.reasons,
      [this.affinities = const []]);
}

/// Sotto queste soglie il viaggio non dice abbastanza sullo stile.
const double kArchetypeMinDistanceKm = 2.0;
const int kArchetypeMinDurationSeconds = 300;

/// Punteggio fisso del jolly "equilibrato": vince solo se nessun altro
/// profilo emerge con chiarezza.
const double _fallbackScore = 0.35;

/// Rampa lineare 0→1 fra [lo] e [hi], limitata agli estremi.
double _ramp(double x, double lo, double hi) {
  if (x <= lo) return 0;
  if (x >= hi) return 1;
  return (x - lo) / (hi - lo);
}

double _inv(double x, double lo, double hi) => 1 - _ramp(x, lo, hi);

String _f1(double v) => v.toStringAsFixed(1);

DriverArchetypeMatch? matchDriverArchetype(DrivingStyleInput i) {
  final candidates = archetypeAffinities(i);
  if (candidates == null) return null;

  // Il primo in ordine di dichiarazione vince a parità: deterministico.
  var best = DriverArchetype.brianOConner;
  var bestScore = _fallbackScore;
  for (final a in DriverArchetype.values) {
    final s = candidates[a];
    if (s != null && s > bestScore) {
      best = a;
      bestScore = s;
    }
  }

  final ranked = [
    for (final a in DriverArchetype.values)
      if (candidates[a] != null) MapEntry(a, candidates[a]!),
  ]..sort((x, y) {
      if (x.key == best) return -1;
      if (y.key == best) return 1;
      return y.value.compareTo(x.value);
    });

  final avg = i.avgSpeedKmh ?? (i.distanceKm / (i.durationSeconds / 3600));
  return DriverArchetypeMatch(best, _reasons(best, i, avg), ranked);
}

/// Affinità 0..1 dello stile del viaggio con ogni pilota. I profili
/// sportivi mancano del tutto se la guida non è pulita. `null` se il
/// viaggio è troppo corto per dire qualcosa.
Map<DriverArchetype, double>? archetypeAffinities(DrivingStyleInput i) {
  if (i.distanceKm < kArchetypeMinDistanceKm ||
      i.durationSeconds < kArchetypeMinDurationSeconds) {
    return null;
  }

  final km = i.distanceKm;
  final avg = i.avgSpeedKmh ?? (km / (i.durationSeconds / 3600));
  final score = i.drivingScore;
  final accel = i.maxAccelerationMs2 ?? 0;
  final z100 = i.zeroToHundredSeconds;
  final turnsPerKm = i.turns / km;
  final lanePerKm = i.laneChanges / km;
  final brakesPerKm = i.brakingEvents / km;
  final stopsPerKm = i.totalStops / km;
  final stoppedRatio = i.stoppedSeconds / i.durationSeconds;
  final elevPerKm = i.elevationGainM / km;

  // Gate di sicurezza per i profili sportivi: guida pulita obbligatoria.
  final cleanEnough =
      i.peakGForce < 1.0 && (score == null ? i.peakGForce < 0.8 : score >= 55);

  final candidates = <DriverArchetype, double>{
    DriverArchetype.brianOConner: _fallbackScore,
    if (cleanEnough)
      DriverArchetype.dominicToretto: [
        _ramp(accel, 3.0, 6.0),
        if (z100 != null) _ramp(14 - z100, 0, 7),
      ].reduce((a, b) => a > b ? a : b),
    if (cleanEnough && i.turns >= 4)
      DriverArchetype.hanLue: 0.5 * _ramp(i.peakGForce, 0.35, 0.7) +
          0.5 * _ramp(i.maxCorneringSpeedKmh ?? 0, 30, 60),
    if (cleanEnough && score != null)
      DriverArchetype.frankMartin:
          _ramp(score.toDouble(), 70, 90) * _ramp(accel, 2.5, 4.5),
    if (score != null)
      DriverArchetype.theDriver: _ramp(score.toDouble(), 75, 95) *
          _ramp(avg, 40, 70) *
          _inv(brakesPerKm, 1, 3),
    if (score != null)
      DriverArchetype.hokeColburn: _ramp(score.toDouble(), 70, 90) *
          _inv(avg, 30, 45) *
          _inv(i.peakGForce, 0.25, 0.45),
    DriverArchetype.saettaMcQueen:
        _ramp(avg, 60, 95) * _inv(stopsPerKm, 0.1, 0.5),
    DriverArchetype.baby:
        (0.5 * _ramp(turnsPerKm, 2, 5) + 0.5 * _ramp(lanePerKm, 0.5, 2)) *
            _inv(avg, 55, 75),
    DriverArchetype.maxRockatansky: [
      _ramp(km, 60, 150),
      _ramp(elevPerKm, 15, 40),
    ].reduce((a, b) => a > b ? a : b),
    DriverArchetype.ugoFantozzi: 0.6 * _ramp(stoppedRatio, 0.15, 0.4) +
        0.4 * _ramp(stopsPerKm, 0.8, 2.5),
    DriverArchetype.mrBean: score != null
        ? 0.6 * _inv(score.toDouble(), 35, 55) + 0.4 * _ramp(brakesPerKm, 2, 5)
        : _ramp(brakesPerKm, 2.5, 6),
  };

  return candidates;
}

List<String> _reasons(DriverArchetype a, DrivingStyleInput i, double avg) {
  final km = i.distanceKm;
  final scoreText =
      i.drivingScore != null ? 'Punteggio ${i.drivingScore}/100' : null;
  final stoppedMin = (i.stoppedSeconds / 60).round();
  return switch (a) {
    DriverArchetype.brianOConner => [
        if (scoreText != null) scoreText,
        'Media ${avg.round()} km/h',
      ],
    DriverArchetype.theDriver => [
        if (scoreText != null) scoreText,
        '${_f1(i.brakingEvents / km)} frenate/km',
      ],
    DriverArchetype.hokeColburn => [
        if (scoreText != null) scoreText,
        'Media ${avg.round()} km/h',
      ],
    DriverArchetype.dominicToretto => [
        if (i.zeroToHundredSeconds != null)
          '0-100 in ${_f1(i.zeroToHundredSeconds!)} s',
        if (i.maxAccelerationMs2 != null)
          'Accelerazione ${_f1(i.maxAccelerationMs2!)} m/s²',
      ],
    DriverArchetype.hanLue => [
        'Picco ${i.peakGForce.toStringAsFixed(2)} G',
        if (i.maxCorneringSpeedKmh != null)
          '${i.maxCorneringSpeedKmh!.round()} km/h in curva',
      ],
    DriverArchetype.frankMartin => [
        if (scoreText != null) scoreText,
        if (i.maxAccelerationMs2 != null)
          'Accelerazione ${_f1(i.maxAccelerationMs2!)} m/s²',
      ],
    DriverArchetype.saettaMcQueen => [
        'Media ${avg.round()} km/h',
        '${i.totalStops} soste',
      ],
    DriverArchetype.baby => [
        '${i.turns} svolte',
        '${i.laneChanges} cambi di corsia',
      ],
    DriverArchetype.maxRockatansky => [
        '${km.toStringAsFixed(0)} km',
        '${i.elevationGainM.round()} m di dislivello',
      ],
    DriverArchetype.ugoFantozzi => [
        '$stoppedMin min da fermo',
        '${i.totalStops} soste',
      ],
    DriverArchetype.mrBean => [
        if (scoreText != null) scoreText,
        '${i.brakingEvents} frenate',
      ],
  };
}

// ---------------------------------------------------------------------------
// STORICO — "il tuo pilota" è quello uscito più spesso negli ultimi 10
// viaggi abbinati. Sotto i 10 è "in analisi"; a pari merito "testa a testa".
// ---------------------------------------------------------------------------

/// Viaggi abbinati necessari per ogni stella di maestria (1→5).
const kMasteryThresholds = [1, 3, 6, 10, 15];
const kPilotWindow = 10;

/// Stelle di maestria 0..5 dato il numero di viaggi abbinati a un pilota.
int masteryLevel(int matchedTrips) =>
    kMasteryThresholds.where((t) => matchedTrips >= t).length;

class PilotHistory {
  /// Ultimi (al massimo) 10 abbinamenti, dal più recente.
  final List<DriverArchetype> lastTen;

  /// Conteggi dentro [lastTen].
  final Map<DriverArchetype, int> tally;

  /// Conteggi su tutto lo storico (maestria, collezione).
  final Map<DriverArchetype, int> totals;

  /// Pilota più frequente in [lastTen]; `null` senza viaggi abbinati.
  final DriverArchetype? main;

  /// Secondo pilota a pari merito con [main], se c'è.
  final DriverArchetype? tiedWith;

  const PilotHistory({
    required this.lastTen,
    required this.tally,
    required this.totals,
    required this.main,
    required this.tiedWith,
  });

  /// Con meno di 10 viaggi il pilota è solo provvisorio.
  bool get ready => lastTen.length >= kPilotWindow;
  bool get isTie => tiedWith != null;
  bool seen(DriverArchetype a) => (totals[a] ?? 0) > 0;
  int get collected => totals.length;
  int mastery(DriverArchetype a) => masteryLevel(totals[a] ?? 0);
}

/// [newestFirst]: un abbinamento per viaggio, dal più recente. A parità di
/// conteggio vince chi è uscito più di recente (deterministico).
PilotHistory buildPilotHistory(List<DriverArchetype> newestFirst) {
  final lastTen = newestFirst.take(kPilotWindow).toList();
  final tally = <DriverArchetype, int>{};
  for (final a in lastTen) {
    tally[a] = (tally[a] ?? 0) + 1;
  }
  final totals = <DriverArchetype, int>{};
  for (final a in newestFirst) {
    totals[a] = (totals[a] ?? 0) + 1;
  }
  final order = tally.keys.toList()
    ..sort((x, y) {
      final c = tally[y]!.compareTo(tally[x]!);
      return c != 0 ? c : lastTen.indexOf(x).compareTo(lastTen.indexOf(y));
    });
  final main = order.isEmpty ? null : order.first;
  final tied =
      order.length > 1 && tally[order[1]] == tally[main] ? order[1] : null;
  return PilotHistory(
    lastTen: lastTen,
    tally: tally,
    totals: totals,
    main: main,
    tiedWith: tied,
  );
}

/// Abbinamenti dello storico viaggi (dal più recente), saltando quelli
/// senza telemetria o troppo corti.
List<DriverArchetype> archetypesOf(Iterable<Trip> tripsNewestFirst) => [
      for (final t in tripsNewestFirst)
        if (DrivingStyleInput.fromTrip(t) case final i?)
          if (matchDriverArchetype(i) case final m?) m.archetype,
    ];
