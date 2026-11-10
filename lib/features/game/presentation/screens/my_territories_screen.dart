import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../domain/entities/territory_cell.dart';
import '../../domain/territory_decay.dart';
import '../../../rival/presentation/providers/active_mascot_provider.dart';
import '../providers/territory_location_provider.dart';
import '../providers/territory_provider.dart';

/// I MIEI TERRITORI (HEAT, handoff §11): le celle possedute raggruppate per
/// zona (città dal reverse geocoding, vedi territory_location_provider),
/// con barra di decadimento e giorni rimasti della cella più a rischio.
/// Tocca una zona per vederne le singole celle.
///
/// Niente accento qui: le zone al sicuro restano in inchiostro, quelle a
/// rischio usano i colori semantici (oro / rosso) così saltano all'occhio.
class MyTerritoriesScreen extends ConsumerWidget {
  const MyTerritoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final territoriesAsync = ref.watch(myTerritoriesProvider);
    final locations = ref.watch(territoryCellLocationsProvider).valueOrNull;
    final decay =
        territoryDecayDaysForMascot(ref.watch(activeMascotProvider).id);

    return Scaffold(
      backgroundColor: AppColor.base,
      body: HeatBackground(
        glow: false,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 30),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go(AppRoutes.game),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppColor.ink),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ScreenTitle('I miei\nterritori', fontSize: 48),
                    const SizedBox(height: 10),
                    Text(
                      'ogni zona decade se non ci passi. tocca una zona per '
                      'vedere le sue celle.',
                      style: AppType.text(
                          fontSize: 14, color: AppColor.inkMuted, height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...territoriesAsync.when(
                loading: () => const [
                  SizedBox(
                    height: 200,
                    child: Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppColor.inkMuted),
                      ),
                    ),
                  ),
                ],
                error: (e, _) => const [
                  _Message('territori non disponibili. riprova più tardi.'),
                ],
                data: (cells) {
                  if (cells.isEmpty) {
                    return const [
                      _Message('nessun territorio conquistato ancora.\n'
                          'guida per rivendicare i primi esagoni.'),
                    ];
                  }
                  final zones = _zones(cells, locations, decay);
                  return [
                    if (locations == null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                        child:
                            Text('raggruppo per zona…', style: AppType.caption),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        children: [
                          for (final (i, z) in zones.indexed) ...[
                            if (i > 0) const SizedBox(height: 6),
                            HeatEnter(
                              index: i.clamp(0, 12),
                              child: _ZoneTile(zone: z),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Zone ordinate dalla più a rischio; dentro, celle per scadenza.
  static List<_Zone> _zones(
    List<TerritoryCell> cells,
    Map<String, TerritoryLocation>? locations,
    int decay,
  ) {
    final now = DateTime.now();
    final byZone = <String, List<TerritoryCell>>{};
    final regionOf = <String, String>{};
    for (final c in cells) {
      final loc = locations?[c.coord.key];
      final name = loc == null ? 'zona sconosciuta' : loc.town;
      byZone.putIfAbsent(name, () => []).add(c);
      if (loc != null) regionOf[name] = loc.region;
    }
    final zones = [
      for (final e in byZone.entries)
        _Zone(
          name: e.key,
          region: regionOf[e.key],
          cells: e.value
            ..sort((a, b) => territoryDaysLeft(a, now, decay)
                .compareTo(territoryDaysLeft(b, now, decay))),
          minDays: territoryDaysLeft(
              e.value.reduce((a, b) => territoryDaysLeft(a, now, decay) <
                      territoryDaysLeft(b, now, decay)
                  ? a
                  : b),
              now,
              decay),
          decayDays: decay,
        ),
    ]..sort((a, b) => a.minDays.compareTo(b.minDays));
    return zones;
  }
}

class _Zone {
  const _Zone({
    required this.name,
    required this.region,
    required this.cells,
    required this.minDays,
    required this.decayDays,
  });

  final String name;
  final String? region;
  final List<TerritoryCell> cells;
  final double minDays;
  final int decayDays;
}

Color _daysColor(double days) => days < 1
    ? AppColor.danger
    : days <= kTerritoryWarningDays
        ? AppColor.gold
        : AppColor.ink;

String _status(double days) => days < 1
    ? 'in scadenza · passaci oggi'
    : days <= kTerritoryWarningDays
        ? 'a rischio · ripassaci presto'
        : 'al sicuro';

class _ZoneTile extends StatefulWidget {
  const _ZoneTile({required this.zone});

  final _Zone zone;

  @override
  State<_ZoneTile> createState() => _ZoneTileState();
}

class _ZoneTileState extends State<_ZoneTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final z = widget.zone;
    final c = _daysColor(z.minDays);
    // 7 segmenti sui 14 giorni di vita: uno ogni 2 giorni.
    final filled = (z.minDays / 2).ceil().clamp(0, 7);
    final sub = [
      _status(z.minDays),
      if (z.region != null && z.region!.isNotEmpty) z.region!,
    ].join(' · ');

    return HeatPressable(
      onTap: () => setState(() => _open = !_open),
      child: Container(
        decoration: BoxDecoration(
          color: AppColor.surface,
          border: Border(left: BorderSide(color: c, width: 3)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              z.name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.display(
                                  fontSize: 22, fontWeight: FontWeight.w900),
                            ),
                          ),
                          Text(
                            '${z.cells.length} esagoni',
                            style: AppType.display(
                              fontSize: 15,
                              italic: false,
                              color: AppColor.inkMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SkewBar(
                        value: filled / 7,
                        segments: 7,
                        gap: 2,
                        color: c,
                      ),
                      const SizedBox(height: 6),
                      Text(sub,
                          style: AppType.text(
                              fontSize: 12, color: AppColor.inkMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 74,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        territoryDaysLabel(z.minDays),
                        maxLines: 1,
                        softWrap: false,
                        style: AppType.display(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: c,
                        ),
                      ),
                      Text(
                        'RIMASTI',
                        style: AppType.text(
                          fontSize: 10,
                          letterSpacing: 1.4,
                          color: AppColor.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: AppMotion.base,
              curve: AppMotion.curve,
              alignment: Alignment.topCenter,
              child: !_open
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        children: [
                          for (final cell in z.cells)
                            _CellLine(cell: cell, decayDays: z.decayDays),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CellLine extends StatelessWidget {
  const _CellLine({required this.cell, required this.decayDays});

  final TerritoryCell cell;
  final int decayDays;

  @override
  Widget build(BuildContext context) {
    final days = territoryDaysLeft(cell, null, decayDays);
    final d = cell.claimedAt;
    final date =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColor.surfaceHigh)),
      ),
      child: Row(
        children: [
          Icon(Icons.hexagon_rounded, size: 16, color: _daysColor(days)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '#${cell.coord.q},${cell.coord.r} · presa il $date'
              '${cell.driveScore != null ? ' · FLOW ${cell.driveScore}' : ''}',
              style: AppType.text(fontSize: 12.5, color: AppColor.inkMuted),
            ),
          ),
          Text(
            territoryDaysLabel(days),
            style: AppType.display(
              fontSize: 14,
              italic: false,
              color: _daysColor(days),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
      child: Column(
        children: [
          const Icon(Icons.hexagon_outlined,
              size: 44, color: AppColor.inkFaint),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppType.text(
                fontSize: 13, color: AppColor.inkMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
