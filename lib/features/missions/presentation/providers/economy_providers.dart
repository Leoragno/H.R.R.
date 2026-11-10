import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../progression/domain/bond.dart';
import '../../../rival/presentation/providers/active_mascot_provider.dart';
import '../../domain/entities/drive_pass.dart';
import 'mission_provider.dart';

// Economia XP (0041): pass di guida, forzieri, cambio missione, sblocchi.
// Provider scritti a mano (niente @riverpod: build_runner non gira con
// questo SDK). Se la migrazione non c'è ancora, il pass resta null e la
// UI nasconde la sezione.

final drivePassProvider = FutureProvider.autoDispose<DrivePass?>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.id;
  if (uid == null) return null;
  try {
    final row = await ref.watch(missionRemoteDatasourceProvider).myPass();
    return row == null ? null : DrivePass.fromJson(row);
  } catch (_) {
    return null;
  }
});

/// Giorni (UTC, come i generatori) in cui l'utente ha già usato il cambio.
final missionSwapDaysProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.id;
  if (uid == null) return const {};
  final swaps = await ref.watch(missionRemoteDatasourceProvider).mySwaps();
  return {for (final s in swaps) dayKey(s.day)};
});

/// "2026-11-10": per confrontare il giorno di un cambio (colonna date) con
/// l'inizio UTC delle giornaliere.
String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

final openedChestsProvider = FutureProvider.autoDispose<Set<String>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.id;
  if (uid == null) return Future.value(const <String>{});
  return ref.watch(missionRemoteDatasourceProvider).myChests();
});

final unlocksProvider = FutureProvider.autoDispose<Unlocks>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.id;
  if (uid == null) return const Unlocks({});
  return Unlocks(
      await ref.watch(missionRemoteDatasourceProvider).myUnlocks(uid));
});

/// Chiave del periodo di un forziere, come `claim_mission_chest`: inizio
/// delle missioni del periodo in UTC, "YYYYMMDD".
String chestPeriodKey(String kind, DateTime startsAt) {
  final u = startsAt.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '$kind:${u.year}${two(u.month)}${two(u.day)}';
}

final bondPointsProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.id;
  if (uid == null) return const {};
  return ref.watch(missionRemoteDatasourceProvider).myBond(uid);
});

/// Legame con la mascotte attiva.
final activeBondProvider = Provider.autoDispose<BondProgress>((ref) {
  final id = ref.watch(activeMascotProvider).id;
  return BondProgress(ref.watch(bondPointsProvider).valueOrNull?[id] ?? 0);
});

/// Cosmetici attivi: dal pass (profile_unlocks) o dal legame.
class Cosmetics {
  const Cosmetics({
    required this.celebration,
    required this.neonSkin,
    required this.title,
  });

  /// Emote esultanza nel Risultato (pass o legame LV2).
  final bool celebration;

  /// Bagliore neon sull'arte della mascotte (pass o legame LV5).
  final bool neonSkin;

  /// "LEGGENDA DI NITRO" (legame LV10) o "RE DELLA STAGIONE" (pass).
  final String? title;
}

final cosmeticsProvider = Provider.autoDispose<Cosmetics>((ref) {
  final unlocks = ref.watch(unlocksProvider).valueOrNull ?? const Unlocks({});
  final bond = ref.watch(activeBondProvider);
  final mascot = ref.watch(activeMascotProvider);
  return Cosmetics(
    celebration: unlocks.emote || bond.unlocked(2),
    neonSkin: unlocks.neonSkin || bond.unlocked(5),
    title: bond.unlocked(10)
        ? 'LEGGENDA DI ${mascot.name.toUpperCase()}'
        : unlocks.seasonTitle
            ? 'RE DELLA STAGIONE'
            : null,
  );
});
