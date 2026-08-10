import 'package:equatable/equatable.dart';

/// Riga `crews`. `level`/`xp`/`member_count` esistono in schema ma non
/// sono ancora alimentati da nessun trigger/RPC lato server (restano ai
/// valori di default) — non esposti qui finché non c'è una vera
/// progressione crew da mostrare; il conteggio membri reale si ottiene
/// contando le righe `crew_members` (vedi [CrewRepository.memberCount]).
class Crew extends Equatable {
  final String id;
  final String name;
  final String tag;
  final String? description;
  final String? emblemUrl;
  final String ownerId;
  final DateTime createdAt;

  const Crew({
    required this.id,
    required this.name,
    required this.tag,
    this.description,
    this.emblemUrl,
    required this.ownerId,
    required this.createdAt,
  });

  @override
  List<Object?> get props =>
      [id, name, tag, description, emblemUrl, ownerId, createdAt];
}
