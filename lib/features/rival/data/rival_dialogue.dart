import '../domain/entities/rival_popup.dart';

/// Frasi per (mascotId, mood). Contenuto pieno per NITRO (mascotte di
/// default, vedi active_mascot_provider.dart); pool più corto per le
/// altre — sufficiente a dimostrare che il sistema è davvero data-driven,
/// da espandere quando arriverà la selezione mascotte (fase 2).
final Map<String, Map<RivalMood, List<String>>> _pools = {
  'nitro': {
    RivalMood.greeting: [
      'Bentornato. Oggi si corre.',
      'Eccoti. Pensavo avessi mollato.',
      'Gas o niente, ricordi?',
      'Si riparte. Battimi, se ci riesci.',
    ],
    RivalMood.missionCelebration: [
      'Missione chiusa. Non male.',
      'Visto? Con me al fianco si vince.',
      'Bel colpo. Il prossimo?',
      'Missione portata a casa. Avanti così.',
    ],
    RivalMood.personalRecordHype: [
      'Record polverizzato! 🔥',
      'Chi ti ferma, oggi?',
      'Velocità così non le avevo mai viste da te.',
      'Nuovo record. Io me lo segno.',
    ],
    RivalMood.streakEncouraging: [
      'Streak in piedi. Continua così.',
      'Ogni giorno un passo avanti. Bravo.',
      'Costanza. È così che si vince.',
    ],
    RivalMood.streakUrgent: [
      'Appena in tempo. La streak è salva.',
      'Per un pelo. La prossima volta arriva prima.',
    ],
    RivalMood.streakLost: [
      'Streak persa. Si riparte da uno.',
      'Un giorno saltato, tutto azzerato. Peccato.',
    ],
    RivalMood.inactivityTaunt: [
      'Tutto fermo da un po\'. Mi manchi in strada.',
      'Il volante non si gira da solo, sai?',
      'Oggi zero. Domani rimedi?',
    ],
  },
  'r3x': {
    RivalMood.greeting: ['Ti vedo negli specchietti...'],
    RivalMood.missionCelebration: ['Easy. Tutto qui?'],
    RivalMood.personalRecordHype: ['Ok, quello mi ha sorpreso.'],
    RivalMood.streakEncouraging: ['Non male, per uno come te.'],
    RivalMood.streakUrgent: ['Salvato per un soffio. Fortuna.'],
    RivalMood.streakLost: ['Prevedibile.'],
    RivalMood.inactivityTaunt: ['Fermo? Comodo restare indietro.'],
  },
  'volt': {
    RivalMood.greeting: ['I numeri parlano.'],
    RivalMood.missionCelebration: ['Calcolato. Come previsto.'],
    RivalMood.personalRecordHype: ['Dato interessante.'],
    RivalMood.streakEncouraging: ['Costanza misurabile. Bene.'],
    RivalMood.streakUrgent: ['Margine minimo. Nota bene.'],
    RivalMood.streakLost: ['Sequenza interrotta.'],
    RivalMood.inactivityTaunt: ['Nessun dato oggi. Silenzio.'],
  },
  'spark': {
    RivalMood.greeting: ['Divertiti, ma perdi.'],
    RivalMood.missionCelebration: ['Slay! 💖'],
    RivalMood.personalRecordHype: ['Queen move!'],
    RivalMood.streakEncouraging: ['Serie che spacca!'],
    RivalMood.streakUrgent: ['Salvata sul filo, drama queen.'],
    RivalMood.streakLost: ['Oops...'],
    RivalMood.inactivityTaunt: ['Dove sei finito/a? Mi annoio.'],
  },
  'dust': {
    RivalMood.greeting: ['Quack. Sorpassato.'],
    RivalMood.missionCelebration: ['Ricco! 💰'],
    RivalMood.personalRecordHype: ['Quack?! Non me lo aspettavo.'],
    RivalMood.streakEncouraging: ['Streak solida. Rispetto.'],
    RivalMood.streakUrgent: ['Salva all\'ultimo. RIP quasi.'],
    RivalMood.streakLost: ['RIP streak. 💀'],
    RivalMood.inactivityTaunt: ['Zzz... anche tu, a quanto pare.'],
  },
};

