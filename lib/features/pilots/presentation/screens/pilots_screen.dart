import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../../progression/presentation/progression_providers.dart';
import '../../../trip/domain/driver_archetype.dart';
import '../widgets/pilot_emblem.dart';

/// "Che pilota sei": pilota attuale (il più frequente negli ultimi 10
/// viaggi), striscia degli ultimi 10 abbinamenti e collezione degli 11.
class PilotsScreen extends ConsumerWidget {
  const PilotsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(pilotHistoryProvider);
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppColor.base,
      body: HeatBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(0, top + 4, 0, 32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: IconButton(
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/home'),
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
                  const ScreenTitle('CHE PILOTA\nSEI', fontSize: 48),
                  const SizedBox(height: 6),
                  Text(
                    'ogni guida ti abbina a un pilota famoso. quello che esce '
                    'più spesso negli ultimi 10 viaggi diventa il tuo.',
                    style: AppType.body
                        .copyWith(color: AppColor.inkMuted, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            HeatEnter(
              index: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _MainPilotCard(history: h),
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: SectionLabel(
                'ULTIMI 10 VIAGGI',
                trailing: h.main == null
                    ? null
                    : '${h.tally[h.main] ?? 0}/${h.lastTen.length} '
                        '${h.main!.monogram}',
              ),
            ),
            const SizedBox(height: 8),
            HeatEnter(
              index: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _LastTenStrip(history: h),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  const Expanded(child: SectionLabel('COLLEZIONE')),
                  Text(
                    '${h.collected}/${DriverArchetype.values.length}',
                    style: AppType.display(
                        fontSize: 14, color: AppColor.gold, italic: false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: .72,
                children: [
                  for (final (i, a) in DriverArchetype.values.indexed)
                    HeatEnter(
                      index: 3 + i ~/ 3,
                      child: _CollectionCard(archetype: a, history: h),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _mainTag(PilotHistory h) {
  if (h.main == null) return 'NESSUN VIAGGIO ANCORA';
  if (!h.ready) return 'IN ANALISI · ${h.lastTen.length}/$kPilotWindow';
  if (h.isTie) return 'TESTA A TESTA CON ${h.tiedWith!.monogram}';
  return 'IL TUO PILOTA';
}

class _MainPilotCard extends StatelessWidget {
  const _MainPilotCard({required this.history});
  final PilotHistory history;

  @override
  Widget build(BuildContext context) {
    final a = history.main;
    final accent = AppColor.accent;
    return HeatPanel(
      shape: const ChamferBorder(cut: 18, bottomLeft: true),
      borderColor: accent,
      glow: accent,
      gradient: LinearGradient(
        colors: [accent.withValues(alpha: .3), AppColor.surface],
        stops: const [0, .7],
      ),
      padding: const EdgeInsets.all(16),
      onTap: a == null ? null : () => showPilotSheet(context, a, history),
      child: Row(
        children: [
          PilotEmblem(
            monogram: a?.monogram ?? '?',
            width: 78,
            color: accent,
            fill: const Color(0xFF1A0F18),
            textColor: accent,
            glow: true,
            locked: a == null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_mainTag(history),
                    style: AppType.label.copyWith(color: accent, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  a?.name ?? 'Guida per scoprirlo',
                  style: AppType.display(
                      fontWeight: FontWeight.w900, fontSize: 30, height: .95),
                ),
                if (a != null) ...[
                  const SizedBox(height: 2),
                  Text(a.source,
                      style: AppType.caption
                          .copyWith(fontSize: 13, color: AppColor.inkMuted)),
                  const SizedBox(height: 6),
                  Text(a.tagline,
                      style: AppType.body.copyWith(fontSize: 13, height: 1.4)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      MasteryStars(history.mastery(a)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text('MAESTRIA ${history.mastery(a)}/5',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.label.copyWith(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LastTenStrip extends StatelessWidget {
  const _LastTenStrip({required this.history});
  final PilotHistory history;

  @override
  Widget build(BuildContext context) {
    // Dal più vecchio al più recente, come una timeline letta da sinistra.
    final items = history.lastTen.reversed.toList();
    return LayoutBuilder(builder: (context, c) {
      const gap = 3.0;
      final w = (c.maxWidth - gap * (kPilotWindow - 1)) / kPilotWindow;
      return Row(
        children: [
          for (var i = 0; i < kPilotWindow; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            if (i < items.length)
              PilotEmblem(
                monogram: items[i].monogram,
                width: w,
                checker: false,
                color: items[i] == history.main
                    ? AppColor.accent
                    : AppColor.lineMuted,
                textColor: items[i] == history.main
                    ? AppColor.accent
                    : AppColor.inkMuted,
              )
            else
              PilotEmblem(
                  monogram: '', width: w, checker: false, fill: AppColor.deep),
          ],
        ],
      );
    });
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.archetype, required this.history});
  final DriverArchetype archetype;
  final PilotHistory history;

  @override
  Widget build(BuildContext context) {
    final seen = history.seen(archetype);
    final isMain = archetype == history.main;
    final accent = AppColor.accent;
    final count = history.totals[archetype] ?? 0;
    return HeatPanel(
      shape: const ChamferBorder(cut: 12),
      borderColor: isMain ? accent : AppColor.line,
      padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
      onTap: () => showPilotSheet(context, archetype, history),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PilotEmblem(
            monogram: archetype.monogram,
            width: 52,
            locked: !seen,
            color: isMain ? accent : (seen ? AppColor.lineMuted : AppColor.line),
            textColor: isMain ? accent : AppColor.ink,
            glow: isMain,
          ),
          const SizedBox(height: 8),
          Text(
            seen ? archetype.name : '???',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.display(
              fontSize: 14,
              height: 1.05,
              italic: false,
              color: seen ? AppColor.ink : AppColor.inkFaint,
            ),
          ),
          const SizedBox(height: 4),
          MasteryStars(history.mastery(archetype), size: 12),
          const SizedBox(height: 4),
          Text(
            isMain
                ? 'IL TUO'
                : seen
                    ? '$count ${count == 1 ? 'VIAGGIO' : 'VIAGGI'}'
                    : 'BLOCCATO',
            style: AppType.label.copyWith(
              fontSize: 10,
              letterSpacing: 1.4,
              color: isMain ? accent : AppColor.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet di dettaglio: COME SI OTTIENE + maestria.
Future<void> showPilotSheet(
    BuildContext context, DriverArchetype a, PilotHistory history) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .6),
    isScrollControlled: true,
    builder: (_) => _PilotSheet(archetype: a, history: history),
  );
}

class _PilotSheet extends StatelessWidget {
  const _PilotSheet({required this.archetype, required this.history});
  final DriverArchetype archetype;
  final PilotHistory history;

  @override
  Widget build(BuildContext context) {
    final a = archetype;
    final seen = history.seen(a);
    final c = a == history.main ? AppColor.accent : AppColor.inkMuted;
    final n = history.totals[a] ?? 0;
    final lv = history.mastery(a);
    final next = lv < kMasteryThresholds.length ? kMasteryThresholds[lv] : null;
    final prev = lv == 0 ? 0 : kMasteryThresholds[lv - 1];
    final frac = next == null ? 1.0 : (n - prev) / (next - prev);
    return Container(
      decoration: BoxDecoration(
        color: AppColor.surface,
        border: Border(top: BorderSide(color: c, width: 2)),
      ),
      padding: EdgeInsets.fromLTRB(
          18, 20, 18, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PilotEmblem(
                monogram: a.monogram,
                width: 70,
                color: c,
                fill: AppColor.deep,
                textColor: c,
                checker: false,
                glow: a == history.main,
                locked: !seen,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(seen ? a.name : '???',
                        style: AppType.display(
                            fontWeight: FontWeight.w900,
                            fontSize: 28,
                            height: .95)),
                    if (seen)
                      Text(a.source,
                          style: AppType.caption.copyWith(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      a == history.main
                          ? 'IL TUO PILOTA'
                          : seen
                              ? 'IN COLLEZIONE'
                              : 'NON ANCORA INCONTRATO',
                      style: AppType.label.copyWith(fontSize: 12, color: c),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (seen) ...[
            const SizedBox(height: 14),
            Text(a.tagline,
                style: AppType.body.copyWith(fontSize: 15, height: 1.45)),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColor.deep,
              border: Border(left: BorderSide(color: c, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('COME SI OTTIENE',
                    style: AppType.label.copyWith(fontSize: 12)),
                const SizedBox(height: 4),
                Text(a.howToGet,
                    style: AppType.body.copyWith(height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColor.deep,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('MAESTRIA $lv/5',
                          style: AppType.label.copyWith(fontSize: 12)),
                    ),
                    MasteryStars(lv, size: 18),
                  ],
                ),
                const SizedBox(height: 8),
                SkewBar(value: frac.clamp(0, 1), color: AppColor.gold),
                const SizedBox(height: 8),
                Text(
                  next == null
                      ? 'maestria completa: $n viaggi abbinati'
                      : 'ancora ${next - n} '
                          '${next - n == 1 ? 'viaggio' : 'viaggi'} '
                          'per la stella ${lv + 1}',
                  style: AppType.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          HeatGhostButton(
            label: 'CHIUDI',
            height: 50,
            fontSize: 17,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
