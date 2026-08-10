import 'package:equatable/equatable.dart';

/// Le due categorie di evento monitorate nella sezione Guida.
enum RadarCategory { velox, pattuglia }

/// Da dove arriva l'evento — determina colore (arancione=api, ciano=crew)
/// e in parte l'icona (vedi radar_icons.dart).
enum RadarSource { api, crew }

/// Un singolo punto Velox/Pattuglia da mostrare sulla mappa e da usare
/// per l'avviso di prossimità durante DRIVE. Unifica sia i punti fissi
/// (Overpass/Waze, `reportedAt` null: non hanno una "scadenza") sia le
/// segnalazioni di crew (`reportedAt` non null, valide 90 minuti — vedi
/// [isExpired]).
class RadarEvent extends Equatable {
  final String id;
  final RadarCategory category;
  final RadarSource source;
  final double lat;
  final double lon;
  final DateTime? reportedAt;

  const RadarEvent({
    required this.id,
    required this.category,
    required this.source,
    required this.lat,
    required this.lon,
    this.reportedAt,
  });

  static const validity = Duration(minutes: 90);

  bool isExpired(DateTime now) {
    final at = reportedAt;
    if (at == null) return false; // punto fisso: non scade mai
    return now.difference(at) > validity;
  }

  @override
  List<Object?> get props => [id, category, source, lat, lon, reportedAt];
}
