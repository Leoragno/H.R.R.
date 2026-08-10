import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/events/mission_event.dart';
import '../../../../core/events/mission_event_bus.dart';
import '../../../../core/utils/deterministic_pick.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/domain/entities/app_notification.dart';
import '../../../notifications/presentation/providers/local_notifications_service.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../data/rival_dialogue.dart';
import '../../data/rival_local_store.dart';
import '../../domain/entities/mascot.dart';
import '../../domain/entities/rival_popup.dart';
import 'active_mascot_provider.dart';

part 'rival_controller_provider.g.dart';

/// Decide quando e cosa dice il Rival, ascoltando due fonti già esistenti
/// invece di reinventarle:
/// - `notificationToastControllerProvider` per missione completata/record
///   personale (la logica di confronto vive già lato server, vedi
///   0018_progress_record_notifications.sql — qui si reagisce e basta);
/// - il bus `MissionEvent` (core/events) solo per `TripCompleted`, usato
///   come timestamp di "ultima attività" per il check di inattività.
/// Streak e "nuovo giorno" sono invece calcolati qui, non esistono altrove
/// (vedi RivalLocalStore).
///
/// Va tenuto vivo per tutta la sessione — instanziato da [HrrApp] con
/// `ref.watch`, stesso pattern di MissionEventBridge.
@Riverpod(keepAlive: true)
class RivalController extends _$RivalController {
  final _store = RivalLocalStore();
  StreamSubscription<MissionEvent>? _busSub;
  DateTime? _lastShownAt;
  String? _profileId;

  static const _minInterval = Duration(seconds: 90);
  static const _inactivityThreshold = Duration(hours: 24);
  static const _lateHour = 21;

  @override
  RivalPopup? build() {
    ref.onDispose(() => _busSub?.cancel());

    final bus = ref.watch(missionEventBusProvider);
    // Ricreato ad ogni build (anche quelli scatenati dal watch di
    // authStateProvider più sotto, non solo alla creazione del bus): senza
    // cancellare prima, login/logout ripetuti accumulerebbero sottoscrizioni
    // duplicate sullo stesso bus.
    _busSub?.cancel();
    _busSub = bus.stream.listen(_onMissionEvent);

    ref.listen<AppNotification?>(notificationToastControllerProvider,
        (previous, next) {
      if (next == null) return;
      if (next.type == 'mission_complete' || next.type == 'mission_claimed') {
        _emit(RivalMood.missionCelebration, seed: next.id);
      } else if (next.type == 'speed_record') {
        _emit(RivalMood.personalRecordHype, seed: next.id);
      }
    });

    // authStateProvider (non myProfileProvider: quello riemette ad ogni
    // trip, non solo al login) — il check giornaliero deve partire una
    // volta per sessione di login, non ad ogni variazione di xp/rep.
    final profileId = ref.watch(authStateProvider).valueOrNull?.id;
    if (profileId != null && profileId != _profileId) {
      _profileId = profileId;
      Future.delayed(const Duration(milliseconds: 1500),
          () => _runDailyAndInactivityCheck(profileId));
    }

    return null;
  }

  void _onMissionEvent(MissionEvent event) {
    if (event is TripCompleted) {
      final profileId = _profileId;
      if (profileId != null) {
        unawaited(_updateLastTripAt(profileId, event.occurredAt));
      }
    }
  }

  Future<void> _updateLastTripAt(String profileId, DateTime at) async {
    final daily = await _store.read(profileId);
    await _store.write(profileId, daily.copyWith(lastTripAt: at));
    // L'utente si è già fatto vivo oggi: il promemoria delle 22:00
    // eventualmente schedulato stamattina non serve più.
    unawaited(
        ref.read(localNotificationsServiceProvider.notifier).cancelStreakReminder());
  }

