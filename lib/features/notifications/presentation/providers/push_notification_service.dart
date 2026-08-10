import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'local_notifications_service.dart';
import 'push_token_providers.dart';

part 'push_notification_service.g.dart';

/// Handler per le push ricevute quando l'app è in background o terminata.
/// FCM lo richiede come funzione top-level annotata `vm:entry-point`
/// perché gira in un isolato separato da quello dell'app: qui non serve
/// fare altro (il payload `notification` viene già mostrato dal sistema
/// operativo), ma la sua sola registrazione è necessaria perché il plugin
/// nativo consegni correttamente i messaggi in questo stato invece di
/// scartarli.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Notifiche push (FCM), fuori dall'app — completano le notifiche in-app
/// (Supabase Realtime, sempre attive a prescindere da questo servizio e
/// dallo stato di Firebase). Su piattaforme/config senza Messaging
/// funzionante (web senza VAPID key, desktop, o un progetto Firebase non
/// ancora impostato) ogni chiamata sotto fallisce silenziosamente — l'app
/// resta comunque completamente utilizzabile.
///
/// Va tenuto vivo per tutta la sessione: instanziato una volta da
/// [HrrApp] (vedi main.dart) leggendolo con `ref.watch`, stesso principio
/// di MissionEventBridge. Il logout libera il token lato server — vedi
/// `AuthController.signOut` in auth_provider.dart — non qui, perché a
/// quel punto la sessione Supabase è già chiusa e la RPC non avrebbe più
/// un `auth.uid()` valido per farlo.
@Riverpod(keepAlive: true)
class PushNotificationService extends _$PushNotificationService {
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  String? _registeredToken;

  @override
  void build() {
    ref.listen(authStateProvider, (previous, next) {
      final user = next.valueOrNull;
      if (user != null) unawaited(_registerForUser());
    });
    final current = ref.read(authStateProvider).valueOrNull;
    if (current != null) unawaited(_registerForUser());

    // App aperta e in primo piano: FCM NON mostra da sola una notifica di
    // sistema in questo stato (succede solo in background/terminata). La
    // riga `notifications` arriva comunque via Supabase Realtime ed è già
    // mostrata dal toast in-app (vedi notification_toast_overlay.dart) —
    // ma quel toast è un widget dentro l'app, non una vera system
    // notification (niente popup/heads-up, suono o icona in barra), che è
    // invece quello che ci si aspetta da una push. Mostriamo quindi anche
    // una local notification qui: nessun doppione con il caso
    // background/terminata, dove NON viene mai chiamato onMessage — lì è
    // il sistema operativo a mostrarla da solo dal payload FCM.
    _foregroundSub = FirebaseMessaging.onMessage.listen(
      (message) => ref
          .read(localNotificationsServiceProvider.notifier)
          .showFromRemoteMessage(message),
    );

    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationOpened);
    unawaited(_checkInitialMessage());

    ref.onDispose(() {
      _refreshSub?.cancel();
      _openedSub?.cancel();
      _foregroundSub?.cancel();
    });
  }

  Future<void> _registerForUser() async {
    try {
      // Richiesta esplicita del permesso Android nativo (POST_NOTIFICATIONS,
      // Android 13+) via permission_handler, in aggiunta a quella sotto di
      // FirebaseMessaging: il plugin Firebase la richiede a sua volta, ma
      // passare anche dalla via standard di Android riduce il rischio di
      // comportamenti diversi tra versioni del plugin/OS — se è già
      // concesso o negato in modo permanente, questa chiamata è un no-op
      // immediato, nessun doppio prompt per l'utente.
      if (!kIsWeb && Platform.isAndroid) {
        await ph.Permission.notification.request();
      }

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken();
      if (token != null) await _upsertToken(token);

      _refreshSub?.cancel();
      _refreshSub = messaging.onTokenRefresh.listen(_upsertToken);
    } catch (_) {
      // Firebase non configurato (credenziali placeholder) o piattaforma
      // senza supporto Messaging (web senza VAPID key, desktop): nessuna
      // registrazione, l'app resta comunque utilizzabile.
    }
  }

  Future<void> _upsertToken(String token) async {
    if (token == _registeredToken) return;
    try {
      await ref.read(pushTokenRepositoryProvider).register(
            token: token,
            platform: _platformName(),
          );
      _registeredToken = token;
    } catch (_) {
      // Riprova al prossimo refresh/login: nessuna notifica push in più
      // rispetto a quelle già visibili in-app.
    }
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    return 'android';
  }

  void _onNotificationOpened(RemoteMessage message) {
    // L'utente ha toccato una push (app in background/terminata): la
    // apriamo sul feed notifiche, GoRouter non richiede un BuildContext
    // per navigare dal router stesso.
    ref.read(appRouterProvider).push(AppRoutes.notifications);
  }

  Future<void> _checkInitialMessage() async {
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _onNotificationOpened(initial);
    } catch (_) {
      // Come sopra: Firebase non configurato o piattaforma non supportata.
    }
  }
}
