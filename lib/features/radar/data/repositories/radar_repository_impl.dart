import '../../domain/entities/radar_bounds.dart';
import '../../domain/entities/radar_event.dart';
import '../../domain/repositories/radar_repository.dart';
import '../datasources/community_reports_remote_datasource.dart';
import '../datasources/open_gatso_poi_remote_datasource.dart';
import '../datasources/overpass_remote_datasource.dart';
import '../datasources/waze_remote_datasource.dart';
import '../services/velox_source_merger.dart';

class RadarRepositoryImpl implements RadarRepository {
  final OverpassRemoteDatasource _overpass;
  final OpenGatsoPoiRemoteDatasource _openGatsoPoi;
  final WazeRemoteDatasource _waze;
  final CommunityReportsRemoteDatasource _communityReports;

  RadarRepositoryImpl(
    this._overpass,
    this._openGatsoPoi,
    this._waze,
    this._communityReports,
  );

  @override
  Future<List<RadarEvent>> veloxApi(RadarBounds bounds) async {
    // Nessuna fonte è verità assoluta da sola: Overpass/OSM è la fonte
    // primaria, Open-GATSO-POI incrocia gli stessi punti (o ne aggiunge di
    // suoi) — vedi VeloxSourceMerger per come diventa "verificato" o meno.
    final results = await Future.wait([
      _overpass.veloxCameras(bounds),
      _openGatsoPoi.veloxCameras(bounds),
    ]);
    return VeloxSourceMerger.merge(results[0], results[1]);
  }

  @override
  Future<List<RadarEvent>> pattugliaApi(RadarBounds bounds) =>
      _waze.policeAlerts(bounds);

  @override
  Stream<List<RadarEvent>> communityReports() => _communityReports
      .watch()
      .map((rows) => rows.map((r) => r.toEntity()).toList());

  @override
  Future<void> submitCommunityReport({
    required String reporterId,
    required RadarCategory category,
    required double lat,
    required double lon,
  }) =>
      _communityReports.submit(
        reporterId: reporterId,
        category: category,
        lat: lat,
        lon: lon,
      );
}
