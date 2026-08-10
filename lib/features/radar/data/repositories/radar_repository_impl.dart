import '../../domain/entities/radar_bounds.dart';
import '../../domain/entities/radar_event.dart';
import '../../domain/repositories/radar_repository.dart';
import '../datasources/crew_reports_remote_datasource.dart';
import '../datasources/overpass_remote_datasource.dart';
import '../datasources/waze_remote_datasource.dart';

class RadarRepositoryImpl implements RadarRepository {
  final OverpassRemoteDatasource _overpass;
  final WazeRemoteDatasource _waze;
  final CrewReportsRemoteDatasource _crewReports;

  RadarRepositoryImpl(this._overpass, this._waze, this._crewReports);

  @override
  Future<List<RadarEvent>> veloxApi(RadarBounds bounds) =>
      _overpass.veloxCameras(bounds);

  @override
  Future<List<RadarEvent>> pattugliaApi(RadarBounds bounds) =>
      _waze.policeAlerts(bounds);

  @override
  Stream<List<RadarEvent>> crewReports(String crewId) => _crewReports
      .watch(crewId)
      .map((rows) => rows.map((r) => r.toEntity()).toList());

  @override
  Future<void> submitCrewReport({
    required String crewId,
    required String reporterId,
    required RadarCategory category,
    required double lat,
    required double lon,
  }) =>
      _crewReports.submit(
        crewId: crewId,
        reporterId: reporterId,
        category: category,
        lat: lat,
        lon: lon,
      );
}
