import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:wakelock_plus/wakelock_plus.dart';

/// Tiene acceso lo schermo mentre il GPS registra, solo su Web/PWA.
///
/// Una PWA (soprattutto su iPhone/Safari) non ha un foreground service né la
/// location in background: appena lo schermo si spegne o la scheda passa in
/// secondo piano il browser sospende la geolocalizzazione e il tracciato si
/// interrompe. L'unica difesa è impedire lo spegnimento dello schermo.
///
/// Su Android (foreground service + wake lock CPU, vedi TripLiveController)
/// e iOS nativo (UIBackgroundModes=location) il tracking sopravvive a
/// schermo spento: lì lo schermo può e deve spegnersi, quindi qui è un no-op.
///
/// Best-effort: un browser senza Wake Lock API (o che rifiuta la richiesta
/// perché non arriva da un gesto dell'utente) non deve mai far fallire il
/// tracciamento — l'utente resta avvisato a schermo di lasciarlo acceso.
abstract final class TrackingWakelock {
  static Future<void> enable() => _toggle(true);

  static Future<void> disable() => _toggle(false);

  static Future<void> _toggle(bool enable) async {
    if (!kIsWeb) return;
    try {
      await WakelockPlus.toggle(enable: enable);
    } catch (_) {
      // Vedi sopra: nessun impatto sul tracking GPS.
    }
  }
}
