import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hrr_app/core/offline/offline_event_queue.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('enqueue poi drain invia in ordine e svuota la coda in caso di successo',
      () async {
    final queue = OfflineEventQueue();
    await queue.enqueue(QueuedMissionEvent(
      eventType: 'trip_completed',
      payload: const {'value': 12.0},
      idempotencyKey: 'k1',
      queuedAt: DateTime.now(),
    ));
    await queue.enqueue(QueuedMissionEvent(
      eventType: 'trip_started',
      payload: const {'value': 1},
      idempotencyKey: 'k2',
      queuedAt: DateTime.now(),
    ));

    final sentKeys = <String>[];
    await queue.drain((e) async => sentKeys.add(e.idempotencyKey));

    expect(sentKeys, ['k1', 'k2']);

    // Coda vuota dopo un drain riuscito: un secondo drain non invia nulla.
    final secondDrainKeys = <String>[];
    await queue.drain((e) async => secondDrainKeys.add(e.idempotencyKey));
    expect(secondDrainKeys, isEmpty);
  });

  test(
      'un fallimento a metà drain lascia in coda solo gli eventi non ancora inviati, in ordine',
      () async {
    final queue = OfflineEventQueue();
    for (final key in ['k1', 'k2', 'k3']) {
      await queue.enqueue(QueuedMissionEvent(
        eventType: 'trip_started',
        payload: const {'value': 1},
        idempotencyKey: key,
        queuedAt: DateTime.now(),
      ));
    }

    final sentKeys = <String>[];
    await queue.drain((e) async {
      if (e.idempotencyKey == 'k2') throw Exception('rete assente');
      sentKeys.add(e.idempotencyKey);
    });

    expect(sentKeys,
        ['k1']); // si ferma al primo fallimento, non salta k2 per mandare k3

    final remainingKeys = <String>[];
    await queue.drain((e) async => remainingKeys.add(e.idempotencyKey));
    expect(remainingKeys, ['k2', 'k3']);
  });
}
