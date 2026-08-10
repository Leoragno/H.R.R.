import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/radar_event.dart';
import '../models/crew_report_model.dart';

/// Unico punto della feature Radar che importa supabase_flutter.
class CrewReportsRemoteDatasource {
  final SupabaseClient _client;
  CrewReportsRemoteDatasource(this._client);

  /// Stream realtime delle segnalazioni della crew (righe intere ad ogni
  /// cambio, non diff — stesso comportamento di `.stream()` già usato per
  /// `profiles`). La scadenza a 90 minuti NON è filtrata qui: due
  /// segnalazioni "vecchie" restano nello snapshot finché non arriva un
  /// nuovo insert/delete a far ripartire lo stream — il controller che
  /// consuma questo stream applica un timer periodico per ripulirle
  /// (vedi CrewReportsController).
  Stream<List<CrewReportModel>> watch(String crewId) {
    return _client
        .from('crew_reports')
        .stream(primaryKey: ['id'])
        .eq('crew_id', crewId)
        .order('created_at')
        .map((rows) =>
            rows.map((r) => CrewReportModel.fromJson(r)).toList());
  }

  Future<void> submit({
    required String crewId,
    required String reporterId,
    required RadarCategory category,
    required double lat,
    required double lon,
  }) async {
    await _client.from('crew_reports').insert({
      'crew_id': crewId,
      'reporter_id': reporterId,
      'category': category == RadarCategory.velox ? 'velox' : 'pattuglia',
      'lat': lat,
      'lon': lon,
    });
  }
}
