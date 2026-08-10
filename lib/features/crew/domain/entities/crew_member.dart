import 'package:equatable/equatable.dart';

/// Colonna `role` di `crew_members` — stesso set di valori del check
/// constraint lato DB (`0001_init.sql`).
enum CrewRole {
  owner,
  officer,
  member;

  static CrewRole fromApi(String value) => switch (value) {
        'owner' => CrewRole.owner,
        'officer' => CrewRole.officer,
        _ => CrewRole.member,
      };

  String get apiValue => switch (this) {
        CrewRole.owner => 'owner',
        CrewRole.officer => 'officer',
        CrewRole.member => 'member',
      };

  String get label => switch (this) {
        CrewRole.owner => 'Proprietario',
        CrewRole.officer => 'Officer',
        CrewRole.member => 'Membro',
      };
}

/// Riga `crew_members` arricchita col profilo del membro (join lato
/// query, vedi `crew_remote_datasource.dart`) — evita un giro di query
/// per utente per mostrare la lista membri.
class CrewMember extends Equatable {
  final String profileId;
  final String crewId;
  final CrewRole role;
  final DateTime joinedAt;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final int level;

  const CrewMember({
    required this.profileId,
    required this.crewId,
    required this.role,
    required this.joinedAt,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.level,
  });

  @override
  List<Object?> get props => [
        profileId,
        crewId,
        role,
        joinedAt,
        username,
        displayName,
        avatarUrl,
        level,
      ];
}