const _genericFallback = <RivalMood, String>{
  RivalMood.greeting: 'Bentornato in strada.',
  RivalMood.missionCelebration: 'Missione completata. Ben fatto.',
  RivalMood.personalRecordHype: 'Nuovo record personale!',
  RivalMood.streakEncouraging: 'Streak in piedi. Continua così.',
  RivalMood.streakUrgent: 'Streak salvata per un soffio.',
  RivalMood.streakLost: 'Streak persa. Si riparte.',
  RivalMood.inactivityTaunt: 'Ti aspettiamo in strada.',
};

/// Frasi in più sbloccate dal legame LV3 ("frasi nuove in radio"): più
/// confidenziali, la mascotte ti conosce.
final Map<String, Map<RivalMood, List<String>>> _bondPools = {
  'nitro': {
    RivalMood.greeting: [
      'Socio. Il motore è caldo, manchi solo tu.',
      'Ormai ti riconosco dal rumore delle frenate. Poche, bravo.',
    ],
    RivalMood.missionCelebration: [
      'Noi due insieme siamo un problema per tutti.'
    ],
    RivalMood.personalRecordHype: [
      'Questo lo racconto ai box per una settimana.'
    ],
    RivalMood.inactivityTaunt: ['Il casco ti aspetta. Anche io, un po\'.'],
  },
  'r3x': {
    RivalMood.greeting: [
      'Ammettilo: senza di me ti annoieresti.',
      'Oggi rubiamo qualche esagono? Dai che lo vuoi.',
    ],
    RivalMood.missionCelebration: ['Ok, questa te la riconosco. Solo questa.'],
    RivalMood.personalRecordHype: ['Mi stai quasi facendo paura. Quasi.'],
    RivalMood.inactivityTaunt: ['I tuoi esagoni piangono. Io rido.'],
  },
  'volt': {
    RivalMood.greeting: [
      'La notte è nostra. I dati lo confermano.',
      'Varianza in calo da quando guidiamo insieme. Interessante.',
    ],
    RivalMood.missionCelebration: ['Previsto. Ma comunque piacevole.'],
    RivalMood.personalRecordHype: ['Fuori scala. Devo ricalibrare.'],
    RivalMood.inactivityTaunt: ['Zero campioni da giorni. Inaccettabile.'],
  },
  'spark': {
    RivalMood.greeting: [
      'Eccoci! Oggi foto, curve e caos. Nell\'ordine che vuoi.',
      'Ho già pronto il filtro per il tuo prossimo spot.',
    ],
    RivalMood.missionCelebration: ['Questa la condivido con TUTTI.'],
    RivalMood.personalRecordHype: [
      'Ma sei serio?! Fammi un video la prossima.'
    ],
    RivalMood.inactivityTaunt: ['Il feed è noioso senza di te.'],
  },
  'dust': {
    RivalMood.greeting: [
      'Quack. Ancora qui, ancora noi. Non si molla.',
      'Un giorno alla volta. Lo sai come la penso.',
    ],
    RivalMood.missionCelebration: ['Testardi si nasce. Noi lo siamo.'],
    RivalMood.personalRecordHype: ['QUACK. Ok, mi hai stupito.'],
    RivalMood.inactivityTaunt: ['La serie non si allunga da sola. Quack.'],
  },
};

/// Non lancia mai per un (mascotId, mood) senza contenuto dedicato: prova
/// prima il pool specifico, poi [_genericFallback] — stesso principio di
/// `notification_presentation.dart` (mai un'eccezione per un caso non
/// ancora mappato). Con [bonded] (legame LV3) si aggiungono le frasi del
/// legame.
List<String> phrasesFor(String mascotId, RivalMood mood,
    {bool bonded = false}) {
  final pool = _pools[mascotId]?[mood];
  final base = pool != null && pool.isNotEmpty
      ? pool
      : [_genericFallback[mood] ?? '...'];
  final extra = bonded ? (_bondPools[mascotId]?[mood]) : null;
  return extra == null ? base : [...base, ...extra];
}
