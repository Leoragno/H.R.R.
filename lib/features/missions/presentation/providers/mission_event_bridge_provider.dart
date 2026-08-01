import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/events/mission_event.dart';
import '../../../../core/events/mission_event_bus.dart';
import '../../../../core/offline/offline_event_queue.dart';
import 'mission_provider.dart';

part 'mission_event_bridge_provider.g.dart';

/// Ascolta il bus condiviso (core/events) e lo collega al Mission Engine:
/// ogni evento viene prima accodato localmente, poi si tenta subito
/// l'invio — un solo percorso sia online che offline, la coda garantisce
/// che un fallimento di rete non perda l'evento (viene ritentato alla
/// riconnessione). Nessuna feature deve mai chiamare
/// record_mission_event/il repository direttamente: pubblica sul bus,
/// questo provider è l'unico consumatore.
///
/// Va tenuto vivo per tutta la sessione app — instanziato una volta da
/// [HrrApp] (vedi main.dart) leggendolo con `ref.watch` cosi Riverpod non
/// lo scarta per mancanza di ascoltatori.
@Riverpod(keepAlive: true)
class MissionEventBridge extends _$MissionEventBridge {
  final _queue = OfflineEventQueue();
  StreamSubscription<MissionEvent>? _busSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void build() {
    final bus = ref.watch(missionEventBusProvider);
    _busSub = bus.stream.listen(_handle);
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        _drainQueue();
      }
    });
    ref.onDispose(() {
      _busSub?.cancel();
      _connectivitySub?.cancel();
    });
  }

  Future<void> _handle(MissionEvent event) async {
    await _queue.enqueue(QueuedMissionEvent(
      eventType: event.type,
      payload: event.toPayload(),
      idempotencyKey: event.idempotencyKey,
      queuedAt: event.occurredAt,
    ));
    await _drainQueue();
  }

  Future<void> _drainQueue() async {
    final repository = ref.read(missionRepositoryProvider);
    await _queue.drain((queued) => repository.recordRawEvent(
          eventType: queued.eventType,
          payload: queued.payload,
          idempotencyKey: queued.idempotencyKey,
        ));
  }
}
