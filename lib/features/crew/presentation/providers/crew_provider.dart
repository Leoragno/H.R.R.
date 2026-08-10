import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/crew_remote_datasource.dart';
import '../../data/repositories/crew_repository_impl.dart';
import '../../domain/entities/crew.dart';
import '../../domain/entities/crew_member.dart';
import '../../domain/repositories/crew_repository.dart';

part 'crew_provider.g.dart';

// ---- DI wiring ----------------------------------------------------------

@riverpod
CrewRemoteDatasource crewRemoteDatasource(CrewRemoteDatasourceRef ref) {
  return CrewRemoteDatasource(ref.watch(supabaseClientProvider));
}

@riverpod
CrewRepository crewRepository(CrewRepositoryRef ref) {
  return CrewRepositoryImpl(ref.watch(crewRemoteDatasourceProvider));
}

// ---- Lettura --------------------------------------------------------------

/// Crew dell'utente corrente, derivata da `profiles.crew_id` (già
/// realtime via [myProfileProvider]): null se non fa parte di nessuna
/// crew. Non serve invalidarla manualmente dopo join/leave/create — lo
/// stream del profilo emette da solo il nuovo `crew_id`.
@riverpod
Future<Crew?> myCrew(MyCrewRef ref) async {
  final crewId = (await ref.watch(myProfileProvider.future))?.crewId;
  if (crewId == null) return null;
  return ref.watch(crewRepositoryProvider).crewById(crewId);
}

@riverpod
Future<List<CrewMember>> crewMembers(CrewMembersRef ref, String crewId) {
  return ref.watch(crewRepositoryProvider).members(crewId);
}

@riverpod
Future<int> crewMemberCount(CrewMemberCountRef ref, String crewId) {
  return ref.watch(crewRepositoryProvider).memberCount(crewId);
}

@riverpod
Future<List<Crew>> browseCrews(BrowseCrewsRef ref) {
  return ref.watch(crewRepositoryProvider).browseCrews();
}

/// Profili che hanno votato per sciogliere [crewId] — lista vuota =
/// nessuna votazione attiva.
@riverpod
Future<List<String>> crewDisbandVoters(CrewDisbandVotersRef ref, String crewId) {
  return ref.watch(crewRepositoryProvider).disbandVoterIds(crewId);
}

// ---- Azioni -----------------------------------------------------------

/// Stato di loading/errore delle azioni (crea/entra/lascia/gestisci
/// membri) indipendente dai provider di lettura sopra — la UI lo usa
/// solo per disabilitare i pulsanti durante una richiesta in corso.
@riverpod
class CrewActionsController extends _$CrewActionsController {
  @override
  FutureOr<void> build() {
    // no-op initial state
  }

  Future<void> createCrew({
    required String name,
    required String tag,
    String? description,
  }) async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(crewRepositoryProvider).createCrew(
            ownerId: userId,
            name: name,
            tag: tag,
            description: description,
          );
      ref.invalidate(browseCrewsProvider);
    });
  }

  Future<void> join(String crewId) async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(crewRepositoryProvider)
          .joinCrew(crewId: crewId, profileId: userId);
      ref.invalidate(crewMembersProvider(crewId));
      ref.invalidate(crewMemberCountProvider(crewId));
    });
  }

  Future<void> leave(String crewId) async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(crewRepositoryProvider)
          .leaveCrew(crewId: crewId, profileId: userId);
      ref.invalidate(crewMembersProvider(crewId));
      ref.invalidate(crewMemberCountProvider(crewId));
    });
  }

  /// Il proprietario lascia una crew con altri membri: la RPC promuove
  /// il membro più anziano come nuovo proprietario prima di rimuoverlo.
  Future<void> leaveWithSuccession(String crewId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(crewRepositoryProvider).leaveWithSuccession(crewId);
      ref.invalidate(crewMembersProvider(crewId));
      ref.invalidate(crewMemberCountProvider(crewId));
    });
  }

  /// Ritorna true se con questo voto la crew è stata sciolta
  /// (unanimità raggiunta) — la UI naviga via, non deve invalidare
  /// nient'altro: `myProfileProvider` è già uno stream realtime e
  /// riflette da solo il crew_id azzerato.
  Future<bool> castDisbandVote(String crewId) async {
    state = const AsyncLoading();
    var disbanded = false;
    state = await AsyncValue.guard(() async {
      disbanded = await ref.read(crewRepositoryProvider).castDisbandVote(crewId);
      if (!disbanded) {
        ref.invalidate(crewDisbandVotersProvider(crewId));
      }
    });
    return disbanded;
  }

  Future<void> retractDisbandVote(String crewId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(crewRepositoryProvider).retractDisbandVote(crewId);
      ref.invalidate(crewDisbandVotersProvider(crewId));
    });
  }

  Future<void> setRole({
    required String crewId,
    required String profileId,
    required CrewRole role,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(crewRepositoryProvider)
          .setMemberRole(crewId: crewId, profileId: profileId, role: role);
      ref.invalidate(crewMembersProvider(crewId));
    });
  }

  Future<void> kick({required String crewId, required String profileId}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(crewRepositoryProvider)
          .kickMember(crewId: crewId, profileId: profileId);
      ref.invalidate(crewMembersProvider(crewId));
      ref.invalidate(crewMemberCountProvider(crewId));
    });
  }
}
