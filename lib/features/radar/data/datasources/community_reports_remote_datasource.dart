import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/radar_event.dart';
import '../models/community_report_model.dart';

/// Unico punto della feature Radar che importa supabase_flutter.
class CommunityReportsRemoteDatasource {
  final SupabaseClient _client;
  CommunityReportsRemoteDatasource(this._client);

  /// Stream realtime delle segnalazioni community (righe intere ad ogni
  /// cambio, non diff — stesso comportamento di `.stream()` già usato per
  /// `profiles`). La scadenza a 90 minuti NON è filtrata qui: due
  /// segnalazioni "vecchie" restano nello snapshot finché non arriva un
  /// nuovo insert/delete a far ripartire lo stream — il controller che
  /// consuma questo stream applica un timer periodico per ripulirle
  /// (vedi CommunityReportsController).
  Stream<List<CommunityReportModel>> watch() {
    return _client
        .from('community_reports')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) =>
            rows.map((r) => CommunityReportModel.fromJson(r)).toList());
  }

  Future<void> submit({
    required String reporterId,
    required RadarCategory category,
    required double lat,
    required double lon,
  }) async {
    await _client.from('community_reports').insert({
      'reporter_id': reporterId,
      'category': category == RadarCategory.velox ? 'velox' : 'pattuglia',
      'lat': lat,
      'lon': lon,
    });
  }
}
