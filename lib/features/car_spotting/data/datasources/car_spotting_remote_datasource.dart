import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/spot_comment_model.dart';
import '../models/spot_model.dart';
import '../models/spot_rating_model.dart';

/// Unico punto della feature Car Spotting che importa supabase_flutter.
class CarSpottingRemoteDatasource {
  static const _bucket = 'car-photos';

  final SupabaseClient _client;

  CarSpottingRemoteDatasource(this._client);

  // FK esplicita necessaria: spots ha più relazioni verso profiles
  // (author_id diretta + spot_reactions/spot_saves many-to-many), quindi
  // "profiles(username)" senza disambiguare fallisce con PGRST201
  // ("more than one relationship was found").
  static const _selectWithAuthor = '*, profiles!spots_author_id_fkey(username)';

  Future<List<SpotModel>> feed({int limit = 30}) async {
    final rows = await _client
        .from('spots')
        .select(_selectWithAuthor)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => SpotModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<SpotModel>> topRated({int limit = 20}) async {
    final rows = await _client
        .from('spots')
        .select(_selectWithAuthor)
        .gt('rating_count', 0)
        .order('average_rating', ascending: false)
        .order('rating_count', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => SpotModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<SpotModel> spotById(String spotId) async {
    final row = await _client
        .from('spots')
        .select(_selectWithAuthor)
        .eq('id', spotId)
        .single();
    return SpotModel.fromJson(row);
  }

  Future<SpotModel> publishSpot({
    required String authorId,
    required Uint8List photoBytes,
    required String photoExtension,
    required String make,
    required String model,
    int? year,
    String? caption,
    String? locationLabel,
  }) async {
    final path =
        '$authorId/${DateTime.now().microsecondsSinceEpoch}$photoExtension';
    await _client.storage.from(_bucket).uploadBinary(path, photoBytes);
    final photoUrl = _client.storage.from(_bucket).getPublicUrl(path);

    final row = await _client
        .from('spots')
        .insert({
          'author_id': authorId,
          'photo_url': photoUrl,
          'detected_make': make,
          'detected_model': model,
          'detected_year': year,
          'caption': caption,
          'location_label': locationLabel,
        })
        .select()
        .single();
    return SpotModel.fromJson(row);
  }

  Future<SpotRatingModel?> myRating(
      {required String spotId, required String profileId}) async {
    final rows = await _client
        .from('spot_ratings')
        .select()
        .eq('spot_id', spotId)
        .eq('profile_id', profileId)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return SpotRatingModel.fromJson(list.first as Map<String, dynamic>);
  }

  Future<SpotRatingModel> rateSpot({
    required String spotId,
    required String profileId,
    required double rating,
  }) async {
    final row = await _client
        .from('spot_ratings')
        .upsert(
          {'spot_id': spotId, 'profile_id': profileId, 'rating': rating},
          onConflict: 'spot_id,profile_id',
        )
        .select()
        .single();
    return SpotRatingModel.fromJson(row);
  }

  Future<List<SpotCommentModel>> comments(String spotId,
      {int limit = 50}) async {
    final rows = await _client
        .from('spot_comments')
        .select('*, profiles(username)')
        .eq('spot_id', spotId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => SpotCommentModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<SpotCommentModel> addComment({
    required String spotId,
    required String authorId,
    required String content,
  }) async {
    final row = await _client
        .from('spot_comments')
        .insert({'spot_id': spotId, 'author_id': authorId, 'content': content})
        .select('*, profiles(username)')
        .single();
    return SpotCommentModel.fromJson(row);
  }

  /// RLS (`spots_delete_author`, vedi migration 0001) impedisce già la
  /// cancellazione a chi non è l'autore — nessun filtro `author_id`
  /// aggiuntivo qui necessario, la query fallisce/non tocca righe da sola.
  /// [photoUrl] è quello già noto lato presentation (da [Spot.photoUrl]):
  /// evita un round-trip in più solo per recuperarlo prima di cancellare.
  Future<void> deleteSpot(String spotId, {required String photoUrl}) async {
    await _client.from('spots').delete().eq('id', spotId);
    final path = _pathFromPublicUrl(photoUrl);
    // Best-effort: la riga è già cancellata, l'oggetto Storage orfano non
    // impatta l'utente — non c'è nulla da recuperare se questa fallisce.
    if (path != null) {
      try {
        await _client.storage.from(_bucket).remove([path]);
      } catch (_) {}
    }
  }

  String? _pathFromPublicUrl(String photoUrl) {
    const marker = '/object/public/$_bucket/';
    final idx = photoUrl.indexOf(marker);
    if (idx == -1) return null;
    return photoUrl.substring(idx + marker.length);
  }
}