  Future<void> _runDailyAndInactivityCheck(String profileId) async {
    final daily = await _store.read(profileId);
    final now = DateTime.now();
    final today = _dateOnly(now);

    if (daily.lastActiveDate == null) {
      await _store.write(
          profileId, daily.copyWith(lastActiveDate: today, streakCount: 1));
      _emit(RivalMood.greeting, seed: '$profileId|$today');
    } else if (daily.lastActiveDate != today) {
      final daysSince = DateTime.parse(today)
          .difference(DateTime.parse(daily.lastActiveDate!))
          .inDays;

      if (daysSince == 1) {
        final newStreak = daily.streakCount + 1;
        final mood = now.hour >= _lateHour && newStreak > 1
            ? RivalMood.streakUrgent
            : (newStreak >= 2 ? RivalMood.streakEncouraging : RivalMood.greeting);
        await _store.write(profileId,
            daily.copyWith(lastActiveDate: today, streakCount: newStreak));
        _emit(mood, seed: '$profileId|$today');

        // C'è una streak da perdere e l'utente non si è ancora fatto
        // vivo oggi: schedula un promemoria per le 22:00 (annullato da
        // _updateLastTripAt appena arriva un trip completato oggi).
        final lastTrip = daily.lastTripAt;
        final alreadyActiveToday =
            lastTrip != null && _dateOnly(lastTrip) == today;
        if (newStreak >= 2 && !alreadyActiveToday) {
          unawaited(ref
              .read(localNotificationsServiceProvider.notifier)
              .scheduleStreakReminder(
                  'Hai $newStreak giorni di fila — non perderli!'));
        }
      } else {
        final lostStreak = daily.streakCount >= 2;
        await _store.write(
            profileId, daily.copyWith(lastActiveDate: today, streakCount: 1));
        _emit(lostStreak ? RivalMood.streakLost : RivalMood.greeting,
            seed: '$profileId|$today');
      }
    }

    await _checkInactivity(profileId, today);
  }

  Future<void> _checkInactivity(String profileId, String today) async {
    final daily = await _store.read(profileId);
    final lastTrip = daily.lastTripAt;
    if (lastTrip == null) return;
    if (daily.inactivityQuipShownDate == today) return;
    if (DateTime.now().difference(lastTrip) < _inactivityThreshold) return;

    await _store.write(
        profileId, daily.copyWith(inactivityQuipShownDate: today));
    _emit(RivalMood.inactivityTaunt, seed: '$profileId|$today|inactivity');
  }

  void _emit(RivalMood mood, {required String seed}) {
    final mascot = ref.read(activeMascotProvider);
    final phrase = pickDeterministic(seed, mascot.id, phrasesFor(mascot.id, mood));
    _publish(mascot, mood, phrase);
  }

  /// Frase dinamica (nome/posizione reali, non pescabili da un pool
  /// statico — stesso principio di interpolazione di
  /// notification_presentation.dart, che inietta n.body in template
  /// fissi). Chiamato da leaderboard_screen.dart quando il rivale
  /// tracciato per la classifica canonica non è più sopra l'utente in
  /// una fetch fresca.
  void announceOvertake({required String rivalName, required int newRank}) {
    final mascot = ref.read(activeMascotProvider);
    final templates = [
      'Hai superato $rivalName! $rivalName è sceso al #$newRank.',
      'Sorpasso su $rivalName — ora è al #$newRank.',
      '$rivalName alle tue spalle. Posizione #$newRank per lui.',
    ];
    final phrase = pickDeterministic('$rivalName|$newRank', mascot.id, templates);
    _publish(mascot, RivalMood.leaderboardOvertake, phrase);
  }

  /// Cooldown globale + pubblicazione dello stato, condiviso da entrambi
  /// i percorsi (pool statico e frase dinamica) — un solo punto che
  /// decide se e quando il popup arriva davvero in UI. Un solo popup
  /// alla volta, niente coda: un trigger scartato durante il cooldown
  /// non viene rimostrato più tardi (evita spam se più eventi arrivano
  /// ravvicinati).
  void _publish(Mascot mascot, RivalMood mood, String phrase) {
    final now = DateTime.now();
    if (_lastShownAt != null && now.difference(_lastShownAt!) < _minInterval) {
      return;
    }
    _lastShownAt = now;
    state = RivalPopup(mascot: mascot, mood: mood, phrase: phrase);
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
