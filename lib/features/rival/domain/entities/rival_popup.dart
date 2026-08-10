import 'package:uuid/uuid.dart';

import 'mascot.dart';

const _uuid = Uuid();

/// Mood che guida sia la frase mostrata (rival_dialogue.dart) sia l'asset
/// visivo preferito (mascot_avatar.dart cerca prima
/// assets/emotes/<id>_<mood>.png, altrimenti ripiega su hero/pose).
enum RivalMood {
  greeting,
  missionCelebration,
  personalRecordHype,
  streakEncouraging,
  streakUrgent,
  streakLost,
  inactivityTaunt,
  leaderboardOvertake,
}

/// Un singolo "impulso" del Rival da mostrare in overlay. Volutamente non
/// Equatable e con [id] generato ad ogni istanza: se lo fosse per valore,
/// Riverpod potrebbe considerare due emissioni identiche (stesso mood e
/// stessa frase pescata a caso) come "nessun cambiamento" e
/// [rival_controller_provider] non riemetterebbe — qui ogni emissione deve
/// invece attraversare sempre `ref.listen`.
class RivalPopup {
  final String id;
  final Mascot mascot;
  final RivalMood mood;
  final String phrase;

  RivalPopup({
    required this.mascot,
    required this.mood,
    required this.phrase,
  }) : id = _uuid.v4();
}
