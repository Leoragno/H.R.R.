import 'package:equatable/equatable.dart';

/// Amico accettato — riga `my_friends()` (0023_friends.sql), già arricchita
/// col profilo lato server (nessun giro aggiuntivo per utente).
class FriendProfile extends Equatable {
  final String profileId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String accentColor;
  final int level;

  const FriendProfile({
    required this.profileId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.accentColor,
    required this.level,
  });

  @override
  List<Object?> get props =>
      [profileId, username, displayName, avatarUrl, accentColor, level];
}

/// Richiesta di amicizia in arrivo — riga `pending_friend_requests()`,
/// col profilo di chi l'ha inviata.
class FriendRequest extends Equatable {
  final String requesterId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String accentColor;
  final int level;
  final DateTime createdAt;

  const FriendRequest({
    required this.requesterId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.accentColor,
    required this.level,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        requesterId,
        username,
        displayName,
        avatarUrl,
        accentColor,
        level,
        createdAt,
      ];
}

/// Rapporto fra chi cerca e il profilo trovato — colonna `relationship` di
/// `search_profiles_for_friend()`, decide quale azione mostrare in UI
/// (Aggiungi / Richiesta inviata / Accetta richiesta / già amici).
enum FriendRelationship {
  none,
  pendingOutgoing,
  pendingIncoming,
  accepted;

  static FriendRelationship fromApi(String value) => switch (value) {
        'accepted' => FriendRelationship.accepted,
        'pending_outgoing' => FriendRelationship.pendingOutgoing,
        'pending_incoming' => FriendRelationship.pendingIncoming,
        _ => FriendRelationship.none,
      };
}

/// Risultato di ricerca profili per aggiungere un amico — riga
/// `search_profiles_for_friend()`.
class FriendSearchResult extends Equatable {
  final String profileId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final int level;
  final FriendRelationship relationship;

  const FriendSearchResult({
    required this.profileId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.level,
    required this.relationship,
  });

  @override
  List<Object?> get props =>
      [profileId, username, displayName, avatarUrl, level, relationship];
}
