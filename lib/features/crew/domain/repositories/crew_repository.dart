import '../entities/crew.dart';
import '../entities/crew_member.dart';

abstract class CrewRepository {
  Future<List<Crew>> browseCrews({int limit = 30});
  Future<Crew> crewById(String crewId);
  Future<int> memberCount(String crewId);
  Future<List<CrewMember>> members(String crewId);

  Future<Crew> createCrew({
    required String ownerId,
    required String name,
    required String tag,
    String? description,
  });

  Future<void> joinCrew({required String crewId, required String profileId});
  Future<void> leaveCrew({required String crewId, required String profileId});

  /// Il chiamante lascia la crew. Se è il proprietario e restano altri
  /// membri, la proprietà passa automaticamente al membro più anziano
  /// (RPC `crew_leave`, vedi 0013_crew_disband_and_succession.sql).
  Future<void> leaveWithSuccession(String crewId);

  /// Profili che hanno già votato per sciogliere [crewId] (votazione
  /// attiva se non vuota).
  Future<List<String>> disbandVoterIds(String crewId);

  /// Registra il voto del chiamante per sciogliere la crew. Ritorna
  /// true se con questo voto si è raggiunta l'unanimità (crew eliminata).
  Future<bool> castDisbandVote(String crewId);

  Future<void> retractDisbandVote(String crewId);

  Future<void> setMemberRole({
    required String crewId,
    required String profileId,
    required CrewRole role,
  });

  Future<void> kickMember({required String crewId, required String profileId});
}
