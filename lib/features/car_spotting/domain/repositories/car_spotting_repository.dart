import 'dart:typed_data';

import '../entities/spot.dart';
import '../entities/spot_comment.dart';
import '../entities/spot_rating.dart';

/// Contratto Car Spotting. Presentation/domain dipendono solo da questa
/// interfaccia — mai da `car_spotting_remote_datasource.dart` direttamente.
abstract class CarSpottingRepository {
  /// Feed pubblico, più recenti prima.
  Future<List<Spot>> feed({int limit = 30});

  /// Solo spot con almeno un voto, ordinati per media stelle (poi per
  /// numero voti a parità di media) — nessuna soglia minima di voti.
  Future<List<Spot>> topRated({int limit = 20});

  Future<Spot> spotById(String spotId);

  /// Carica la foto su Storage (bucket `car-photos`) e inserisce la riga
  /// `spots`. Ritorna lo spot pubblicato. `photoBytes` è già compressa
  /// lato presentation (dominio non conosce image_picker/Flutter).
  Future<Spot> publishSpot({
    required Uint8List photoBytes,
    required String photoExtension,
    required String make,
    required String model,
    int? year,
    String? caption,
    String? locationLabel,
  });

  /// Il proprio voto per uno spot, se esiste (RLS: solo il voto di
  /// auth.uid() è leggibile).
  Future<SpotRating?> myRating(String spotId);

  /// Upsert del voto (insert se assente, update se già votato) — un solo
  /// voto per utente per spot, modificabile.
  Future<SpotRating> rateSpot({required String spotId, required double rating});

  Future<List<SpotComment>> comments(String spotId);

  Future<SpotComment> addComment(
      {required String spotId, required String content});

  /// Cancella uno spot (solo l'autore può, via RLS) e ripulisce la foto
  /// dal bucket Storage.
  Future<void> deleteSpot({required String spotId, required String photoUrl});
}
