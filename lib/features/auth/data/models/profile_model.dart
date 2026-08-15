import '../../domain/entities/app_user.dart';

/// DTO mirroring the `profiles` table row. Converts to/from the
/// domain entity so the rest of the app never touches raw Supabase JSON.
class ProfileModel {
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

  const ProfileModel({
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

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      level: json['level'] as int? ?? 1,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      rep: (json['rep'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Rookie Driver',
      vehicleBrand: json['vehicle_brand'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      country: json['country'] as String?,
      accentColor: json['accent_color'] as String? ?? '#35e0ff',
      mascotId: json['mascot_id'] as String?,
      totalKm: (json['total_km'] as num?)?.toDouble() ?? 0,
      totalTrips: json['total_trips'] as int? ?? 0,
      drivingScore: (json['driving_score'] as num?)?.toDouble() ?? 5.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'level': level,
        'xp': xp,
        'rep': rep,
        'title': title,
        'vehicle_brand': vehicleBrand,
        'vehicle_model': vehicleModel,
        'country': country,
        'accent_color': accentColor,
        'mascot_id': mascotId,
      };

  AppUser toEntity() => AppUser(
        id: id,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        level: level,
        xp: xp,
        rep: rep,
        title: title,
        vehicleBrand: vehicleBrand,
        vehicleModel: vehicleModel,
        country: country,
        accentColor: accentColor,
        mascotId: mascotId,
        totalKm: totalKm,
        totalTrips: totalTrips,
        drivingScore: drivingScore,
      );
}
