import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Ricarica "forzata" della PWA: rimuove service worker e Cache Storage
/// rimasti da build precedenti (le vecchie versioni di Flutter web
/// servivano l'app offline da lì), poi ricarica la pagina. Ogni passaggio
/// è best-effort: anche se uno fallisce, il reload avviene comunque.
Future<void> hardReload() async {
  try {
    final registrations =
        await web.window.navigator.serviceWorker.getRegistrations().toDart;
    for (final registration in registrations.toDart) {
      await registration.unregister().toDart;
    }
  } catch (_) {}
  try {
    final keys = await web.window.caches.keys().toDart;
    for (final key in keys.toDart) {
      await web.window.caches.delete(key.toDart).toDart;
    }
  } catch (_) {}
  web.window.location.reload();
}
