import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/app_notification.dart';

/// Icona/colore/copy "simpatica" per un tipo di notifica — il `title`/
/// `body` grezzi in DB sono neutri (scritti per essere generici lato
/// server), qui li vestiamo con un tono più giocoso senza toccare le
/// migration. Nuovi `type` non ancora mappati usano [_fallback], mai
/// un'eccezione per un tipo sconosciuto (i trigger server-side possono
/// introdurne di nuovi prima che il client li conosca).
///
/// Ogni tipo ha più varianti di title/body: [_pick] sceglie in modo
/// stabile (stesso [AppNotification.id] -> stessa variante, niente
/// flicker tra rebuild) ma diverso da notifica a notifica, così due
/// "Missione completata" di fila non si leggono identiche.
class NotificationPresentation {
  final IconData icon;
  final Color color;
  final String Function(AppNotification n) title;
  final String Function(AppNotification n) body;

  const NotificationPresentation({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
}

T _pick<T>(AppNotification n, String salt, List<T> options) =>
    options[(n.id + salt).hashCode.abs() % options.length];

final Map<String, NotificationPresentation> _byType = {
  'mission_complete': NotificationPresentation(
    icon: Icons.emoji_events_rounded,
    color: AppColor.cyan,
    title: (n) => _pick(n, 'title', const [
      'Missione completata! 🎯',
      'Obiettivo raggiunto! ✅',
      'Missione nel sacco! 🔥',
    ]),
    body: (n) => _pick(n, 'body', [
      '"${n.body ?? "Una missione"}" portata a casa. Vai a riscuotere il premio!',
      'Hai chiuso "${n.body ?? "una missione"}" alla grande. Il premio ti aspetta.',
      '"${n.body ?? "Una missione"}" è storia. Passa a ritirare il bottino!',
    ]),
  ),
  'mission_almost_done': NotificationPresentation(
    icon: Icons.local_fire_department_rounded,
    color: AppColor.amber,
    title: (n) => _pick(n, 'title', const [
      'Ci sei quasi! 🔥',
      'Manca un soffio! 💨',
      'Dritto al traguardo! 🏁',
    ]),
    body: (n) =>
        'Manca pochissimo per completare "${n.body ?? "la missione"}".',
  ),
  'mission_claimed': NotificationPresentation(
    icon: Icons.card_giftcard_rounded,
    color: AppColor.magenta,
    title: (n) => _pick(n, 'title', const [
      'Premio riscosso! 🎁',
      'Bottino incassato! 💰',
      'Premio in tasca! 🎉',
    ]),
    body: (n) => '"${n.body ?? "Il premio"}" è ufficialmente nel tuo bottino.',
  ),
  'achievement_unlocked': NotificationPresentation(
    icon: Icons.military_tech_rounded,
    color: const Color(0xFFFFC93C),
    title: (n) => _pick(n, 'title', const [
      'Achievement sbloccato! 🏆',
      'Nuovo trofeo! 🏅',
      'Leggenda in costruzione! ⭐',
    ]),
    body: (n) => _pick(n, 'body', [
      '${n.body ?? "Un traguardo"} — sei una leggenda della strada.',
      '${n.body ?? "Un traguardo"}. Il tuo garage si arricchisce di gloria.',
      '${n.body ?? "Un traguardo"} conquistato. Continua così!',
    ]),
  ),
  'like': NotificationPresentation(
    icon: Icons.favorite_rounded,
    color: AppColor.magenta,
    title: (n) => _pick(n, 'title', const [
      'Piaci alla folla! ❤️',
      'Successo! 😍',
    ]),
    body: (n) => n.body ?? 'A qualcuno piace il tuo spot.',
  ),
  'comment': NotificationPresentation(
    icon: Icons.chat_bubble_rounded,
    color: AppMascot.nitro,
    title: (n) => _pick(n, 'title', const [
      'Nuovo commento! 💬',
      'Si commenta! 🗣️',
      'Hai fatto scalpore! 📢',
    ]),
    body: (n) => _pick(n, 'body', [
      n.body ?? 'Qualcuno ha detto la sua sul tuo spot.',
      '${n.body ?? "Qualcuno ha commentato"} — rispondi prima che si offenda! 😄',
    ]),
  ),
  'event': NotificationPresentation(
    icon: Icons.event_rounded,
    color: AppMascot.volt,
    title: (n) => _pick(n, 'title', const [
      'Si muove qualcosa! 📅',
      'Occhio al calendario! 🗓️',
    ]),
    body: (n) => n.body ?? 'C\'è un evento che potrebbe interessarti.',
  ),
  'rating': NotificationPresentation(
    icon: Icons.star_rounded,
    color: AppColor.amber,
    title: (n) => _pick(n, 'title', const [
      'Nuovo voto! ⭐',
      'Sei stato votato! 🌟',
      'Le stelle parlano! ✨',
    ]),
    body: (n) => n.body ?? 'Qualcuno ha votato il tuo spot.',
  ),
  'territory_stolen': NotificationPresentation(
    icon: Icons.flag_rounded,
    color: AppColor.danger,
    title: (n) => _pick(n, 'title', const [
      'Territorio conquistato! 🏴',
      'Ti hanno invaso! 🚩',
      'Confini sotto attacco! ⚔️',
    ]),
    body: (n) => n.body ?? 'Qualcuno ti ha rubato un esagono.',
  ),
  'level_up': NotificationPresentation(
    icon: Icons.trending_up_rounded,
    color: AppColor.success,
    title: (n) => _pick(n, 'title', const [
      'Livello superiore! 🚀',
      'Sei salito di livello! 📈',
      'Sempre più forte! 💪',
    ]),
    body: (n) => n.body ?? 'Hai guadagnato un nuovo livello.',
  ),
  'speed_record': NotificationPresentation(
    icon: Icons.speed_rounded,
    color: AppColor.cyan,
    title: (n) => _pick(n, 'title', const [
      'Nuovo record di velocità! 🏎️',
      'Velocità mai vista! 💨',
      'Hai spinto al massimo! ⚡',
    ]),
    body: (n) => n.body ?? 'Hai battuto il tuo record personale di velocità.',
  ),
  'leaderboard_overtaken': NotificationPresentation(
    icon: Icons.trending_down_rounded,
    color: AppColor.danger,
    title: (n) => _pick(n, 'title', const [
      'Sorpasso subito! 📉',
      'Ti hanno superato! 😤',
    ]),
    body: (n) => n.body ?? 'Qualcuno ti ha superato in classifica.',
  ),
  'distance_record': NotificationPresentation(
    icon: Icons.map_rounded,
    color: AppColor.magenta,
    title: (n) => _pick(n, 'title', const [
      'Nuovo record di distanza! 🛣️',
      'Chilometri da leggenda! 🗺️',
      'Hai macinato strada! 🚗',
    ]),
    body: (n) => n.body ?? 'Hai battuto il tuo record personale di distanza.',
  ),
};

final _fallback = NotificationPresentation(
  icon: Icons.notifications_rounded,
  color: AppColor.inkMuted,
  title: (n) => n.title,
  body: (n) => n.body ?? '',
);

NotificationPresentation presentationFor(AppNotification notification) =>
    _byType[notification.type] ?? _fallback;
