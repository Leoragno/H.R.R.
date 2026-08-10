import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/mascot.dart';

part 'active_mascot_provider.g.dart';

/// Mascotte attiva per l'utente corrente — letta da [myProfileProvider]
/// (si aggiorna in realtime quando l'utente cambia scelta in
/// Impostazioni, stesso meccanismo di accentColor), con fallback alla
/// prima del catalogo se non ha ancora scelto o se l'id persistito non è
/// (più) riconosciuto.
@riverpod
Mascot activeMascot(ActiveMascotRef ref) {
  final mascotId = ref.watch(myProfileProvider).valueOrNull?.mascotId;
  if (mascotId == null) return kMascotCatalog.first;
  for (final m in kMascotCatalog) {
    if (m.id == mascotId) return m;
  }
  return kMascotCatalog.first;
}
