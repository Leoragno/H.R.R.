import 'package:equatable/equatable.dart';

/// Stagione attiva — riga `season`. Solo metadati (nome/finestra); XP e
/// livello mostrati nell'header Missions restano quelli del profilo
/// (`myProfileProvider`), non duplicati in un contatore stagionale
/// separato che il DB non traccia ancora.
class Season extends Equatable {
  final String id;
  final String code;
  final String name;
  final DateTime startsAt;
  final DateTime endsAt;

  const Season({
    required this.id,
    required this.code,
    required this.name,
    required this.startsAt,
    required this.endsAt,
  });

  @override
  List<Object?> get props => [id, code, name, startsAt, endsAt];
}
