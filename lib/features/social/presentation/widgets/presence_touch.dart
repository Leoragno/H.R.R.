import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../social_providers.dart';

/// Segna "visto adesso" (profiles.last_seen_at) all'apertura e a ogni
/// ritorno in primo piano. Errori ignorati: se la migrazione 0039 non è
/// ancora applicata la RPC non esiste e non deve disturbare.
class PresenceTouch extends ConsumerStatefulWidget {
  const PresenceTouch({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<PresenceTouch> createState() => _PresenceTouchState();
}

class _PresenceTouchState extends ConsumerState<PresenceTouch>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _touch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _touch();
  }

  Future<void> _touch() async {
    try {
      await ref.read(socialRepositoryProvider).touchLastSeen();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
