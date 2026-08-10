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

/// Non lancia mai per un (mascotId, mood) senza contenuto dedicato: prova
/// prima il pool specifico, poi [_genericFallback] — stesso principio di
/// `notification_presentation.dart` (mai un'eccezione per un caso non
/// ancora mappato).
List<String> phrasesFor(String mascotId, RivalMood mood) {
  final pool = _pools[mascotId]?[mood];
  if (pool != null && pool.isNotEmpty) return pool;
  return [_genericFallback[mood] ?? '...'];
}
