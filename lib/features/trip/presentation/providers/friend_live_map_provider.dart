import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_provider.dart';
import '../../../friends/presentation/providers/friends_provider.dart';
import '../../domain/entities/route_point.dart';
import 'crew_live_map_provider.dart' show CrewLiveDriver;

part 'friend_live_map_provider.g.dart';

/// Vedi _kCrewLiveStaleAfter in crew_live_map_provider.dart — stessa soglia,
/// stesso motivo.
const _kFriendLiveStaleAfter = Duration(seconds: 12);

/// Espone gli amici accettati dell'utente che stanno guidando ora, con
/// posizione live, per il layer "amici" sulla mappa della sezione guida —
/// stesso dato/scopo di [CrewLiveMapController] ma un canale Realtime PER
/// AMICO ("friend-live-<profileId>", vedi 0023_friends.sql) invece di un
/// canale unico condiviso da crew: ogni amico pubblica solo sul proprio
/// canale (vedi TripLiveController._joinFriendLiveChannel), qui ci si
/// iscrive in sola lettura a quello di ciascun amico accettato — la RLS
/// del canale (0023) è quella che impedisce a chiunque non sia amico
/// accettato di leggerlo, non un filtro qui lato client.
@riverpod
class FriendLiveMapController extends _$FriendLiveMapController {
  final Map<String, RealtimeChannel> _channels = {};
  Timer? _staleTimer;

  @override
  Map<String, CrewLiveDriver> build() {
    ref.onDispose(_leaveAll);

    final friendIds = <String>{
      for (final f in ref.watch(myFriendsProvider).valueOrNull ?? const [])
        f.profileId,
    };
    _reconcileChannels(friendIds);

    _staleTimer?.cancel();
    _staleTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final now = DateTime.now();
      final fresh = {
        for (final entry in state.entries)
          if (now.difference(entry.value.lastUpdate) < _kFriendLiveStaleAfter)
            entry.key: entry.value,
      };
      if (fresh.length != state.length) state = fresh;
    });

    return const {};
  }

  void _reconcileChannels(Set<String> friendIds) {
    for (final id in _channels.keys.toList()) {
      if (!friendIds.contains(id)) _leave(id);
    }
    for (final id in friendIds) {
      if (!_channels.containsKey(id)) _join(id);
    }
  }

  void _join(String friendId) {
    final channel = ref.read(supabaseClientProvider).channel(
          'friend-live-$friendId',
          opts: const RealtimeChannelConfig(private: true),
        );
    _channels[friendId] = channel;
    channel
      ..onBroadcast(
          event: 'position',
          callback: (payload) => _onPosition(friendId, payload))
      ..onPresenceSync((_) => _onPresenceSync(friendId, channel))
      ..subscribe();
  }

  void _leave(String friendId) {
    final channel = _channels.remove(friendId);
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    if (state.containsKey(friendId)) {
      state = {...state}..remove(friendId);
    }
  }

  void _leaveAll() {
    _staleTimer?.cancel();
    _staleTimer = null;
    for (final channel in _channels.values) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    _channels.clear();
  }

  /// A differenza del canale crew (condiviso da più membri, quindi la
  /// Presence sync serve a capire CHI c'è ancora), il canale di un amico
  /// ha un solo possibile publisher: presence vuota = quell'amico ha
  /// smesso di guidare (untrack in TripLiveController), presence non
  /// vuota = sta ancora guidando, nessun payload aggiuntivo da leggere.
  void _onPresenceSync(String friendId, RealtimeChannel channel) {
    final present = channel.presenceState().any((s) => s.presences.isNotEmpty);
    if (!present && state.containsKey(friendId)) {
      state = {...state}..remove(friendId);
    }
  }

  void _onPosition(String friendId, Map<String, dynamic> payload) {
    final lat = (payload['lat'] as num?)?.toDouble();
    final lng = (payload['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    final existing = state[friendId];
    final points = [...?existing?.routePoints, RoutePoint(lat, lng)];
    final trimmed =
        points.length > 500 ? points.sublist(points.length - 500) : points;

    state = {
      ...state,
      friendId: CrewLiveDriver(
        profileId: friendId,
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
}
