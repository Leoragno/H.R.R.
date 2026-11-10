import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../../pilots/presentation/widgets/pilot_emblem.dart';
import '../../../progression/domain/progression.dart';
import '../../domain/driver_archetype.dart';
import '../../domain/entities/trip.dart';
import '../providers/trip_provider.dart';
import '../widgets/route_preview_painter.dart';
import '../widgets/trip_stat_card.dart'
    show
        accelHint,
        decelHint,
        formatStoppedTime,
        formatTripDuration,
        gForceHint;

String _two(int n) => n.toString().padLeft(2, '0');

/// Dettaglio guida (handoff HEAT, schermata 9), dai dati persistiti del
/// viaggio: tracciato, FLOW e grado, numeri chiave, ricompense, pilota del
/// viaggio, griglia statistiche, elimina. I grafici velocità/quota non ci
/// sono: i campioni di telemetria non vengono salvati.
class TripDetailScreen extends ConsumerWidget {
  final String tripId;
  const TripDetailScreen({super.key, required this.tripId});

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColor.surfaceHigh,
        title: const Text('Eliminare il viaggio?'),
        content: const Text(
            'Il viaggio verrà rimosso dal tuo storico. XP e REP già assegnati restano.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Elimina', style: TextStyle(color: AppColor.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(tripRepositoryProvider).discardTrip(id);
    if (!context.mounted) return;
    ref.invalidate(recentTripsProvider);
    context.canPop() ? context.pop() : context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripByIdProvider(tripId));
    return Scaffold(
      backgroundColor: AppColor.base,
      body: tripAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: AppColor.accent)),
        error: (e, _) => SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.pop(),
                  icon:
                      const Icon(Icons.arrow_back_rounded, color: AppColor.ink),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text('Viaggio non trovato',
                      style: AppType.body.copyWith(color: AppColor.danger)),
                ),
              ),
            ],
          ),
        ),
        data: (trip) => _Body(
          trip: trip,
          onDelete: () => _confirmDelete(context, ref, trip.id),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.trip, required this.onDelete});
  final Trip trip;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final d = trip.startedAt;
    final night = isNightTime(d);
    final score = trip.drivingScore;
    final input = DrivingStyleInput.fromTrip(trip);
    final match = input == null ? null : matchDriverArchetype(input);
    final top = MediaQuery.paddingOf(context).top;
    var i = 0;

    return ListView(
      padding:
          EdgeInsets.only(bottom: 30 + MediaQuery.paddingOf(context).bottom),
      children: [
        // Tracciato a tutta larghezza su griglia scura.
        SizedBox(
          height: 250 + top,
          child: Stack(
            children: [
              const Positioned.fill(
                  child: CustomPaint(painter: _GridPainter())),
              if (trip.route.length >= 2)
                Positioned.fill(
                  top: top + 50,
                  bottom: 30,
                  child: RoutePreview(points: trip.route),
                ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 70,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x000B0912), AppColor.base],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 6,
                top: top + 4,
                child: IconButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go(AppRoutes.home),
                  icon:
                      const Icon(Icons.arrow_back_rounded, color: AppColor.ink),
                ),
              ),
              Positioned(
                right: 14,
                bottom: 14,
                child: Row(
                  children: [
                    const _Legend(color: AppColor.ink, label: 'PARTENZA'),
                    const SizedBox(width: 12),
                    _Legend(color: AppColor.accent, label: 'ARRIVO'),
                  ],
                ),
              ),
            ],
          ),
        ),
        HeatEnter(
          index: i++,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            night
                                ? Icons.nightlight_round
                                : Icons.wb_sunny_rounded,
                            size: 16,
                            color: night ? AppColor.night : AppColor.day,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${night ? 'NOTTE' : 'GIORNO'} · '
                            '${_two(d.day)}/${_two(d.month)}/${d.year} · '
                            '${_two(d.hour)}:${_two(d.minute)}',
                            style: AppType.label.copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: 'FLOW ',
                            style: AppType.label.copyWith(
                                fontSize: 16,
                                letterSpacing: 3,
                                color: AppColor.accent),
                          ),
                          TextSpan(
                            text: score?.toString() ?? '—',
                            style: AppType.display(
                                fontWeight: FontWeight.w900,
                                fontSize: 64,
                                height: 1),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
                if (score != null)
                  GraffitiText(flowGrade(score), fontSize: 72, angle: -0.14),
              ],
            ),
          ),
        ),
        HeatEnter(
          index: i++,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: _KeyNumbers(cells: [
              ('DISTANZA', trip.distanceKm.toStringAsFixed(1), 'km'),
              ('DURATA', formatTripDuration(trip.durationSeconds), ''),
              (
                'VEL. MEDIA',
                trip.avgSpeedKmh?.toStringAsFixed(0) ?? '—',
                'km/h'
              ),
              (
                'VEL. MASSIMA',
                trip.maxSpeedKmh?.toStringAsFixed(0) ?? '—',
                'km/h'
              ),
            ]),
          ),
        ),
        HeatEnter(
          index: i++,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(
              children: [
                for (final (label, value, color) in [
                  ('XP', '+${trip.xpEarned}', AppColor.gold),
                  ('REP', '+${trip.repEarned}', AppColor.ink),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: HeatPanel(
                      shape: const SlantBorder.all(10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 7),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(label,
                                style: AppType.label.copyWith(
                                    fontSize: 15, letterSpacing: 1.6)),
                          ),
                          Text(value,
                              style: AppType.display(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 26,
                                  color: color)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (match != null) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: SectionLabel('PILOTA DEL VIAGGIO'),
          ),
          HeatEnter(
            index: i++,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: HeatPanel(
                shape: const ChamferBorder(cut: 14),
                borderColor: AppColor.line,
                padding: const EdgeInsets.all(14),
                onTap: () => context.push(AppRoutes.pilots),
                child: Row(
                  children: [
                    PilotEmblem(monogram: match.archetype.monogram),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(match.archetype.name,
                              style: AppType.display(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  height: 1)),
                          const SizedBox(height: 4),
                          Text(match.archetype.tagline,
                              style: AppType.caption.copyWith(height: 1.35)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColor.inkFaint),
                  ],
                ),
              ),
            ),
          ),
        ],
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
          child: SectionLabel('STATISTICHE'),
        ),
        HeatEnter(
          index: i++,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _StatsGrid(trip: trip),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: AppColor.danger),
            label: Text('Elimina viaggio',
                style: AppType.body.copyWith(color: AppColor.danger)),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppType.label.copyWith(fontSize: 11)),
        ],
      );
}

