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
  final String? crewId;

  const AppUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.level,
    required this.xp,
    required this.rep,
    required this.title,
    this.crewId,
  });

  @override
  List<Object?> get props =>
      [id, username, displayName, avatarUrl, level, xp, rep, title, crewId];
}
