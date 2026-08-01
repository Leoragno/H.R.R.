import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Evento di dominio pubblicato da una feature qualsiasi verso il Mission
/// Engine (vedi mission_event_bus.dart). Nessuna feature deve contenere
/// logica di missione al suo interno: pubblica un evento sul bus e basta.
///
/// `idempotencyKey` è generata alla creazione dell'evento (non al momento
/// dell'invio): è la stessa chiave sia nel tentativo online sia in un
/// eventuale replay dalla coda offline, così `record_mission_event()`
/// lato server (dedup su `mission_event_log.idempotency_key`) non conta
/// mai due volte lo stesso accadimento.
sealed class MissionEvent {
  /// Solo per bookkeeping locale (coda offline/debug) — mai inviato alla
  /// RPC, che deriva sempre il profilo da `auth.uid()` lato server.
  final String profileId;
  final String idempotencyKey;
  final DateTime occurredAt;

  MissionEvent({
    required this.profileId,
    String? idempotencyKey,
    DateTime? occurredAt,
  })  : idempotencyKey = idempotencyKey ?? _uuid.v4(),
        occurredAt = occurredAt ?? DateTime.now();

  /// Deve combaciare con `missions.target_metric` lato DB.
  String get type;

  /// Quanto questo evento fa avanzare `mission_progress.current_value`.
  /// Di default 1 (un'occorrenza singola, es. "una foto caricata").
  double get value => 1;

  Map<String, dynamic> toPayload() => {'value': value};
}

class TripCompleted extends MissionEvent {
  final double distanceKm;

  TripCompleted({
    required super.profileId,
    required this.distanceKm,
    super.idempotencyKey,
    super.occurredAt,
  });

  @override
  String get type => 'trip_completed';

  @override
  double get value => distanceKm;
}

class TripStarted extends MissionEvent {
  TripStarted(
      {required super.profileId, super.idempotencyKey, super.occurredAt});

  @override
  String get type => 'trip_started';
}

class PhotoUploaded extends MissionEvent {
  PhotoUploaded(
      {required super.profileId, super.idempotencyKey, super.occurredAt});

  @override
  String get type => 'photo_uploaded';
}

class LikeReceived extends MissionEvent {
  LikeReceived(
      {required super.profileId, super.idempotencyKey, super.occurredAt});

  @override
  String get type => 'like_received';
}

class CommentAdded extends MissionEvent {
  CommentAdded(
      {required super.profileId, super.idempotencyKey, super.occurredAt});

  @override
  String get type => 'comment_added';
}

class CityVisited extends MissionEvent {
  final String? cityName;

  CityVisited(
      {required super.profileId,
      this.cityName,
      super.idempotencyKey,
      super.occurredAt});

  @override
  String get type => 'city_visited';

  @override
  Map<String, dynamic> toPayload() =>
      {...super.toPayload(), if (cityName != null) 'city_name': cityName};
}

class PoiDiscovered extends MissionEvent {
  final String? poiName;

  PoiDiscovered(
      {required super.profileId,
      this.poiName,
      super.idempotencyKey,
      super.occurredAt});

  @override
  String get type => 'poi_discovered';

  @override
  Map<String, dynamic> toPayload() =>
      {...super.toPayload(), if (poiName != null) 'poi_name': poiName};
}

class FriendAdded extends MissionEvent {
  FriendAdded(
      {required super.profileId, super.idempotencyKey, super.occurredAt});

  @override
  String get type => 'friend_added';
}

class CrewJoined extends MissionEvent {
  CrewJoined(
      {required super.profileId, super.idempotencyKey, super.occurredAt});

  @override
  String get type => 'crew_joined';
}

class CarSpotted extends MissionEvent {
  /// Marca rilevata (es. "Ferrari") — portata nel payload per un futuro
  /// matching mirato lato server; il progress engine di questa consegna
  /// tratta ogni evento car_spotted come +1 generico, senza filtrare per
  /// marca (missioni tipo "Ferrari Hunter" restano da completare a mano
  /// finché il matching per marca non viene aggiunto a record_mission_event).
  final String? make;

  CarSpotted(
      {required super.profileId,
      this.make,
      super.idempotencyKey,
      super.occurredAt});

  @override
  String get type => 'car_spotted';

  @override
  Map<String, dynamic> toPayload() =>
      {...super.toPayload(), if (make != null) 'make': make};
}

class ReactionReceived extends MissionEvent {
  final String reactionType;

  ReactionReceived({
    required super.profileId,
    required this.reactionType,
    super.idempotencyKey,
    super.occurredAt,
  });

  @override
  String get type => 'reaction_received';

  @override
  Map<String, dynamic> toPayload() =>
      {...super.toPayload(), 'reaction_type': reactionType};
}