/// Griglia "strade" del prototipo dietro al tracciato.
class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColor.base);
    final p = Paint()..color = AppColor.surface;
    for (double x = 58; x < size.width; x += 61) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 3, size.height), p);
    }
    for (double y = 66; y < size.height; y += 69) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 3), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

class _KeyNumbers extends StatelessWidget {
  const _KeyNumbers({required this.cells});
  final List<(String, String, String)> cells;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var r = 0; r < cells.length; r += 2) ...[
          if (r > 0) const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = r; c < r + 2 && c < cells.length; c++) ...[
                if (c > r) const SizedBox(width: 5),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: const ShapeDecoration(
                      color: AppColor.surface,
                      shape: ChamferBorder(cut: 10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cells[c].$1,
                            style: AppType.label
                                .copyWith(fontSize: 12, letterSpacing: 1.6)),
                        Text.rich(
                          TextSpan(text: cells[c].$2, children: [
                            if (cells[c].$3.isNotEmpty)
                              TextSpan(
                                text: ' ${cells[c].$3}',
                                style: AppType.display(
                                    fontSize: 14,
                                    italic: false,
                                    color: AppColor.inkMuted),
                              ),
                          ]),
                          maxLines: 1,
                          style: AppType.display(
                              fontWeight: FontWeight.w900,
                              fontSize: 28,
                              height: 1.05),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// Statistiche persistite da complete_trip (0030/0032). '—' per i campi
/// assenti (viaggi precedenti alla migrazione, o quota GPS mancante).
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    String n(num? v, [int digits = 0]) =>
        v == null ? '—' : v.toStringAsFixed(digits);
    final peakG = trip.peakGForce;
    final maxAccel = trip.maxAccelerationMs2;
    final maxDecel = trip.maxDecelerationMs2;
    final stats = <(String, String, String, String?)>[
      (
        'DA FERMO',
        trip.stoppedSeconds == null
            ? '—'
            : formatStoppedTime(Duration(seconds: trip.stoppedSeconds!)),
        '',
        null
      ),
      ('SOSTE', n(trip.totalStops), '', null),
      ('0-100', n(trip.zeroToHundredSeconds, 2), 's', null),
      ('FRENATE', n(trip.brakingEvents), '', null),
      ('SVOLTE SX', n(trip.turnsLeft), '', null),
      ('SVOLTE DX', n(trip.turnsRight), '', null),
      ('CAMBI CORSIA', n(trip.laneChanges), '', null),
      ('PICCO G', n(peakG, 2), 'G', peakG == null ? null : gForceHint(peakG)),
      ('MAX IN CURVA', n(trip.maxCorneringSpeedKmh), 'km/h', null),
      (
        'ACCEL. MAX',
        n(maxAccel, 1),
        'm/s²',
        maxAccel == null ? null : accelHint(maxAccel)
      ),
      (
        'DECEL. MAX',
        maxDecel == null ? '—' : maxDecel.abs().toStringAsFixed(1),
        'm/s²',
        maxDecel == null ? null : decelHint(maxDecel)
      ),
      ('DISLIVELLO', n(trip.elevationGainM), 'm', null),
      ('ALTITUDINE MAX', n(trip.maxAltitudeM), 'm', null),
    ];
    return LayoutBuilder(builder: (context, c) {
      const gap = 5.0;
      final w = (c.maxWidth - gap * 2) / 3;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final (label, value, unit, hint) in stats)
            Container(
              width: w,
              padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
              color: AppColor.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.label
                          .copyWith(fontSize: 10, letterSpacing: 1.2)),
                  Text.rich(
                    TextSpan(text: value, children: [
                      if (unit.isNotEmpty && value != '—')
                        TextSpan(
                          text: ' $unit',
                          style: AppType.display(
                              fontSize: 11,
                              italic: false,
                              color: AppColor.inkMuted),
                        ),
                    ]),
                    maxLines: 1,
                    style: AppType.display(
                        fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                  if (hint != null)
                    Text(hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.caption.copyWith(fontSize: 10)),
                ],
              ),
            ),
        ],
      );
    });
  }
}
