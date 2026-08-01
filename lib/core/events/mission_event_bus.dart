import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'mission_event.dart';

part 'mission_event_bus.g.dart';

/// Bus condiviso verso il Mission Engine. Qualunque feature pubblica qui
/// (`ref.read(missionEventBusProvider).publish(TripCompleted(...))`) senza
/// mai importare missions/repository — questo è l'unico punto di
/// contatto, per evitare controlli di missione sparsi nel codice.
class MissionEventBus {
  final _controller = StreamController<MissionEvent>.broadcast();

  Stream<MissionEvent> get stream => _controller.stream;

  void publish(MissionEvent event) => _controller.add(event);

  void dispose() => _controller.close();
}

@Riverpod(keepAlive: true)
MissionEventBus missionEventBus(MissionEventBusRef ref) {
  final bus = MissionEventBus();
  ref.onDispose(bus.dispose);
  return bus;
}
