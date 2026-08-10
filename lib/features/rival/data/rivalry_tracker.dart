import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Ultimo rivale noto (l'entry immediatamente sopra l'utente) per la
/// classifica canonica xp/settimana/globale — una sola chiave per
/// utente, nessun tracking per altre combinazioni metrica/periodo/scope.
class RivalrySnapshot {
  final String profileId;
  final String displayName;
  final int rank;

  const RivalrySnapshot({
    required this.profileId,
    required this.displayName,
    required this.rank,
  });

  Map<String, dynamic> toJson() =>
      {'profile_id': profileId, 'display_name': displayName, 'rank': rank};

  factory RivalrySnapshot.fromJson(Map<String, dynamic> json) =>
      RivalrySnapshot(
        profileId: json['profile_id'] as String,
        displayName: json['display_name'] as String,
        rank: json['rank'] as int,
      );
}

/// Persistito su shared_preferences (JSON su un'unica chiave), stesso
/// stile di RivalLocalStore (core/rival/data/rival_local_store.dart) —
/// nessun local DB vero in questo progetto, e qui basta un solo record.
class RivalryTracker {
  String _key(String profileId) => 'rivalry_tracker_$profileId';

  Future<RivalrySnapshot?> read(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(profileId));
    if (raw == null || raw.isEmpty) return null;
    return RivalrySnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> write(String profileId, RivalrySnapshot? snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    if (snapshot == null) {
      await prefs.remove(_key(profileId));
    } else {
      await prefs.setString(_key(profileId), jsonEncode(snapshot.toJson()));
    }
  }
}
