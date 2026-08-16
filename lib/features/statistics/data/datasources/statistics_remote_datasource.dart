import 'package:supabase_flutter/supabase_flutter.dart';

/// Unico punto della feature Statistiche che importa supabase_flutter —
/// tutto il resto dei dati viene riusato dai provider di altre feature
/// (profilo, achievement, territorio, classifica, missioni): qui c'è solo
/// il conteggio spot personali (che oggi non esiste altrove, il feed è
/// limitato alle ultime 30 righe, vedi car_spotting_provider.dart) e
/// l'aggregato delle statistiche di guida per-viaggio (0032_trip_motion_
/// stats_totals.sql).
class StatisticsRemoteDatasource {
  final SupabaseClient _client;

  StatisticsRemoteDatasource(this._client);

  Future<int> mySpotCount(String profileId) async {
    final rows = await _client
        .from('spots')
        .select('id')
        .eq('author_id', profileId);
    return (rows as List).length;
  }

  /// Riga singola sempre presente (anche con zero viaggi: tutti i campi
  /// numeric restano null dall'aggregato SQL, mai un errore/riga assente).
  Future<Map<String, dynamic>> tripMotionTotals() async {
    final res = await _client.rpc('trip_motion_stats_totals');
    final rows = res as List;
    return rows.isEmpty
        ? const {}
        : Map<String, dynamic>.from(rows.first as Map);
  }
}
