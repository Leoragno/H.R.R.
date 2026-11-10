import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../../../core/widgets/recenter_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../rival/presentation/providers/active_mascot_provider.dart';
import '../../domain/entities/territory_cell.dart';
import '../../domain/territory_color.dart';
import '../../domain/territory_decay.dart';
import '../providers/game_controller.dart';
import '../providers/territory_provider.dart';
import '../widgets/game_map_background.dart';
import '../widgets/territory_panel.dart';

/// GIOCA (HEAT, handoff §10): mappa a esagoni a tutto schermo, badge del
/// giocatore con area e titolo di zona, contatori TUOI / RIVALI / A
/// RISCHIO, card della cella toccata e pannello classifica territorio.
///
/// Le celle si conquistano guidando (flusso GPS di [GameController],
/// indipendente da Trip Live). La mappa è navigabile liberamente: la
/// camera non segue ogni fix, vedi [_recenter].
///
/// Elemento acceso: i miei esagoni sulla mappa (l'area nel badge ne è la
/// legenda). Tutto il resto resta in inchiostro/semantico.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final _mapKey = GlobalKey<GameMapBackgroundState>();
  TerritoryCell? _selected;

  Future<void> _recenter(GameController controller) async {
    await controller.recenterNow();
    await _mapKey.currentState?.recenter();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final me = ref.watch(myProfileProvider).valueOrNull;
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final mascot = ref.watch(activeMascotProvider);

    final counts = _Counts.of(state.visibleCells.values, myId,
        territoryDecayDaysForMascot(mascot.id));
    final selected = _selected;
    const bottomInset = kTerritoryPanelCollapsedHeight + 10;

    return Scaffold(
      backgroundColor: AppColor.void_,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GameMapBackground(
            key: _mapKey,
            lat: state.focusLat,
            lon: state.focusLon,
            cells: state.visibleCells,
            mode: state.mapMode,
            myProfileId: myId,
            onViewportChanged: controller.onViewportChanged,
            onCellTapped: (c) => setState(() => _selected = c),
          ),
          // Sfumatura in alto per leggere i badge sopra la mappa.
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 210,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xF50B0912), Color(0x000B0912)],
                    stops: [.4, 1],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PlayerBadge(
                          name: me?.username ?? me?.displayName ?? 'pilota',
                          faceAsset: 'assets/faces/${mascot.id}.png',
                          areaKm2: state.areaKm2(),
                        ),
                        const SizedBox(height: 6),
                        _ZoneTitle(label: counts.zoneTitle),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _CountChip(
                          label: 'TUOI',
                          value: counts.mine,
                          color: AppColor.accent),
                      const SizedBox(height: 4),
                      _CountChip(
                          label: 'RIVALI',
                          value: counts.rivals,
                          color: AppColor.danger),
                      const SizedBox(height: 4),
                      _CountChip(
                          label: 'A RISCHIO',
                          value: counts.atRisk,
                          color: AppColor.gold),
                      const SizedBox(height: 8),
                      HeatChip(
                        label: state.mapMode == GameMapMode.mineOnly
                            ? 'SOLO MIEI'
                            : 'TUTTI',
                        height: 30,
                        leading: const Icon(Icons.layers_rounded,
                            size: 16, color: AppColor.inkMuted),
                        onTap: () => controller.setMapMode(
                          state.mapMode == GameMapMode.mineOnly
                              ? GameMapMode.solo
                              : GameMapMode.mineOnly,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: bottomInset,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6, bottom: 8),
                    child: RecenterButton(onTap: () => _recenter(controller)),
                  ),
                ),
                if (state.gpsStatus == GameGpsStatus.denied ||
                    state.gpsStatus == GameGpsStatus.disabled) ...[
                  _GpsBanner(
                    status: state.gpsStatus,
                    onRetry: controller.recenterNow,
                  ),
                  const SizedBox(height: 6),
                ],
                if (selected != null && !state.panelExpanded)
                  _CellCard(
                    key: ValueKey(selected.coord.key),
                    cell: selected,
                    isMine: selected.ownerId == myId,
                    myFace: 'assets/faces/${mascot.id}.png',
                    onClose: () => setState(() => _selected = null),
                  ),
              ],
            ),
          ),
          const TerritoryPanel(),
        ],
      ),
    );
  }
}

/// Conteggi sulle celle inquadrate + titolo di zona.
class _Counts {
  const _Counts(this.mine, this.rivals, this.atRisk, this.zoneTitle);

  final int mine;
  final int rivals;
  final int atRisk;
  final String zoneTitle;

  static _Counts of(
      Iterable<TerritoryCell> cells, String? myId, int myDecayDays) {
    final byOwner = <String, int>{};
    var mine = 0, rivals = 0, atRisk = 0;
    final now = DateTime.now();
    for (final c in cells) {
      byOwner[c.ownerId] = (byOwner[c.ownerId] ?? 0) + 1;
      if (c.ownerId == myId) {
        mine++;
        if (territoryDaysLeft(c, now, myDecayDays) <= kTerritoryWarningDays) {
          atRisk++;
        }
      } else {
        rivals++;
      }
    }
    var bestRival = 0;
    byOwner.forEach((owner, n) {
      if (owner != myId && n > bestRival) bestRival = n;
    });
    final title = mine == 0
        ? 'ESPLORATORE'
        : mine > bestRival
            ? 'RE DELLA ZONA'
            : 'SCALATORE DELLA ZONA';
    return _Counts(mine, rivals, atRisk, title);
  }
}

