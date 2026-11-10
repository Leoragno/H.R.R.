import 'package:flutter/material.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/app_notification.dart';

/// Come si presenta un tipo di notifica (HEAT): icona, colore semantico,
/// etichetta in grassetto ([title]), frase ([body]) e dove porta il tocco
/// ([route]). Il title/body salvati in DB sono scritti dai trigger server
/// (con emoji e numeri grezzi): qui si ricompone un testo asciutto, nel
/// tono minuscolo del design, usando `data` quando serve.
///
/// Colori: rosso per i rivali (territorio rubato, sorpasso), oro per
/// premi e voti, inchiostro per il resto. Mai l'accento: in lista
/// sarebbe ripetuto su ogni riga.
///
/// Tipi nuovi non ancora mappati usano [_fallback], mai un'eccezione: i
/// trigger server possono introdurne prima che il client li conosca.
class NotificationPresentation {
  final IconData icon;
  final Color color;
  final String Function(AppNotification n) title;
  final String Function(AppNotification n) body;

  /// Rotta da aprire al tocco; null = nessuna destinazione.
  final String? Function(AppNotification n) route;

  /// Riga "rivale" (sfondo rosso tenue da non letta).
  final bool rival;

  const NotificationPresentation({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.route = _noRoute,
    this.rival = false,
  });
}

String? _noRoute(AppNotification n) => null;

String _clean(String? s, String fallback) {
  final t = (s ?? '').trim();
  return t.isEmpty ? fallback : t;
}

num? _num(AppNotification n, String key) => n.data[key] as num?;

String? _spotRoute(AppNotification n) {
  final id = n.data['spot_id'] as String?;
  return id == null ? null : AppRoutes.spotDetail.replaceFirst(':spotId', id);
}

String? _tripRoute(AppNotification n) {
  final id = n.data['trip_id'] as String?;
  return id == null ? null : AppRoutes.tripDetail.replaceFirst(':tripId', id);
}

