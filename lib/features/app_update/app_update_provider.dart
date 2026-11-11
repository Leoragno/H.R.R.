import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/network/supabase_provider.dart';
import '../auth/presentation/providers/auth_provider.dart';

/// Versione dell'APK più recente pubblicata (supabase/migrations/
/// 0036_app_releases.sql), già risolta sull'ABI di questo telefono.
class AppUpdate {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String? sha256;
  final String? notes;

  const AppUpdate({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    this.sha256,
    this.notes,
  });
}

// Ordine di preferenza se l'ABI riportata dal telefono non ha un'APK
// dedicata nella release (es. un x86 senza build): arm64 gira sulla quasi
// totalità dei telefoni attuali.
const _kFallbackAbis = ['arm64-v8a', 'armeabi-v7a'];

/// Aggiornamento disponibile per l'APK installata, o null se è già
/// l'ultima / non applicabile (web e iOS si aggiornano per altre vie: la
/// PWA ricaricando la pagina). Rivalutato a ogni ripresa dell'app (vedi
/// AppUpdatePrompt), così toccando la push "aggiornamento disponibile"
/// l'avviso compare subito.
///
/// Provider scritto a mano (non @riverpod): un solo FutureProvider non
/// giustifica un giro di build_runner, lento su questo progetto.
/// Numero di build senza il prefisso ABI. Con `--split-per-abi` Flutter
/// scrive nel versionCode Android `abi * 1000 + build` (armeabi-v7a 1,
/// arm64-v8a 2, x86_64 4): la 0.1.1+2 installata su arm64 risponde 2002.
/// Confrontare i numeri grezzi con il build della release (es. 3) faceva
/// credere a ogni telefono di essere già aggiornato.
int buildNumberOf(int versionCode) => versionCode % 1000;

final availableAppUpdateProvider =
    FutureProvider.autoDispose<AppUpdate?>(_availableAppUpdate);

Future<AppUpdate?> _availableAppUpdate(Ref ref) async {
  if (kIsWeb || !Platform.isAndroid) return null;
  // app_releases è leggibile solo da utenti autenticati.
  if (ref.watch(authStateProvider).valueOrNull == null) return null;

  final info = await PackageInfo.fromPlatform();
  final installed = buildNumberOf(int.tryParse(info.buildNumber) ?? 0);

  final row = await ref
      .read(supabaseClientProvider)
      .from('app_releases')
      .select('version_code, version_name, apks, notes')
      // Per data, non per version_code: la release 0.1.3 ha anche una riga
      // con codice alto (9004) per le app 0.1.1/0.1.2, che confrontano i
      // numeri grezzi; le release successive hanno codici normali.
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();
  if (row == null) return null;

  final versionCode = (row['version_code'] as num).toInt();
  if (buildNumberOf(versionCode) <= installed) return null;

  final apks = Map<String, dynamic>.from(row['apks'] as Map);
  final abi = await OtaUpdate().getAbi();
  final candidates = [if (abi != null) abi, ..._kFallbackAbis];
  for (final candidate in candidates) {
    final apk = apks[candidate];
    if (apk is Map && apk['url'] is String) {
      return AppUpdate(
        versionCode: versionCode,
        versionName: row['version_name'] as String,
        apkUrl: apk['url'] as String,
        sha256: apk['sha256'] as String?,
        notes: row['notes'] as String?,
      );
    }
  }
  return null;
}
