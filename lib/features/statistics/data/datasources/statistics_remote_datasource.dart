import 'package:supabase_flutter/supabase_flutter.dart';

/// Unico punto della feature Statistiche che importa supabase_flutter —
/// tutto il resto dei dati viene riusato dai provider di altre feature
/// (profilo, achievement, territorio, classifica, missioni), qui c'è solo
/// il conteggio spot personali, che oggi non esiste altrove (il feed è
/// limitato alle ultime 30 righe, vedi car_spotting_provider.dart).
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
}
