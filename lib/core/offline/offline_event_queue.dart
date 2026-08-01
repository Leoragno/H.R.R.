import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Voce accodata quando un evento missione non può (ancora) essere
/// confermato dal server. Volutamente disaccoppiata dalla gerarchia
/// [MissionEvent]: al replay serve solo ciò che richiama
/// `record_mission_event`, non l'istanza tipizzata originale.
class QueuedMissionEvent {
  final String eventType;
  final Map<String, dynamic> payload;
  final String idempotencyKey;
  final DateTime queuedAt;

  const QueuedMissionEvent({
    required this.eventType,
    required this.payload,
    required this.idempotencyKey,
    required this.queuedAt,
  });

  Map<String, dynamic> toJson() => {
        'event_type': eventType,
        'payload': payload,
        'idempotency_key': idempotencyKey,
        'queued_at': queuedAt.toIso8601String(),
      };

  factory QueuedMissionEvent.fromJson(Map<String, dynamic> json) =>
      QueuedMissionEvent(
        eventType: json['event_type'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        idempotencyKey: json['idempotency_key'] as String,
        queuedAt: DateTime.parse(json['queued_at'] as String),
      );
}

/// Coda offline persistita su `shared_preferences` (un array JSON su
/// un'unica chiave) — nessuna feature del progetto usa ancora un local DB
/// vero (Hive/sqflite/Drift), e questa coda tiene solo pochi record
/// append-only, non serve altro. Drenata in ordine: ogni evento porta la
/// propria `idempotency_key`, quindi un replay dopo un fallimento
/// parziale (rete caduta a metà drain) non fa mai contare due volte lo
/// stesso evento lato server — niente merge/conflict resolution qui,
/// solo retry.
class OfflineEventQueue {
  static const _prefsKey = 'mission_offline_event_queue';

  Future<List<QueuedMissionEvent>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => QueuedMissionEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _write(List<QueuedMissionEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsKey, jsonEncode(events.map((e) => e.toJson()).toList()));
  }

  Future<void> enqueue(QueuedMissionEvent event) async {
    final events = await _read();
    events.add(event);
    await _write(events);
  }

  /// Invia in ordine tramite [send]; le voci inviate con successo escono
  /// dalla coda. Si ferma al primo fallimento per non processare fuori
  /// ordine — riprova dall'inizio del residuo al prossimo trigger.
  Future<void> drain(
      Future<void> Function(QueuedMissionEvent event) send) async {
    final events = await _read();
    if (events.isEmpty) return;

    var sent = 0;
    for (final event in events) {
      try {
        await send(event);
        sent++;
      } catch (_) {
        break;
      }
    }

    if (sent > 0) {
      await _write(events.sublist(sent));
    }
  }
}
