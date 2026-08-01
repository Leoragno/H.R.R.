// File generato normalmente da `flutterfire configure`.
// PLACEHOLDER: sostituisci con l'output reale del tuo progetto Firebase
// prima del rilascio — questi valori fittizi impediscono a Messaging/
// Analytics/Crashlytics di funzionare ma permettono al progetto di
// compilare durante lo sviluppo locale.
//
// Comando da eseguire quando il progetto Firebase è pronto:
//   dart pub global activate flutterfire_cli
//   flutterfire configure
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions non configurato per ${defaultTargetPlatform.name}.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE_OUTPUT',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'hrr-app-placeholder',
    storageBucket: 'hrr-app-placeholder.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE_OUTPUT',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'hrr-app-placeholder',
    storageBucket: 'hrr-app-placeholder.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE_OUTPUT',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'hrr-app-placeholder',
    storageBucket: 'hrr-app-placeholder.appspot.com',
    iosBundleId: 'com.hrr.app.hrrApp',
  );
}
