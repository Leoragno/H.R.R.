import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'web_reload_stub.dart' if (dart.library.js_interop) 'web_reload_web.dart';

/// Id della build web, iniettato da scripts/deploy_web.sh
/// (--dart-define=WEB_BUILD_ID) e scritto anche in build.json accanto
/// all'app. Vuoto nelle build fatte senza lo script: in quel caso il
/// controllo è disattivato invece di segnalare aggiornamenti fantasma.
const _kBuildId = String.fromEnvironment('WEB_BUILD_ID');

const _kCheckInterval = Duration(minutes: 5);

/// Banner "Nuova versione disponibile" per il sito/PWA. Una PWA installata
/// (soprattutto su iOS) può restare aperta in memoria per giorni con la
/// build vecchia: confrontiamo periodicamente l'id compilato qui dentro con
/// build.json sul server. Nessun reload automatico: interromperebbe una
/// guida registrata dal browser — decide l'utente col pulsante.
class WebUpdateBanner extends StatefulWidget {
  final Widget child;
  const WebUpdateBanner({super.key, required this.child});

  @override
  State<WebUpdateBanner> createState() => _WebUpdateBannerState();
}

class _WebUpdateBannerState extends State<WebUpdateBanner>
    with WidgetsBindingObserver {
  Timer? _timer;
  // Build remota già vista e chiusa con la X: il banner ricompare solo
  // se nel frattempo esce una build ancora più nuova.
  String? _dismissedBuild;
  String? _availableBuild;
  bool _reloading = false;

  bool get _enabled => kIsWeb && _kBuildId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_check());
    _timer = Timer.periodic(_kCheckInterval, (_) => unawaited(_check()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_enabled) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check() async {
    try {
      final response = await Dio().get<dynamic>(
        Uri.base.resolve('build.json').toString(),
        // Mai dalla cache HTTP del browser, altrimenti rileggeremmo l'id
        // della build vecchia.
        queryParameters: {'t': DateTime.now().millisecondsSinceEpoch},
        options: Options(responseType: ResponseType.json),
      );
      final data = response.data;
      final remote = data is Map ? data['build'] : null;
      if (!mounted || remote is! String || remote == _kBuildId) return;
      if (remote != _availableBuild) setState(() => _availableBuild = remote);
    } catch (_) {
      // Offline o build.json assente: riprova al prossimo giro.
    }
  }

  Future<void> _reload() async {
    setState(() => _reloading = true);
    await hardReload();
  }

  @override
  Widget build(BuildContext context) {
    final available = _availableBuild;
    final show = available != null && available != _dismissedBuild;
    return Stack(
      children: [
        widget.child,
        if (show)
          Positioned(
            left: AppSpace.md,
            right: AppSpace.md,
            top: 0,
            child: SafeArea(
              child: Material(
                color: AppColor.surfaceHigh,
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.md, AppSpace.xs, AppSpace.xs, AppSpace.xs),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColor.line),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.system_update_rounded,
                          size: 20, color: AppColor.inkMuted),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: Text('Nuova versione di H.R.R. disponibile',
                            style: AppType.caption
                                .copyWith(color: AppColor.ink)),
                      ),
                      TextButton(
                        onPressed: _reloading ? null : _reload,
                        child: Text(_reloading ? 'Aggiorno…' : 'Aggiorna',
                            style: const TextStyle(color: AppColor.cyan)),
                      ),
                      IconButton(
                        tooltip: 'Più tardi',
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: AppColor.inkMuted),
                        onPressed: () =>
                            setState(() => _dismissedBuild = available),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
