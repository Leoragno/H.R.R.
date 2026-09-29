import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ota_update/ota_update.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'app_update_provider.dart';

/// Propone l'aggiornamento dell'APK quando ne esiste uno più recente (vedi
/// [availableAppUpdateProvider]). Avvolge le tab in MainShell: ricontrolla
/// a ogni ritorno in primo piano e mostra l'avviso una volta per versione
/// per sessione — "Più tardi" non lo ripropone finché l'app non viene
/// riaperta da zero.
class AppUpdatePrompt extends ConsumerStatefulWidget {
  final Widget child;
  const AppUpdatePrompt({super.key, required this.child});

  @override
  ConsumerState<AppUpdatePrompt> createState() => _AppUpdatePromptState();
}

class _AppUpdatePromptState extends ConsumerState<AppUpdatePrompt>
    with WidgetsBindingObserver {
  int? _promptedVersion;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(availableAppUpdateProvider);
    }
  }

  void _maybePrompt(AppUpdate? update) {
    if (update == null || update.versionCode == _promptedVersion) return;
    _promptedVersion = update.versionCode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AppUpdateDialog(update: update),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppUpdate?>>(availableAppUpdateProvider,
        (previous, next) => _maybePrompt(next.valueOrNull));
    return widget.child;
  }
}

class _AppUpdateDialog extends StatefulWidget {
  final AppUpdate update;
  const _AppUpdateDialog({required this.update});

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  StreamSubscription<OtaEvent>? _sub;
  // null = non ancora avviato; 0-100 = download in corso.
  int? _progress;
  bool _installing = false;
  String? _error;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _progress = 0;
      _installing = false;
      _error = null;
    });
    try {
      // Istanza nuova a ogni tentativo: OtaUpdate tiene in cache lo stream
      // della prima esecuzione, un riprova sulla stessa istanza non
      // ripartirebbe.
      _sub = OtaUpdate()
          .execute(
            widget.update.apkUrl,
            destinationFilename: 'hrr-${widget.update.versionName}.apk',
            // Scarta un download troncato/corrotto invece di passarlo
            // all'installer, che risponderebbe "pacchetto non valido".
            sha256checksum: widget.update.sha256,
          )
          .listen(_onEvent, onError: (Object e) => _fail('$e'));
    } catch (e) {
      _fail('$e');
    }
  }

  void _onEvent(OtaEvent event) {
    if (!mounted) return;
    switch (event.status) {
      case OtaStatus.DOWNLOADING:
        setState(() => _progress = int.tryParse(event.value ?? '') ?? _progress);
      case OtaStatus.INSTALLING:
      case OtaStatus.INSTALLATION_DONE:
        setState(() => _installing = true);
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
        _fail('Consenti a H.R.R. di installare app: Impostazioni › App › '
            'H.R.R. › Installa app sconosciute, poi riprova.');
      case OtaStatus.CHECKSUM_ERROR:
      case OtaStatus.DOWNLOAD_ERROR:
        _fail('Download non riuscito o incompleto. Controlla la connessione '
            'e riprova.');
      case OtaStatus.CANCELED:
        _fail('Download annullato.');
      case OtaStatus.ALREADY_RUNNING_ERROR:
        break;
      case OtaStatus.INSTALLATION_ERROR:
      case OtaStatus.INTERNAL_ERROR:
        _fail('Aggiornamento non riuscito (${event.value ?? 'errore'}).');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _progress = null;
      _installing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;
    final progress = _progress;
    final busy = progress != null && _error == null;
    final notes = update.notes?.trim();

    return AlertDialog(
      backgroundColor: AppColor.surfaceHigh,
      title: Text('Aggiornamento ${update.versionName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('È disponibile una nuova versione di H.R.R.'),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            Text(notes, style: AppType.caption),
          ],
          if (busy) ...[
            const SizedBox(height: AppSpace.md),
            LinearProgressIndicator(
              value: _installing ? null : progress / 100,
              color: AppColor.cyan,
              backgroundColor: AppColor.line,
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              _installing
                  ? 'Conferma "Installa" nella schermata di Android.'
                  : 'Download $progress%',
              style: AppType.caption,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpace.md),
            Text(_error!,
                style: AppType.caption.copyWith(color: AppColor.danger)),
          ],
        ],
      ),
      actions: [
        if (!busy || _installing)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_installing ? 'Chiudi' : 'Più tardi'),
          ),
        if (!busy)
          TextButton(
            onPressed: _start,
            child: Text(_error == null ? 'Aggiorna' : 'Riprova',
                style: const TextStyle(color: AppColor.cyan)),
          ),
      ],
    );
  }
}
