import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/territory_cell.dart';
import '../providers/territory_location_provider.dart';
import '../providers/territory_provider.dart';

// Devono restare allineate a territory_decay_days() in 0026_territory_
// decay_counterattack.sql e alla soglia di sbiadimento usata sulla mappa
// (game_map_background.dart).
const _kDecayDays = 14;
const _kFadeWarningDays = 3;

double _daysLeft(TerritoryCell cell) =>
    _kDecayDays - DateTime.now().difference(cell.claimedAt).inHours / 24;

sealed class _ListItem {
  const _ListItem();
}

class _CountryHeader extends _ListItem {
  final String country;
  const _CountryHeader(this.country);
}

class _RegionHeader extends _ListItem {
  final String region;
  const _RegionHeader(this.region);
}

class _TownHeader extends _ListItem {
  final String town;
  final int count;
  const _TownHeader(this.town, this.count);
}

class _CellRow extends _ListItem {
  final TerritoryCell cell;
  const _CellRow(this.cell);
}

/// "I miei territori" (brief, punto 1): tutti i pentagoni posseduti,
/// raggruppati per stato/regione/paese (dal reverse geocoding del centro
/// di ogni cella, vedi territory_location_provider.dart) e, dentro ogni
/// gruppo, ordinati per scadenza più vicina prima — stesso criterio con
/// cui la RPC `my_territories` restituiva già la lista piatta.
class MyTerritoriesScreen extends ConsumerWidget {
  const MyTerritoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final territoriesAsync = ref.watch(myTerritoriesProvider);
    final locationsAsync = ref.watch(territoryCellLocationsProvider);

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
          final locations = locationsAsync.valueOrNull;
          final items = locations == null
              ? [for (final cell in cells) _CellRow(cell)]
              : _groupedItems(cells, locations);

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpace.md),
            itemCount: items.length +
                (expiring.isEmpty ? 0 : 1) +
                (locations == null ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: AppSpace.sm),
            itemBuilder: (context, i) {
              var index = i;
              if (expiring.isNotEmpty) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.xs),
                    child: Text(
                      '${expiring.length} IN SCADENZA',
                      style: AppType.label.copyWith(color: AppColor.amber),
                    ),
                  );
                }
                index--;
              }
              if (locations == null) {
                if (index == 0) {
                  return Text(
                    'Raggruppamento per zona in corso…',
                    style: AppType.caption,
                  );
                }
                index--;
              }
              return _buildItem(items[index]);
            },
          );
        },
      ),
    );
  }

  List<_ListItem> _groupedItems(
      List<TerritoryCell> cells, Map<String, TerritoryLocation> locations) {
    // stato -> regione -> paese -> celle (ordinate per scadenza più vicina).
    final tree = <String, Map<String, Map<String, List<TerritoryCell>>>>{};
    for (final cell in cells) {
      final loc = locations[cell.coord.key] ?? TerritoryLocation.unknown;
      tree
          .putIfAbsent(loc.country, () => {})
          .putIfAbsent(loc.region, () => {})
          .putIfAbsent(loc.town, () => [])
          .add(cell);
    }

    final items = <_ListItem>[];
    for (final country in tree.keys.toList()..sort()) {
      items.add(_CountryHeader(country));
      final regions = tree[country]!;
      for (final region in regions.keys.toList()..sort()) {
        items.add(_RegionHeader(region));
        final towns = regions[region]!;
        for (final town in towns.keys.toList()..sort()) {
          final townCells = towns[town]!
            ..sort((a, b) => _daysLeft(a).compareTo(_daysLeft(b)));
          items.add(_TownHeader(town, townCells.length));
          items.addAll(townCells.map(_CellRow.new));
        }
      }
    }
    return items;
  }

  Widget _buildItem(_ListItem item) => switch (item) {
        _CountryHeader(:final country) => Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm, bottom: 2),
            child: Row(
              children: [
                const Icon(Icons.public_rounded,
                    size: 16, color: AppColor.ink),
                const SizedBox(width: AppSpace.xs),
                Text(country.toUpperCase(),
                    style: AppType.title.copyWith(fontSize: 16)),
              ],
            ),
          ),
        _RegionHeader(:final region) => Padding(
            padding: const EdgeInsets.only(left: AppSpace.md, bottom: 2),
            child: Text(region, style: AppType.label),
          ),
        _TownHeader(:final town, :final count) => Padding(
            padding: const EdgeInsets.only(left: AppSpace.lg, bottom: 2),
            child: Text('$town · $count',
                style: AppType.caption.copyWith(color: AppColor.inkMuted)),
          ),
        _CellRow(:final cell) => Padding(
            padding: const EdgeInsets.only(left: AppSpace.lg),
            child: _TerritoryRow(cell: cell),
          ),
      };
}

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
