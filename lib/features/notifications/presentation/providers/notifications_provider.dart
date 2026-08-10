import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/supabase_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/notifications_remote_datasource.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

part 'notifications_provider.g.dart';

// ---- DI wiring ------------------------------------------------------------

@riverpod
NotificationsRemoteDatasource notificationsRemoteDatasource(
        NotificationsRemoteDatasourceRef ref) =>
    NotificationsRemoteDatasource(ref.watch(supabaseClientProvider));

@riverpod
NotificationRepository notificationRepository(NotificationRepositoryRef ref) =>
    NotificationRepositoryImpl(ref.watch(notificationsRemoteDatasourceProvider));

// ---- Toast per l'arrivo di una nuova notifica ------------------------------

/// Pulsa con l'ultima notifica arrivata mentre l'app era già aperta (mai
/// per il backlog scaricato all'avvio) — ConsumerWidget in giro per l'app
/// (vedi MainShell) ci fa `ref.listen` per mostrare un toast un po'
/// simpatico. Stato semplice, lo aggiorna solo [NotificationsController].
@riverpod
class NotificationToastController extends _$NotificationToastController {
  @override
  AppNotification? build() => null;

  void show(AppNotification notification) => state = notification;
}

// ---- Lista notifiche (realtime) --------------------------------------------

/// Tutte le notifiche dell'utente corrente, più recenti prima — lo stream
/// Supabase riconsegna l'intero snapshot ad ogni cambio (non un diff):
/// la prima consegna è il backlog (nessun toast), quelle successive sono
/// confrontate con lo stato precedente per capire quali righe sono
/// davvero nuove e meritano un toast.
@riverpod
class NotificationsController extends _$NotificationsController {
  StreamSubscription<List<AppNotification>>? _sub;
  bool _hydrated = false;

  @override
  List<AppNotification> build() {
    final profileId = ref.watch(myProfileProvider).valueOrNull?.id;
    ref.onDispose(_cancel);
    if (profileId != null) _subscribe(profileId);
    return const [];
  }

  void _subscribe(String profileId) {
    _sub?.cancel();
    _hydrated = false;
    _sub = ref.read(notificationRepositoryProvider).watch(profileId).listen(
      (rows) {
        if (!_hydrated) {
          _hydrated = true;
          state = rows;
          return;
        }
        final knownIds = state.map((n) => n.id).toSet();
        final fresh = rows.where((n) => !knownIds.contains(n.id)).toList();
        state = rows;
        if (fresh.isNotEmpty) {
          ref.read(notificationToastControllerProvider.notifier).show(fresh.first);
        }
      },
      onError: (_) {
        // Realtime momentaneamente non disponibile: si mantiene l'ultimo
        // stato noto invece di svuotare la lista, nessun errore in UI.
      },
    );
  }

  void _cancel() {
    _sub?.cancel();
    _sub = null;
  }

  Future<void> markRead(String id) async {
    final idx = state.indexWhere((n) => n.id == id);
    if (idx == -1 || state[idx].read) return;
    // Ottimista: l'update realtime in arrivo confermerà lo stesso stato.
    final updated = [...state];
    updated[idx] = updated[idx].copyWith(read: true);
    state = updated;
    await ref.read(notificationRepositoryProvider).markRead(id);
  }

  Future<void> markAllRead() async {
    final profileId = ref.read(myProfileProvider).valueOrNull?.id;
    if (profileId == null) return;
    state = [for (final n in state) n.copyWith(read: true)];
    await ref.read(notificationRepositoryProvider).markAllRead(profileId);
  }
}

@riverpod
int unreadNotificationsCount(UnreadNotificationsCountRef ref) =>
    ref.watch(notificationsControllerProvider).where((n) => !n.read).length;
