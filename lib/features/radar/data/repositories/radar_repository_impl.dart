import '../../domain/entities/radar_bounds.dart';
import '../../domain/entities/radar_event.dart';
import '../../domain/repositories/radar_repository.dart';
import '../datasources/community_reports_remote_datasource.dart';
import '../datasources/overpass_remote_datasource.dart';
import '../datasources/waze_remote_datasource.dart';

class RadarRepositoryImpl implements RadarRepository {
  final OverpassRemoteDatasource _overpass;
  final WazeRemoteDatasource _waze;
  final CommunityReportsRemoteDatasource _communityReports;

  RadarRepositoryImpl(this._overpass, this._waze, this._communityReports);

  @override
  Future<List<RadarEvent>> veloxApi(RadarBounds bounds) =>
      _overpass.veloxCameras(bounds);

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
