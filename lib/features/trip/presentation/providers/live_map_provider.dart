import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/route_point.dart';

part 'live_map_provider.g.dart';

/// Quanto un fix è "vecchio" prima di considerare un utente non più in
/// guida — copre i casi in cui il canale non riceve un evento di leave
/// pulito (app uccisa, connessione persa), senza dipendere solo dalla
/// Presence sync.
const _kLiveStaleAfter = Duration(seconds: 12);

/// Snapshot della guida live di un utente, ricostruito dai messaggi
/// broadcast del canale condiviso "drivers-live" (vedi TripLiveController
/// per il lato publisher e la migration 0027 per l'autorizzazione RLS del
/// canale). Mai persistito: vive solo mentre la mappa della sezione guida
/// è aperta.
class LiveDriver {
  final String profileId;
  final String username;
  final String? avatarUrl;
  final String accentColor;
  final double lat;
  final double lng;
  final double speedKmh;
  final double? heading;
  final List<RoutePoint> routePoints;
  final DateTime lastUpdate;

  const LiveDriver({
    required this.profileId,
    required this.username,
    required this.avatarUrl,
    required this.accentColor,
    required this.lat,
    required this.lng,
    required this.speedKmh,
    required this.heading,
    required this.routePoints,
    required this.lastUpdate,
  });
}

/// Espone tutti gli utenti che stanno guidando ora, con posizione e
/// percorso live, per il layer "altri driver" sulla mappa della sezione
/// guida — l'app è privata e chiusa, tutti gli utenti sono già
/// "connessi" tra loro, quindi un solo canale condiviso invece di uno per
/// crew o uno per amico. Si iscrive in sola lettura allo stesso canale su
/// cui [TripLiveController] pubblica quando l'utente stesso guida.
@riverpod
class LiveMapController extends _$LiveMapController {
  static const _channelName = 'drivers-live';

  RealtimeChannel? _channel;
  Timer? _staleTimer;

  @override
  Map<String, LiveDriver> build() {
    ref.onDispose(_leave);
    if (ref.watch(authStateProvider).valueOrNull != null) _join();
    return const {};
  }

  void _join() {
    final channel = ref.read(supabaseClientProvider).channel(
          _channelName,
          opts: const RealtimeChannelConfig(private: true),
        );
    _channel = channel;
    channel
      ..onBroadcast(event: 'position', callback: _onPosition)
      ..onPresenceSync(_onPresenceSync)
      ..subscribe();

    _staleTimer?.cancel();
    _staleTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final now = DateTime.now();
      final fresh = {
        for (final entry in state.entries)
          if (now.difference(entry.value.lastUpdate) < _kLiveStaleAfter)
            entry.key: entry.value,
      };
      if (fresh.length != state.length) state = fresh;
    });
  }

  /// La Presence sync riporta chi è tuttora "agganciato" al canale: usata
  /// solo per rimuovere subito chi ha smesso di guidare (track()/untrack()
  /// in TripLiveController), lo staleness timer sopra resta la rete di
  /// sicurezza per le disconnessioni non pulite.
  void _onPresenceSync(RealtimePresenceSyncPayload _) {
    final channel = _channel;
    if (channel == null) return;
    final present = <String>{
      for (final s in channel.presenceState())
        for (final p in s.presences)
          if (p.payload['profileId'] is String)
            p.payload['profileId'] as String,
    };
    if (state.keys.every(present.contains)) return;
    state = {
      for (final entry in state.entries)
        if (present.contains(entry.key)) entry.key: entry.value,
    };
  }

  void _onPosition(Map<String, dynamic> payload) {
    final profileId = payload['profileId'] as String?;
    final lat = (payload['lat'] as num?)?.toDouble();
    final lng = (payload['lng'] as num?)?.toDouble();
    if (profileId == null || lat == null || lng == null) return;

    final existing = state[profileId];
    final points = [...?existing?.routePoints, RoutePoint(lat, lng)];
    final trimmed =
        points.length > 500 ? points.sublist(points.length - 500) : points;

    state = {
      ...state,
      profileId: LiveDriver(
        profileId: profileId,
        username: payload['username'] as String? ?? existing?.username ?? '',
        avatarUrl: payload['avatarUrl'] as String? ?? existing?.avatarUrl,
        accentColor: payload['accentColor'] as String? ??
            existing?.accentColor ??
            '#35E0FF',
        lat: lat,
        lng: lng,
        speedKmh: (payload['speedKmh'] as num?)?.toDouble() ?? 0,
        heading: (payload['heading'] as num?)?.toDouble(),
        routePoints: trimmed,
        lastUpdate: DateTime.now(),
      ),
    };
  }

  void _leave() {
    _staleTimer?.cancel();
    _staleTimer = null;
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
  }
}
