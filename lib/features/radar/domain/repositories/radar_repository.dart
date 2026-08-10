import '../entities/radar_bounds.dart';
import '../entities/radar_event.dart';

abstract class RadarRepository {
  /// Velox fisici nella bounding box visibile (Overpass/OpenStreetMap).
  /// Lista vuota se l'endpoint non è configurato o la richiesta fallisce
  /// — mai un'eccezione che risale alla UI.
  Future<List<RadarEvent>> veloxApi(RadarBounds bounds);

  /// Pattuglie nella bounding box visibile (alert pubblici Waze,
  /// categoria POLICE). Stesse garanzie di [veloxApi].
  Future<List<RadarEvent>> pattugliaApi(RadarBounds bounds);

  /// Segnalazioni della crew [crewId] (Velox e Pattuglia insieme), già
  /// filtrate a quelle non scadute (90 minuti) e aggiornate in realtime.
  Stream<List<RadarEvent>> crewReports(String crewId);

  Future<void> submitCrewReport({
    required String crewId,
    required String reporterId,
    required RadarCategory category,
    required double lat,
    required double lon,
  });
}
