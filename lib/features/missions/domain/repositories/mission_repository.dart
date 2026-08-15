import '../../../../core/events/mission_event.dart';
import '../entities/mission.dart';
import '../entities/mission_claim.dart';
import '../entities/mission_progress.dart';
import '../entities/season.dart';

/// Contratto Missions. Presentation/domain dipendono solo da questa
/// interfaccia — mai da `mission_remote_datasource.dart` direttamente.
abstract class MissionRepository {
  /// Missioni attualmente visibili al chiamante (le secret non ancora
  /// completate sono già escluse lato RLS, non serve filtrarle qui).
  Future<List<Mission>> activeMissions({MissionType? type});

  Future<List<MissionProgress>> myProgress();

  /// Id delle missioni già riscattate dal chiamante — serve alla UI per
  /// distinguere "pronta da riscattare" da "già riscattata" (mission_progress
  /// non porta questa informazione, vive in mission_claims).
  Future<List<String>> myClaimedMissionIds();

  /// Stream realtime del progresso — richiede `mission_progress` nella
  /// pubblicazione `supabase_realtime` (aggiunta in 0003_mission_engine.sql).
  Stream<List<MissionProgress>> watchMyProgress();

  /// Chiama la RPC `record_mission_event`: il server ricalcola il
  /// progresso dai fatti grezzi dell'evento (mai un progress delta
  /// calcolato dal client). Sicura da richiamare più volte con la stessa
  /// `idempotencyKey` dell'evento (replay offline incluso). Wrapper sottile
  /// su [recordRawEvent] — nessuna logica duplicata tra i due.
  Future<void> recordEvent(MissionEvent event);

  /// Variante "raw" usata dal replay della coda offline, dove non esiste
  /// più un'istanza [MissionEvent] concreta — solo i campi già estratti
  /// e persistiti (`QueuedMissionEvent`).
  Future<void> recordRawEvent({
    required String eventType,
    required Map<String, dynamic> payload,
    required String idempotencyKey,
  });

  /// Chiama la RPC `claim_mission`: assegna le ricompense server-side.
  Future<MissionClaim> claimMission(String missionId);

  /// Numero di missioni segrete attive nel pool (per i placeholder "???"),
  /// senza mai esporre quali siano.
  Future<int> secretMissionSlotCount();

  Future<Season?> activeSeason();
}
