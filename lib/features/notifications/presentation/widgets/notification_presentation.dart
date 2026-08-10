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
    color: AppColors.guidaCyan,
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
    color: AppColors.neonAmber,
    title: (n) => _pick(n, 'title', const [
          'Ci sei quasi! 🔥',
          'Manca un soffio! 💨',
          'Dritto al traguardo! 🏁',
        ]),
    body: (n) => 'Manca pochissimo per completare "${n.body ?? "la missione"}".',
  ),
  'mission_claimed': NotificationPresentation(
    icon: Icons.card_giftcard_rounded,
    color: AppColors.guidaMagenta,
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
    color: AppColors.neonMagenta,
    title: (n) => _pick(n, 'title', const [
          'Piaci alla folla! ❤️',
          'Successo! 😍',
        ]),
    body: (n) => n.body ?? 'A qualcuno piace il tuo spot.',
  ),
  'comment': NotificationPresentation(
    icon: Icons.chat_bubble_rounded,
    color: AppColors.guidaBlue,
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
  'friend_request': NotificationPresentation(
    icon: Icons.person_add_rounded,
    color: AppColors.guidaCyan,
    title: (n) => _pick(n, 'title', const [
          'Nuova richiesta di amicizia 🤝',
          'Qualcuno vuole unirsi! 👋',
        ]),
    body: (n) => n.body ?? 'Qualcuno vuole unirsi al tuo giro.',
  ),
  'event': NotificationPresentation(
    icon: Icons.event_rounded,
    color: AppColors.guidaPurple,
    title: (n) => _pick(n, 'title', const [
          'Si muove qualcosa! 📅',
          'Occhio al calendario! 🗓️',
        ]),
    body: (n) => n.body ?? 'C\'è un evento che potrebbe interessarti.',
  ),
  'rating': NotificationPresentation(
    icon: Icons.star_rounded,
    color: AppColors.neonAmber,
    title: (n) => _pick(n, 'title', const [
          'Nuovo voto! ⭐',
          'Sei stato votato! 🌟',
          'Le stelle parlano! ✨',
        ]),
    body: (n) => n.body ?? 'Qualcuno ha votato il tuo spot.',
  ),
  'crew_member_joined': NotificationPresentation(
    icon: Icons.group_add_rounded,
    color: AppColors.guidaCyan,
    title: (n) => _pick(n, 'title', const [
          'Nuovo membro! 🚗',
          'La squadra si allarga! 👥',
          'Rinforzi in arrivo! 🏎️',
        ]),
    body: (n) => n.body ?? 'Un nuovo pilota si è unito alla crew.',
  ),
  'crew_role_changed': NotificationPresentation(
    icon: Icons.military_tech_rounded,
    color: AppColors.neonAmber,
    title: (n) => n.title,
    body: (n) => n.body ?? 'Il tuo ruolo in crew è cambiato.',
  ),
  'crew_member_left': NotificationPresentation(
    icon: Icons.waving_hand_rounded,
    color: AppColors.guidaTextSecondary,
    title: (n) => _pick(n, 'title', const [
          'Qualcuno ha lasciato la crew 👋',
          'Un pilota se ne va 🚪',
        ]),
    body: (n) => n.body ?? 'Un membro ha lasciato la crew.',
  ),
  'crew_kicked': NotificationPresentation(
    icon: Icons.person_remove_rounded,
    color: AppColors.neonRed,
    title: (n) => _pick(n, 'title', const [
          'Espulso dalla crew',
          'Fuori dal giro',
        ]),
    body: (n) => n.body ?? 'Sei stato rimosso dalla crew.',
  ),
  'crew_disband_vote_started': NotificationPresentation(
    icon: Icons.warning_amber_rounded,
    color: AppColors.neonAmber,
    title: (n) => _pick(n, 'title', const [
          'Voto di scioglimento in corso ⚠️',
          'La crew è a un bivio 🚧',
        ]),
    body: (n) => n.body ?? 'Un membro vuole sciogliere la crew.',
  ),
  'crew_disbanded': NotificationPresentation(
    icon: Icons.heart_broken_rounded,
    color: AppColors.neonRed,
    title: (n) => _pick(n, 'title', const [
          'Crew sciolta 💔',
          'Fine di un\'era 🏁',
        ]),
    body: (n) => n.body ?? 'La crew è stata sciolta.',
  ),
  'territory_stolen': NotificationPresentation(
    icon: Icons.flag_rounded,
    color: AppColors.neonRed,
    title: (n) => _pick(n, 'title', const [
          'Territorio conquistato! 🏴',
          'Ti hanno invaso! 🚩',
          'Confini sotto attacco! ⚔️',
        ]),
    body: (n) => n.body ?? 'Qualcuno ti ha rubato un esagono.',
  ),
  'level_up': NotificationPresentation(
    icon: Icons.trending_up_rounded,
    color: AppColors.neonGreen,
    title: (n) => _pick(n, 'title', const [
          'Livello superiore! 🚀',
          'Sei salito di livello! 📈',
          'Sempre più forte! 💪',
        ]),
    body: (n) => n.body ?? 'Hai guadagnato un nuovo livello.',
  ),
  'speed_record': NotificationPresentation(
    icon: Icons.speed_rounded,
    color: AppColors.neonCyan,
    title: (n) => _pick(n, 'title', const [
          'Nuovo record di velocità! 🏎️',
          'Velocità mai vista! 💨',
          'Hai spinto al massimo! ⚡',
        ]),
    body: (n) => n.body ?? 'Hai battuto il tuo record personale di velocità.',
  ),
  'leaderboard_overtaken': NotificationPresentation(
    icon: Icons.trending_down_rounded,
    color: AppColors.neonRed,
    title: (n) => _pick(n, 'title', const [
          'Sorpasso subito! 📉',
          'Ti hanno superato! 😤',
        ]),
    body: (n) => n.body ?? 'Qualcuno ti ha superato in classifica.',
  ),
  'distance_record': NotificationPresentation(
    icon: Icons.map_rounded,
    color: AppColors.neonPurple,
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
  color: AppColors.guidaTextSecondary,
  title: (n) => n.title,
  body: (n) => n.body ?? '',
);

NotificationPresentation presentationFor(AppNotification notification) =>
    _byType[notification.type] ?? _fallback;
