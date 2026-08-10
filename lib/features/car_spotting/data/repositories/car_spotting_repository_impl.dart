import 'dart:typed_data';

import '../../domain/entities/spot.dart';
import '../../domain/entities/spot_comment.dart';
import '../../domain/entities/spot_rating.dart';
import '../../domain/repositories/car_spotting_repository.dart';
import '../datasources/car_spotting_remote_datasource.dart';

class CarSpottingRepositoryImpl implements CarSpottingRepository {
  final CarSpottingRemoteDatasource _remote;
  final String Function() _currentProfileId;

  CarSpottingRepositoryImpl(this._remote, this._currentProfileId);

  @override
  Future<List<Spot>> feed({int limit = 30}) async {
    final spots = await _remote.feed(limit: limit);
    return spots.map((s) => s.toEntity()).toList();
  }

  @override
  Future<List<Spot>> topRated({int limit = 20}) async {
    final spots = await _remote.topRated(limit: limit);
    return spots.map((s) => s.toEntity()).toList();
  }

  @override
  Future<Spot> spotById(String spotId) async =>
      (await _remote.spotById(spotId)).toEntity();

  @override
  Future<Spot> publishSpot({
    required Uint8List photoBytes,
    required String photoExtension,
    required String make,
    required String model,
    int? year,
    String? caption,
    String? locationLabel,
  }) async {
    final spot = await _remote.publishSpot(
      authorId: _currentProfileId(),
      photoBytes: photoBytes,
      photoExtension: photoExtension,
      make: make,
      model: model,
      year: year,
      caption: caption,
      locationLabel: locationLabel,
    );
    return spot.toEntity();
  }

  @override
  Future<SpotRating?> myRating(String spotId) async {
    final rating =
        await _remote.myRating(spotId: spotId, profileId: _currentProfileId());
    return rating?.toEntity();
  }

  @override
  Future<SpotRating> rateSpot(
      {required String spotId, required double rating}) async {
    final result = await _remote.rateSpot(
        spotId: spotId, profileId: _currentProfileId(), rating: rating);
    return result.toEntity();
  }

  @override
  Future<List<SpotComment>> comments(String spotId) async {
    final comments = await _remote.comments(spotId);
    return comments.map((c) => c.toEntity()).toList();
  }

  @override
  Future<SpotComment> addComment(
      {required String spotId, required String content}) async {
    final comment = await _remote.addComment(
        spotId: spotId, authorId: _currentProfileId(), content: content);
    return comment.toEntity();
  }

  @override
  Future<void> deleteSpot({required String spotId, required String photoUrl}) =>
      _remote.deleteSpot(spotId, photoUrl: photoUrl);
}
