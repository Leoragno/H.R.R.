import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/car_glyph_icon.dart';
import '../../../../core/widgets/notification_bell_button.dart';
import '../../../../core/widgets/profile_avatar_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/game_controller.dart';
import '../widgets/game_map_background.dart';
import '../widgets/hex_map_painter.dart';
import '../widgets/territory_panel.dart';

/// Tab "Gioca": conquista territorio via GPS a esagoni (mockup
/// Guida.dc.html righe 720-835). Le celle si rivendicano camminando/
/// guidando mentre questa schermata è aperta — flusso GPS indipendente
/// da quello di Trip Live (concettualmente diverso: qui è conquista
/// ambientale, non un viaggio con inizio/fine esplicito).
class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final me = ref.watch(myProfileProvider).valueOrNull;
    final myId = ref.watch(authStateProvider).valueOrNull?.id;

    final zoneBadge = _zoneBadgeLabel(state, myId);

    return Scaffold(
      backgroundColor: AppColors.guidaBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GameMapBackground(lat: state.focusLat, lon: state.focusLon),
          // Scrim per far risaltare gli esagoni colorati e i badge sopra
          // le tile della mappa reale.
          Container(color: Colors.black.withValues(alpha: 0.32)),
          HexMapView(
            focus: state.focus,
            cells: state.visibleCells,
            mode: state.mapMode,
            myProfileId: myId,
            myCrewId: me?.crewId,
          ),
          if (state.focus != null)
            const Align(
              alignment: Alignment.center,
              child: _PositionArrow(),
            ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MapModeSelector(
                          mode: state.mapMode,
                          onSelect: controller.setMapMode,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const NotificationBellButton(size: 40),
                      const SizedBox(width: 10),
                      const ProfileAvatarButton(size: 40),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _PlayerBadge(
                    name: me?.displayName ?? me?.username ?? 'Pilota',
                    areaKm2: state.areaKm2(),
                  ),
                  const SizedBox(height: 8),
                  _ZoneBadge(label: zoneBadge),
                ],
              ),
            ),
          ),
          if (state.gpsStatus == GameGpsStatus.denied ||
              state.gpsStatus == GameGpsStatus.disabled)
            Positioned(
              left: 14,
              right: 14,
              bottom: kTerritoryPanelCollapsedHeight + 84,
              child: _GpsBanner(
                status: state.gpsStatus,
                onRetry: controller.recenterNow,
              ),
            ),
          Positioned(
            right: 16,
            bottom: kTerritoryPanelCollapsedHeight + 18,
            child: _RecenterButton(onTap: controller.recenterNow),
          ),
          const TerritoryPanel(),
        ],
      ),
    );
  }

  String _zoneBadgeLabel(GameState state, String? myId) {
    final localCounts = <String, int>{};
    for (final cell in state.visibleCells.values) {
      localCounts[cell.ownerId] = (localCounts[cell.ownerId] ?? 0) + 1;
    }
    final myLocalCount = myId == null ? 0 : (localCounts[myId] ?? 0);
    var bestRivalLocal = 0;
    localCounts.forEach((owner, count) {
      if (owner != myId && count > bestRivalLocal) bestRivalLocal = count;
    });

    if (myLocalCount == 0) return 'ESPLORATORE';
    return myLocalCount > bestRivalLocal
        ? 'RE DELLA ZONA'
        : 'SCALATORE DELLA ZONA';
  }
}

// Marker "sei qui" sopra la griglia esagonale. Un'icona nuda dello stesso
// colore ciano usato per le celle "mie" (vedi hex_map_painter._colorFor)
// diventava invisibile appena l'utente rivendicava la propria cella
// sotto: un badge scuro con bordo bianco dà sempre contrasto, qualunque
// sia il colore dell'esagono sottostante.
class _PositionArrow extends StatelessWidget {
  const _PositionArrow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0B101E),
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 6, spreadRadius: 1),
        ],
      ),
      child: const Icon(Icons.navigation_rounded,
          color: AppColors.guidaCyan, size: 20),
    );
  }
}

class _MapModeSelector extends StatelessWidget {
  final GameMapMode mode;
  final ValueChanged<GameMapMode> onSelect;
  const _MapModeSelector({required this.mode, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xDB0B101E),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x2E7896FF)),
      ),
      child: Row(
        children: [
          for (final m in GameMapMode.values) ...[
            if (m != GameMapMode.values.first) const SizedBox(width: 2),
            Expanded(
              child: _MapModeButton(
                label: m.label,
                selected: mode == m,
                onTap: () => onSelect(m),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MapModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MapModeButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected
                ? const LinearGradient(colors: [
                    Color(0xFF14E6FF),
                    Color(0xFF4A5BFF),
                    Color(0xFFFF2FD0),
                  ])
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.archivo(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color:
                  selected ? AppColors.guidaOnAccent : const Color(0xFFCFDCEC),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerBadge extends StatelessWidget {
  final String name;
  final double areaKm2;
  const _PlayerBadge({required this.name, required this.areaKm2});

  @override
  Widget build(BuildContext context) {
    final areaText = (areaKm2 < 0.1
        ? areaKm2.toStringAsFixed(3)
        : areaKm2.toStringAsFixed(2));
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      decoration: BoxDecoration(
        color: const Color(0xDB0B101E),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x2E7896FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFFE9E9E9),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: CarGlyphIcon(size: 28, color: Color(0xFF2A2A2A)),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.chakraPetch(
                  fontWeight: FontWeight.w800, fontSize: 22),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$areaText KM²',
            style:
                AppTheme.chakraPetch(fontWeight: FontWeight.w800, fontSize: 22),
          ),
        ],
      ),
    );
  }
}

class _ZoneBadge extends StatelessWidget {
  final String label;
  const _ZoneBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xE60B101E),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x47FF2D9B)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('♛', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTheme.archivo(
                fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.1),
          ),
          const SizedBox(width: 8),
          const Text('♛', style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

class _RecenterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RecenterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xD8121212),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Icon(Icons.my_location_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

class _GpsBanner extends StatelessWidget {
  final GameGpsStatus status;
  final VoidCallback onRetry;
  const _GpsBanner({required this.status, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final message = status == GameGpsStatus.denied
        ? 'Permesso posizione negato: attivalo per conquistare territorio.'
        : 'GPS disattivato: attivalo per conquistare territorio.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xE6161200),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neonAmber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.gps_off_rounded,
              color: AppColors.neonAmber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: AppTheme.archivo(fontSize: 12.5, color: Colors.white)),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text('Riprova',
                style: AppTheme.archivo(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neonAmber)),
          ),
        ],
      ),
    );
  }
}
