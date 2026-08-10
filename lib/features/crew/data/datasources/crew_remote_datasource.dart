import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/crew_member.dart';
import '../models/crew_member_model.dart';
import '../models/crew_model.dart';

const _memberSelect = '*, profiles(username, display_name, avatar_url, level)';

/// Unico punto della feature Crew che importa supabase_flutter.
class CrewRemoteDatasource {
  final SupabaseClient _client;

  CrewRemoteDatasource(this._client);

  Future<List<CrewModel>> browseCrews({int limit = 30}) async {
    final rows = await _client
        .from('crews')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => CrewModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<CrewModel> crewById(String crewId) async {
    final row = await _client.from('crews').select().eq('id', crewId).single();
    return CrewModel.fromJson(row);
  }

  // `crews.member_count` non è mai aggiornato lato server (nessun
  // trigger): il conteggio reale si ottiene solo contando le righe
  // crew_members, mai fidandosi della colonna.
  Future<int> memberCount(String crewId) async {
    final rows = await _client
        .from('crew_members')
        .select('profile_id')
        .eq('crew_id', crewId);
    return (rows as List).length;
  }

  Future<List<CrewMemberModel>> members(String crewId) async {
    final rows = await _client
        .from('crew_members')
        .select(_memberSelect)
        .eq('crew_id', crewId)
        .order('joined_at'); // il proprietario è sempre il primo iscritto
    return (rows as List)
        .map((r) => CrewMemberModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<CrewModel> createCrew({
    required String ownerId,
    required String name,
    required String tag,
    String? description,
  }) async {
    final crewRow = await _client
        .from('crews')
        .insert({
          'name': name,
          'tag': tag,
          'description': description,
          'owner_id': ownerId,
        })
        .select()
        .single();
    final crew = CrewModel.fromJson(crewRow);

    // Nessuna RPC atomica per la creazione: se questo insert fallisse
    // dopo che la crew è stata creata resterebbe una crew "orfana" senza
    // membri (edge case raro, nessuna policy di delete esiste per
    // ripulirla lato client — accettato per questa versione).
    await _client.from('crew_members').insert({
      'crew_id': crew.id,
      'profile_id': ownerId,
      'role': 'owner',
    });
    await _client.from('profiles').update({'crew_id': crew.id}).eq('id', ownerId);
    return crew;
  }

  Future<void> joinCrew({
    required String crewId,
    required String profileId,
  }) async {
    await _client
        .from('crew_members')
        .insert({'crew_id': crewId, 'profile_id': profileId});
    await _client.from('profiles').update({'crew_id': crewId}).eq('id', profileId);
  }

  Future<void> leaveCrew({
    required String crewId,
    required String profileId,
  }) async {
    await _client
        .from('crew_members')
        .delete()
        .eq('crew_id', crewId)
        .eq('profile_id', profileId);
    await _client.from('profiles').update({'crew_id': null}).eq('id', profileId);
  }

  // RPC `crew_leave` (0013_crew_disband_and_succession.sql): gestisce
  // anche il trasferimento di proprietà se il chiamante è owner e
  // restano altri membri — un semplice delete client-side non basta,
  // servirebbe comunque modificare crews.owner_id/crew_members.role di
  // un ALTRO utente, cosa che le RLS negano a chiunque non sia owner.
  Future<void> leaveWithSuccession(String crewId) async {
    await _client.rpc('crew_leave', params: {'p_crew_id': crewId});
  }

  Future<List<String>> disbandVoterIds(String crewId) async {
    final rows = await _client
        .from('crew_disband_votes')
        .select('profile_id')
        .eq('crew_id', crewId);
    return (rows as List).map((r) => r['profile_id'] as String).toList();
  }

  Future<bool> castDisbandVote(String crewId) async {
    final res = await _client
        .rpc('crew_cast_disband_vote', params: {'p_crew_id': crewId});
    final row = res is List
        ? Map<String, dynamic>.from(res.first as Map)
        : Map<String, dynamic>.from(res as Map);
    return row['disbanded'] as bool;
  }

  Future<void> retractDisbandVote(String crewId) async {
    await _client
        .rpc('crew_retract_disband_vote', params: {'p_crew_id': crewId});
  }

  // Richiede la policy "crew_members_update_owner" (0010_crew_members_
  // management.sql): solo il proprietario della crew può eseguirla.
  Future<void> setMemberRole({
    required String crewId,
    required String profileId,
    required CrewRole role,
  }) async {
    await _client
        .from('crew_members')
        .update({'role': role.apiValue})
        .eq('crew_id', crewId)
        .eq('profile_id', profileId);
  }

  Future<void> kickMember({
    required String crewId,
    required String profileId,
  }) async {
    await _client
        .from('crew_members')
        .delete()
        .eq('crew_id', crewId)
        .eq('profile_id', profileId);
    await _client.from('profiles').update({'crew_id': null}).eq('id', profileId);
  }
}