class _PlayerBadge extends StatelessWidget {
  const _PlayerBadge({
    required this.name,
    required this.faceAsset,
    required this.areaKm2,
  });

  final String name;
  final String faceAsset;
  final double areaKm2;

  @override
  Widget build(BuildContext context) {
    final area =
        areaKm2 < .1 ? areaKm2.toStringAsFixed(3) : areaKm2.toStringAsFixed(1);
    return HeatPanel(
      shape: const SlantBorder(left: 0, right: 12),
      color: const Color(0xEB14121C),
      padding: const EdgeInsets.fromLTRB(4, 4, 22, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: Image.asset(
              faceAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: AppColor.surfaceHigh),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    AppType.display(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${area.replaceAll('.', ',')} KM²',
            style: AppType.display(
              fontSize: 17,
              italic: false,
              color: AppColor.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneTitle extends StatelessWidget {
  const _ZoneTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return HeatPanel(
      shape: const SlantBorder.all(6),
      color: AppColor.ink,
      borderColor: null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium_rounded,
              size: 16, color: AppColor.onAccent),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppType.display(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: AppColor.onAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return HeatPanel(
      shape: const SlantBorder.all(6),
      color: const Color(0xEB14121C),
      borderColor: null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: SizedBox(
        width: 84,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                label,
                style: AppType.display(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  italic: false,
                  letterSpacing: 1.4,
                  color: AppColor.inkMuted,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Text(
                '$value',
                style: AppType.display(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nome del proprietario di una cella rivale (una query per proprietario).
final _ownerNameProvider = FutureProvider.autoDispose.family<String?, String>(
  (ref, ownerId) =>
      ref.read(territoryRepositoryProvider).profileDisplayName(ownerId),
);

/// Card della cella toccata: di chi è, quanto le resta, cosa fare.
class _CellCard extends ConsumerWidget {
  const _CellCard({
    super.key,
    required this.cell,
    required this.isMine,
    required this.myFace,
    required this.onClose,
  });

  final TerritoryCell cell;
  final bool isMine;
  final String myFace;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = isMine ? AppColor.accent : rivalColorFor(cell.ownerId);
    final days = territoryDaysLeft(
        cell,
        null,
        isMine
            ? territoryDecayDaysForMascot(ref.watch(activeMascotProvider).id)
            : kTerritoryDecayDays);
    final daysText = territoryDaysLabel(days).toLowerCase();
    final atRisk = days <= kTerritoryWarningDays;
    final ownerName =
        isMine ? null : ref.watch(_ownerNameProvider(cell.ownerId)).valueOrNull;

    return HeatEnter(
      child: Container(
        decoration: BoxDecoration(
          color: AppColor.surface,
          border: Border(
            top: BorderSide(color: c, width: 2),
            left: const BorderSide(color: AppColor.line),
            right: const BorderSide(color: AppColor.line),
            bottom: const BorderSide(color: AppColor.line),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMine) ...[
              SizedBox(
                width: 58,
                height: 58,
                child: Image.asset(
                  myFace,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: isMine
                            ? _tag('#${cell.coord.q},${cell.coord.r} · TUO', c)
                            : _tag(
                                '#${cell.coord.q},${cell.coord.r} · '
                                '${ownerName == null ? 'RIVALE' : 'DI ${ownerName.toUpperCase()}'}',
                                c,
                              ),
                      ),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: onClose,
                          icon: const Icon(Icons.close_rounded,
                              size: 20, color: AppColor.inkMuted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isMine
                        ? (atRisk
                            ? 'decade $daysText se non ci ripassi. guidaci sopra per rinnovarla.'
                            : 'è tua. al sicuro ancora per $daysText.')
                        : 'guidaci sopra per rubarla e colorarla col tuo neon.',
                    style: AppType.text(fontSize: 14, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: HeatButton(
                      label: isMine ? 'I MIEI TERRITORI' : 'GUIDA E RUBALA',
                      icon: isMine
                          ? Icons.list_rounded
                          : Icons.directions_car_rounded,
                      height: 42,
                      fontSize: 18,
                      color: c,
                      glow: false,
                      onPressed: () => context.push(
                        isMine ? AppRoutes.myTerritories : AppRoutes.tripLive,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color c) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppType.display(
          fontSize: 14,
          italic: false,
          letterSpacing: 1.6,
          color: c,
        ),
      );
}

class _GpsBanner extends StatelessWidget {
  const _GpsBanner({required this.status, required this.onRetry});

  final GameGpsStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = status == GameGpsStatus.denied
        ? 'permesso posizione negato: attivalo per conquistare territorio.'
        : 'GPS spento: attivalo per conquistare territorio.';
    return Container(
      decoration: const BoxDecoration(
        color: AppColor.surface,
        border: Border(left: BorderSide(color: AppColor.gold, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      child: Row(
        children: [
          const Icon(Icons.gps_off_rounded, color: AppColor.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: AppType.text(fontSize: 12.5)),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'RIPROVA',
              style: AppType.display(
                fontSize: 15,
                italic: false,
                letterSpacing: 1.2,
                color: AppColor.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
