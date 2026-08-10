import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/missions/presentation/providers/mission_event_bridge_provider.dart';
import 'features/notifications/presentation/providers/local_notifications_service.dart';
import 'features/notifications/presentation/providers/push_notification_service.dart';
import 'features/rival/presentation/providers/rival_controller_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // firebase_crashlytics non ha un'implementazione per Web/Windows/Linux
  // (solo Android/iOS/macOS): assegnarlo incondizionatamente fa sì che
  // ogni FlutterError sollevi a sua volta un'eccezione nel plugin quando
  // si gira in locale su Chrome o Windows desktop.
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  }

  runApp(const ProviderScope(child: HrrApp()));
}

class HrrApp extends ConsumerWidget {
  const HrrApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // Tiene vivo il Mission Engine per tutta la sessione (ascolto bus +
    // drain coda offline) — vedi mission_event_bridge_provider.dart.
    ref.watch(missionEventBridgeProvider);
    // Crea il canale Android delle notifiche PRIMA che possa arrivare una
    // push (vedi local_notifications_service.dart) — deve avviarsi
    // all'apertura dell'app, non alla prima chiamata lazy da dentro
    // PushNotificationService, altrimenti una push a freddo rischierebbe
    // di arrivare prima che il canale esista.
    ref.watch(localNotificationsServiceProvider);
    // Registra il device per le notifiche push (FCM) — no-op silenzioso
    // finché Firebase non ha credenziali reali, vedi push_notification_
    // service.dart.
    ref.watch(pushNotificationServiceProvider);
    // Tiene vivo il Rival per tutta la sessione (ascolto eventi + check
    // giornaliero streak/inattività) — vedi rival_controller_provider.dart.
    ref.watch(rivalControllerProvider);

    return MaterialApp.router(
      title: 'H.R.R.',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
