import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/router/app_router.dart';

part 'local_notifications_service.g.dart';

/// Canale Android usato sia qui (system notification mostrata mentre
/// l'app è in foreground) sia dal manifest
/// (`com.google.firebase.messaging.default_notification_channel_id`) sia
/// dal payload FCM lato server (`android.notification.channel_id` in
/// supabase/functions/send-push) — deve restare lo STESSO id ovunque,
/// altrimenti Android crea un secondo canale silenzioso/IMPORTANCE_DEFAULT
/// alla prima push e l'utente non lo scopre mai per riattivare
/// suono/popup a mano.
const hrrNotificationChannelId = 'hrr_default_channel';

/// Notifiche locali Android: servono SOLO per il caso "app in foreground",
/// dove FCM (a differenza di background/terminata) non mostra da sé una
/// system notification — vedi il commento sul listener onMessage in
/// push_notification_service.dart. Nessun ruolo nel flusso
/// background/terminata (lì la mostra il sistema operativo da solo dal
/// payload `notification` + `android.notification.channel_id`) né nelle
/// notifiche in-app via Supabase Realtime (notification_toast_overlay.dart),
/// che restano un canale completamente separato e non tocco.
@Riverpod(keepAlive: true)
class LocalNotificationsService extends _$LocalNotificationsService {
  late final FlutterLocalNotificationsPlugin _plugin;
  late final Future<void> _ready;

  @override
  void build() {
    _plugin = FlutterLocalNotificationsPlugin();
    _ready = _init();
  }

  Future<void> _init() async {
    tz_data.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('ic_notification');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (_) => _openNotifications(),
    );

    // Il manifest dichiara già hrr_default_channel come canale FCM di
    // default (per background/terminata) — lo creiamo esplicitamente anche
    // lato Flutter con IMPORTANCE_HIGH così esiste già (stesso id, stessa
    // importanza) fin dalla primissima push in foreground, invece di
    // aspettare che lo crei FCM da solo con impostazioni meno aggressive.
    const channel = AndroidNotificationChannel(
      hrrNotificationChannelId,
      'Notifiche H.R.R.',
      description: 'Missioni, achievement e community',
      importance: Importance.high,
      playSound: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _openNotifications() {
    ref.read(appRouterProvider).push(AppRoutes.notifications);
  }

  /// Mostra una system notification a partire da una push FCM ricevuta in
  /// foreground (dove FCM non la mostra da solo). No-op se il messaggio
  /// non ha un blocco `notification` (solo `data`) — evita di inventare
  /// titolo/corpo dal nulla.
  Future<void> showFromRemoteMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Il canale/plugin si inizializzano in modo asincrono da build(): senza
    // aspettarli qui, una push arrivata a freddo (pochi ms dopo l'avvio
    // dell'app) potrebbe chiamare show() prima che il canale esista
    // ancora, e la notifica sparirebbe silenziosamente.
    await _ready;

    await _plugin.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          hrrNotificationChannelId,
          'Notifiche H.R.R.',
          channelDescription: 'Missioni, achievement e community',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
          playSound: true,
        ),
      ),
    );
  }

  /// Id fisso: ri-schedulare sovrascrive lo slot precedente, cancel
  /// funziona sempre sullo stesso id senza doverlo tracciare altrove.
  static const _streakReminderId = 990001;

  /// Promemoria "streak a rischio" alle 22:00 locali di oggi — no-op se
  /// sono già passate (nessun senso schedulare nel passato). Costruito
  /// convertendo l'orario locale in UTC con le API native di [DateTime]
  /// (già corrette rispetto al fuso del dispositivo) invece di dipendere
  /// da un pacchetto di lookup del fuso IANA locale.
  Future<void> scheduleStreakReminder(String body) async {
    await _ready;
    final now = DateTime.now();
    final at = DateTime(now.year, now.month, now.day, 22, 0);
    if (at.isBefore(now)) return;

    await _plugin.zonedSchedule(
      _streakReminderId,
      'La tua streak è a rischio! 🔥',
      body,
      tz.TZDateTime.from(at.toUtc(), tz.UTC),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          hrrNotificationChannelId,
          'Notifiche H.R.R.',
          channelDescription: 'Missioni, achievement e community',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
          playSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Chiamato appena l'utente si fa vivo nel giorno corrente (es. un
  /// trip completato) — il promemoria delle 22:00 non serve più.
  Future<void> cancelStreakReminder() async {
    await _ready;
    await _plugin.cancel(_streakReminderId);
  }
}
