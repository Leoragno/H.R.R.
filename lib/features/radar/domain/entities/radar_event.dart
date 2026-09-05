import 'package:equatable/equatable.dart';

/// Le due categorie di evento monitorate nella sezione Guida.
enum RadarCategory { velox, pattuglia }

/// Da dove arriva l'evento — determina colore (arancione=api,
/// ciano=community) e in parte l'icona (vedi radar_icons.dart).
enum RadarSource { api, community }

/// Un singolo punto Velox/Pattuglia da mostrare sulla mappa e da usare
/// per l'avviso di prossimità durante DRIVE. Unifica sia i punti fissi
/// (Overpass/Waze, `reportedAt` null: non hanno una "scadenza") sia le
/// segnalazioni della community (`reportedAt` non null, valide 90 minuti —
/// vedi [isExpired]).
class RadarEvent extends Equatable {
  final String id;
  final RadarCategory category;
  final RadarSource source;
  final double lat;
  final double lon;
  final DateTime? reportedAt;

  /// Per i velox `source == api`: true se il punto è confermato da più di
  /// una fonte indipendente (oggi Overpass/OSM + Open-GATSO-POI, vedi
  /// [VeloxSourceMerger]), false se viene da una sola fonte non
  /// incrociata. Nessun database di velox è "verità assoluta" da solo —
  /// la UI distingue le due situazioni con la stessa icona a opacità
  /// diversa (mai un colore nuovo, vedi DESIGN.md). Irrilevante per
  /// pattuglie (fonte singola Waze, per natura non incrociabile: sono
  /// mobili) e per le segnalazioni community: per queste resta sempre
  /// `true` così l'opacità non cambia rispetto a oggi.
  final bool verified;

  const RadarEvent({
    required this.id,
    required this.category,
    required this.source,
    required this.lat,
    required this.lon,
    this.reportedAt,
    this.verified = true,
  });

  static const validity = Duration(minutes: 90);

  bool isExpired(DateTime now) {
    final at = reportedAt;
    if (at == null) return false; // punto fisso: non scade mai
    return now.difference(at) > validity;
  }

  @override
  List<Object?> get props =>
      [id, category, source, lat, lon, reportedAt, verified];
}
