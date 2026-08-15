import 'package:equatable/equatable.dart';

/// Pure domain entity — no Supabase/Flutter imports here by design.
class AppUser extends Equatable {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final int level;
  final int xp;
  final int rep;
  final String title;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? country;
  final String accentColor;
  final String? mascotId;
  final double totalKm;
  final int totalTrips;
  final double drivingScore;

  const AppUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.level,
    required this.xp,
    required this.rep,
    required this.title,
    this.vehicleBrand,
    this.vehicleModel,
    this.country,
    this.accentColor = '#35e0ff',
    this.mascotId,
    this.totalKm = 0,
    this.totalTrips = 0,
    this.drivingScore = 5.0,
  });

  @override
  List<Object?> get props => [
        id,
        username,
        displayName,
        avatarUrl,
        level,
        xp,
        rep,
        title,
        vehicleBrand,
        vehicleModel,
        country,
        accentColor,
        mascotId,
        totalKm,
        totalTrips,
        drivingScore,
      ];
}