final Map<String, NotificationPresentation> _byType = {
  'mission_complete': NotificationPresentation(
    icon: Icons.flag_rounded,
    color: AppColor.gold,
    title: (n) => 'Missione',
    body: (n) =>
        '"${_clean(n.body, 'una missione')}" completata. riscuoti il premio.',
    route: (n) => AppRoutes.missions,
  ),
  'mission_almost_done': NotificationPresentation(
    icon: Icons.timer_rounded,
    color: AppColor.gold,
    title: (n) => 'Missione',
    body: (n) => 'ci sei quasi: "${_clean(n.body, 'la missione')}".',
    route: (n) => AppRoutes.missions,
  ),
  'mission_claimed': NotificationPresentation(
    icon: Icons.card_giftcard_rounded,
    color: AppColor.gold,
    title: (n) => 'Missione',
    body: (n) => 'premio di "${_clean(n.body, 'una missione')}" riscosso.',
    route: (n) => AppRoutes.missions,
  ),
  'achievement_unlocked': NotificationPresentation(
    icon: Icons.workspace_premium_rounded,
    color: AppColor.gold,
    title: (n) => 'Achievement',
    body: (n) => '${_clean(n.body, 'nuovo traguardo')} · sbloccato.',
    route: (n) => AppRoutes.achievements,
  ),
  'comment': NotificationPresentation(
    icon: Icons.chat_bubble_rounded,
    color: AppColor.ink,
    title: (n) => 'Commento',
    body: (n) => _clean(n.body, 'qualcuno ha commentato il tuo spot.'),
    route: _spotRoute,
  ),
  'rating': NotificationPresentation(
    icon: Icons.star_rounded,
    color: AppColor.gold,
    title: (n) => 'Voto',
    body: (n) {
      final r = _num(n, 'rating');
      return r == null
          ? _clean(n.body, 'qualcuno ha votato il tuo spot.')
          : 'il tuo spot ha ricevuto ${r.round()}/5.';
    },
    route: _spotRoute,
  ),
  'like': NotificationPresentation(
    icon: Icons.favorite_rounded,
    color: AppColor.ink,
    title: (n) => 'Spot',
    body: (n) => _clean(n.body, 'a qualcuno piace il tuo spot.'),
    route: _spotRoute,
  ),
  'territory_stolen': NotificationPresentation(
    icon: Icons.hexagon_rounded,
    color: AppColor.danger,
    rival: true,
    title: (n) => 'Territorio',
    body: (n) => _clean(n.body, 'qualcuno ti ha rubato un esagono.')
        .replaceAll('pentagoni', 'esagoni')
        .replaceAll('pentagono', 'esagono'),
    route: (n) => AppRoutes.game,
  ),
  'leaderboard_overtaken': NotificationPresentation(
    icon: Icons.trending_down_rounded,
    color: AppColor.danger,
    rival: true,
    title: (n) => 'Classifica',
    body: (n) => _clean(n.body, 'qualcuno ti ha superato in classifica.'),
    route: (n) => AppRoutes.leaderboard,
  ),
  'level_up': NotificationPresentation(
    icon: Icons.trending_up_rounded,
    color: AppColor.ink,
    title: (n) => 'Livello',
    body: (n) {
      final l = _num(n, 'level');
      return l == null
          ? _clean(n.body, 'sei salito di livello.')
          : 'sei salito al livello ${l.toInt()}.';
    },
    route: (n) => AppRoutes.profile,
  ),
  'speed_record': NotificationPresentation(
    icon: Icons.speed_rounded,
    color: AppColor.ink,
    title: (n) => 'Record',
    body: (n) {
      final v = _num(n, 'max_speed_kmh');
      return v == null
          ? _clean(n.body, 'nuovo record personale di velocità.')
          : 'nuovo record di velocità · ${v.round()} km/h.';
    },
    route: _tripRoute,
  ),
  'distance_record': NotificationPresentation(
    icon: Icons.route_rounded,
    color: AppColor.ink,
    title: (n) => 'Record',
    body: (n) {
      final v = _num(n, 'distance_km');
      return v == null
          ? _clean(n.body, 'nuovo record personale di distanza.')
          : 'guida più lunga di sempre · ${v.toStringAsFixed(1).replaceAll('.', ',')} km.';
    },
    route: _tripRoute,
  ),
  'friend_request': NotificationPresentation(
    icon: Icons.person_add_rounded,
    color: AppColor.ink,
    title: (n) => 'Amici',
    body: (n) => _clean(n.body, 'hai una nuova richiesta di amicizia.'),
  ),
  'crew_member_joined': NotificationPresentation(
    icon: Icons.groups_rounded,
    color: AppColor.ink,
    title: (n) => 'Crew',
    body: (n) => _clean(n.body, 'un nuovo membro nella tua crew.'),
  ),
  'crew_disbanded': NotificationPresentation(
    icon: Icons.group_off_rounded,
    color: AppColor.inkMuted,
    title: (n) => 'Crew',
    body: (n) => _clean(n.body, 'la tua crew è stata sciolta.'),
  ),
  'event': NotificationPresentation(
    icon: Icons.event_rounded,
    color: AppColor.ink,
    title: (n) => _clean(n.title, 'Evento'),
    body: (n) => _clean(n.body, ''),
  ),
  // Sfide 1 vs 1 (0039_challenges_presence.sql).
  'challenge_received': NotificationPresentation(
    icon: Icons.sports_mma_rounded,
    color: AppColor.danger,
    rival: true,
    title: (n) => 'Sfida',
    body: (n) {
      final who = n.data['from_username'] as String?;
      final stake = _num(n, 'stake_xp');
      return who == null
          ? _clean(n.body, 'qualcuno ti ha sfidato.')
          : '@$who ti sfida${stake == null ? '' : ' · ${stake.toInt()} XP'}.';
    },
    route: (n) => AppRoutes.challenges,
  ),
  'challenge_accepted': NotificationPresentation(
    icon: Icons.sports_mma_rounded,
    color: AppColor.ink,
    title: (n) => 'Sfida',
    body: (n) => _clean(n.body, 'sfida accettata. si parte.'),
    route: (n) => AppRoutes.challenges,
  ),
  'challenge_declined': NotificationPresentation(
    icon: Icons.sports_mma_rounded,
    color: AppColor.inkMuted,
    title: (n) => 'Sfida',
    body: (n) => _clean(n.body, 'sfida rifiutata.'),
    route: (n) => AppRoutes.challenges,
  ),
  'challenge_won': NotificationPresentation(
    icon: Icons.emoji_events_rounded,
    color: AppColor.gold,
    title: (n) => 'Sfida vinta',
    body: (n) {
      final stake = _num(n, 'stake_xp');
      return stake == null
          ? _clean(n.body, 'hai vinto la sfida.')
          : 'hai vinto la sfida. +${stake.toInt()} XP.';
    },
    route: (n) => AppRoutes.challenges,
  ),
  'challenge_lost': NotificationPresentation(
    icon: Icons.sports_mma_rounded,
    color: AppColor.danger,
    rival: true,
    title: (n) => 'Sfida persa',
    body: (n) => _clean(n.body, 'hai perso la sfida. chiedi la rivincita.'),
    route: (n) => AppRoutes.challenges,
  ),
  'challenge_draw': NotificationPresentation(
    icon: Icons.sports_mma_rounded,
    color: AppColor.inkMuted,
    title: (n) => 'Sfida pari',
    body: (n) => _clean(n.body, 'la sfida è finita in parità.'),
    route: (n) => AppRoutes.challenges,
  ),
  // Nuova APK (0036_app_releases.sql): l'avviso "Aggiorna" lo mostra
  // AppUpdatePrompt all'apertura, qui solo la voce nel feed.
  'app_update': NotificationPresentation(
    icon: Icons.system_update_rounded,
    color: AppColor.ink,
    title: (n) => 'Aggiornamento',
    body: (n) => _clean(n.body, 'nuova versione disponibile.'),
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
