import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/territory_cell.dart';
import '../providers/territory_provider.dart';

// Devono restare allineate a territory_decay_days() in 0026_territory_
// decay_counterattack.sql e alla soglia di sbiadimento usata sulla mappa
// (game_map_background.dart).
const _kDecayDays = 14;
const _kFadeWarningDays = 3;

/// "I miei territori" (brief, punto 1): tutti i pentagoni posseduti, quelli
/// più vicini a scadere in cima — stesso ordinamento già dato dalla RPC
/// `my_territories`, nessun riordino lato client.
class MyTerritoriesScreen extends ConsumerWidget {
  const MyTerritoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final territoriesAsync = ref.watch(myTerritoriesProvider);

    return Scaffold(
      backgroundColor: AppColor.base,
      appBar: AppBar(title: const Text('I miei territori')),
      body: territoriesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColor.cyan)),
        error: (e, _) => Center(
          child: Text('Errore nel caricamento dei territori',
              style: AppType.text(color: AppColor.danger)),
        ),
        data: (cells) {
          if (cells.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Text(
                  'Nessun territorio conquistato ancora. Guida per '
                  'rivendicare i primi esagoni!',
                  textAlign: TextAlign.center,
                  style: AppType.text(color: AppColor.inkMuted),
                ),
              ),
            );
          }
          final expiring =
              cells.where((c) => _daysLeft(c) <= _kFadeWarningDays).toList();
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpace.md),
            itemCount: cells.length + (expiring.isEmpty ? 0 : 1),
            separatorBuilder: (_, __) => const SizedBox(height: AppSpace.sm),
            itemBuilder: (context, i) {
              if (expiring.isNotEmpty && i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.xs),
                  child: Text(
                    '${expiring.length} IN SCADENZA',
                    style: AppType.label.copyWith(color: AppColor.amber),
                  ),
                );
              }
              final cell = cells[i - (expiring.isEmpty ? 0 : 1)];
              return _TerritoryRow(cell: cell);
            },
          );
        },
      ),
    );
  }
}

double _daysLeft(TerritoryCell cell) =>
    _kDecayDays - DateTime.now().difference(cell.claimedAt).inHours / 24;

class _TerritoryRow extends StatelessWidget {
  final TerritoryCell cell;
  const _TerritoryRow({required this.cell});

  @override
  Widget build(BuildContext context) {
    final daysLeft = _daysLeft(cell);
    final expiring = daysLeft <= _kFadeWarningDays;
    final accent = expiring ? AppColor.amber : AppColor.cyan;
    final daysLabel = daysLeft <= 0
        ? 'in scadenza'
        : daysLeft < 1
            ? 'meno di 1 giorno'
            : '${daysLeft.floor()} giorni';

    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: expiring
          ? AppGlow.edge(accent)
          : AppGlow.card,
      child: Row(
        children: [
          Icon(Icons.hexagon_rounded, color: accent, size: 28),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Esagono ${cell.coord.q},${cell.coord.r}',
                    style: AppType.body),
                const SizedBox(height: 2),
                Text(
                  'Conquistato ${_formatDate(cell.claimedAt)}'
                  '${cell.driveScore != null ? ' · punteggio ${cell.driveScore}' : ''}',
                  style: AppType.caption,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(daysLabel,
                  style: AppType.text(
                      fontWeight: FontWeight.w700, color: accent)),
              Text('rimasti', style: AppType.caption),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}
