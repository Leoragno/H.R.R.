import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Stato giornaliero/streak del Rival per un profilo — persistito su
/// `shared_preferences` (un JSON su un'unica chiave, stesso pattern di
/// OfflineEventQueue in core/offline/): nessuna feature di questo progetto
/// usa un local DB vero, e qui bastano pochi campi scalari.
class RivalDailyState {
  /// yyyy-MM-dd, data-only in ora locale.
  final String? lastActiveDate;
  final int streakCount;
  final DateTime? lastTripAt;

  /// yyyy-MM-dd — guarda contro più di una "presa in giro per inattività"
  /// nello stesso giorno.
  final String? inactivityQuipShownDate;

  const RivalDailyState({
    this.lastActiveDate,
    this.streakCount = 0,
    this.lastTripAt,
    this.inactivityQuipShownDate,
  });

  RivalDailyState copyWith({
    String? lastActiveDate,
    int? streakCount,
    DateTime? lastTripAt,
    String? inactivityQuipShownDate,
  }) =>
      RivalDailyState(
        lastActiveDate: lastActiveDate ?? this.lastActiveDate,
        streakCount: streakCount ?? this.streakCount,
        lastTripAt: lastTripAt ?? this.lastTripAt,
        inactivityQuipShownDate:
            inactivityQuipShownDate ?? this.inactivityQuipShownDate,
      );

  Map<String, dynamic> toJson() => {
        'last_active_date': lastActiveDate,
        'streak_count': streakCount,
        'last_trip_at': lastTripAt?.toIso8601String(),
        'inactivity_quip_shown_date': inactivityQuipShownDate,
      };

  factory RivalDailyState.fromJson(Map<String, dynamic> json) =>
      RivalDailyState(
        lastActiveDate: json['last_active_date'] as String?,
        streakCount: json['streak_count'] as int? ?? 0,
        lastTripAt: json['last_trip_at'] == null
            ? null
            : DateTime.parse(json['last_trip_at'] as String),
        inactivityQuipShownDate: json['inactivity_quip_shown_date'] as String?,
      );
}

class RivalLocalStore {
  String _key(String profileId) => 'rival_state_$profileId';

  Future<RivalDailyState> read(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(profileId));
    if (raw == null || raw.isEmpty) return const RivalDailyState();
    return RivalDailyState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> write(String profileId, RivalDailyState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(profileId), jsonEncode(state.toJson()));
  }
}
