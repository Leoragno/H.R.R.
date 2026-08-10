// File generato normalmente da `flutterfire configure`.
// Android e iOS puntano al progetto Firebase reale "hrr-ac9f6" (stessi
// valori di android/app/google-services.json). Il blocco `web` invece è
// ancora un placeholder letterale: nessuna build web di questo progetto
// registra token FCM (vedi push_notification_service.dart, i platform
// gestiti sono solo android/ios), quindi non blocca nulla — se in futuro
// serve anche lì, rilancia:
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
    apiKey: 'AIzaSyA3AlK0246tmB6svJlVNNf-lI2XNJdHKuk',
    appId: '1:968773926384:android:ffee2a48ed96dc8409b135',
    messagingSenderId: '968773926384',
    projectId: 'hrr-ac9f6',
    storageBucket: 'hrr-ac9f6.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDNmz-_zm_2aaHDODfcw6GDCOhK1G7V9Bg',
    appId: '1:968773926384:ios:60258ea1f016f15f09b135',
    messagingSenderId: '968773926384',
    projectId: 'hrr-ac9f6',
    storageBucket: 'hrr-ac9f6.firebasestorage.app',
    iosBundleId: 'com.hrr.app.hrrApp',
  );
}
