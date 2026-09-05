import '../entities/radar_bounds.dart';
import '../entities/radar_event.dart';

abstract class RadarRepository {
  /// Velox fisici nella bounding box visibile, uniti da più fonti
  /// indipendenti (Overpass/OpenStreetMap + Open-GATSO-POI, vedi
  /// VeloxSourceMerger) — [RadarEvent.verified] distingue i punti
  /// confermati da entrambe dai punti da fonte singola. Lista vuota se
  /// nessun endpoint è configurato o le richieste falliscono — mai
  /// un'eccezione che risale alla UI.
  Future<List<RadarEvent>> veloxApi(RadarBounds bounds);

  /// Pattuglie nella bounding box visibile (alert pubblici Waze,
  /// categoria POLICE). Stesse garanzie di [veloxApi].
  Future<List<RadarEvent>> pattugliaApi(RadarBounds bounds);

  /// Segnalazioni della community (Velox e Pattuglia insieme), già filtrate
  /// a quelle non scadute (90 minuti) e aggiornate in realtime.
  Stream<List<RadarEvent>> communityReports();

  Future<void> submitCommunityReport({
    required String reporterId,
    required RadarCategory category,
    required double lat,
    required double lon,
  });
}
