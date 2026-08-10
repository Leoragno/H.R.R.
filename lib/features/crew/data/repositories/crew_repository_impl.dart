import '../../domain/entities/crew.dart';
import '../../domain/entities/crew_member.dart';
import '../../domain/repositories/crew_repository.dart';
import '../datasources/crew_remote_datasource.dart';

class CrewRepositoryImpl implements CrewRepository {
  final CrewRemoteDatasource _remote;

  CrewRepositoryImpl(this._remote);

  @override
  Future<List<Crew>> browseCrews({int limit = 30}) async {
    final crews = await _remote.browseCrews(limit: limit);
    return crews.map((c) => c.toEntity()).toList();
  }

  @override
  Future<Crew> crewById(String crewId) async =>
      (await _remote.crewById(crewId)).toEntity();

  @override
  Future<int> memberCount(String crewId) => _remote.memberCount(crewId);

  @override
  Future<List<CrewMember>> members(String crewId) async {
    final members = await _remote.members(crewId);
    return members.map((m) => m.toEntity()).toList();
  }

  @override
  Future<Crew> createCrew({
    required String ownerId,
    required String name,
    required String tag,
    String? description,
  }) async =>
      (await _remote.createCrew(
        ownerId: ownerId,
        name: name,
        tag: tag,
        description: description,
      ))
          .toEntity();

  @override
  Future<void> joinCrew({required String crewId, required String profileId}) =>
      _remote.joinCrew(crewId: crewId, profileId: profileId);

  @override
  Future<void> leaveCrew({required String crewId, required String profileId}) =>
      _remote.leaveCrew(crewId: crewId, profileId: profileId);

  @override
  Future<void> leaveWithSuccession(String crewId) =>
      _remote.leaveWithSuccession(crewId);

  @override
  Future<List<String>> disbandVoterIds(String crewId) =>
      _remote.disbandVoterIds(crewId);

  @override
  Future<bool> castDisbandVote(String crewId) =>
      _remote.castDisbandVote(crewId);

  @override
  Future<void> retractDisbandVote(String crewId) =>
      _remote.retractDisbandVote(crewId);

  @override
  Future<void> setMemberRole({
    required String crewId,
    required String profileId,
    required CrewRole role,
  }) =>
      _remote.setMemberRole(crewId: crewId, profileId: profileId, role: role);

  @override
  Future<void> kickMember({required String crewId, required String profileId}) =>
      _remote.kickMember(crewId: crewId, profileId: profileId);
}
