import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../../pilots/presentation/widgets/pilot_emblem.dart';
import '../../../trip/domain/entities/route_point.dart';
import '../social_providers.dart';

const _months = [
  'GEN',
  'FEB',
  'MAR',
  'APR',
  'MAG',
  'GIU',
  'LUG',
  'AGO',
  'SET',
  'OTT',
  'NOV',
  'DIC',
];

/// "10 – 16 NOV" (lunedì – domenica della settimana di [from]).
String weekRangeLabel(DateTime from) {
  final to = from.add(const Duration(days: 6));
  return from.month == to.month
      ? '${from.day} – ${to.day} ${_months[to.month - 1]}'
      : '${from.day} ${_months[from.month - 1]} – ${to.day} ${_months[to.month - 1]}';
}

String _km(double v) =>
    v.toStringAsFixed(v >= 100 ? 0 : 1).replaceAll('.', ',');

/// La tua settimana (HEAT): cinque slide in stile storie — km, pilota
/// della settimana, territorio, classifica amici, guida migliore. Tocco a
/// destra avanti, a sinistra indietro. Un accento per slide: il numero
/// protagonista (sull'ultima, la CTA).
class WeekScreen extends ConsumerStatefulWidget {
  const WeekScreen({super.key});

  @override
  ConsumerState<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends ConsumerState<WeekScreen> {
  static const _count = 5;
  int _i = 0;

  void _close() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.home);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(weekRecapProvider);
    final w = async.valueOrNull;

    return Scaffold(
      backgroundColor: AppColor.void_,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(
                children: [
                  for (var s = 0; s < _count; s++) ...[
                    if (s > 0) const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: s <= _i ? AppColor.ink : AppColor.line,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                        'HRR · ${weekRangeLabel(w?.from ?? weekStart(DateTime.now()))}',
                        style: AppType.display(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            italic: false,
                            letterSpacing: 1.6,
                            color: AppColor.inkMuted)),
                  ),
                  IconButton(
                    tooltip: 'chiudi',
                    onPressed: _close,
                    icon: const Icon(Icons.close_rounded, color: AppColor.ink),
                  ),
                ],
              ),
            ),
            Expanded(
              child: w == null
                  ? Center(
                      child: async.hasError
                          ? Text('settimana non caricata.',
                              style: AppType.text(
                                  fontSize: 14, color: AppColor.inkMuted))
                          : const CircularProgressIndicator(
                              color: AppColor.ink),
                    )
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
                            child: KeyedSubtree(
                              key: ValueKey(_i),
                              child: HeatEnter(child: _slide(w)),
                            ),
                          ),
                        ),
                        // Zone di tocco: sinistra indietro, destra avanti.
                        Positioned.fill(
                          child: Row(
                            children: [
                              Expanded(
                                child: Semantics(
                                  button: true,
                                  label: 'indietro',
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTap: () => setState(() =>
                                        _i = (_i - 1).clamp(0, _count - 1)),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Semantics(
                                  button: true,
                                  label: 'avanti',
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTap: () => setState(() =>
                                        _i = (_i + 1).clamp(0, _count - 1)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            if (w != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
                child: _i < _count - 1
                    ? Text('TOCCA PER CONTINUARE',
                        style: AppType.display(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            italic: false,
                            letterSpacing: 2,
                            color: AppColor.inkFaint))
                    : HeatButton(
                        label: 'IN STRADA',
                        height: 56,
                        fontSize: 22,
                        onPressed: () => context.go(AppRoutes.home),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _slide(WeekRecap w) => switch (_i) {
        0 => _Drive(w),
        1 => _Pilot(w),
        2 => _Territory(w),
        3 => _Ranking(w),
        _ => _Best(w),
      };
}

TextStyle _kicker() => AppType.display(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    italic: false,
    letterSpacing: 2,
    color: AppColor.inkMuted);

TextStyle _hero(Color c, {double size = 120}) => AppType.display(
    fontSize: size, fontWeight: FontWeight.w900, height: .9, color: c);

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.color = AppColor.ink});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: AppType.text(fontSize: 15, color: AppColor.inkMuted)),
            ),
            Text(value,
                style: AppType.display(
                    fontSize: 26, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      );
}

class _Drive extends StatelessWidget {
  const _Drive(this.w);
  final WeekRecap w;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        const GraffitiText('la tua settimana',
            fontSize: 34, color: AppColor.ink),
        const SizedBox(height: 26),
        Text('HAI GUIDATO', style: _kicker()),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(_km(w.km), style: _hero(AppColor.accent, size: 140)),
        ),
        Text('KM', style: _hero(AppColor.ink, size: 40)),
        const Spacer(),
        if (w.trips == 0)
          Text('ancora nessuna guida questa settimana. la strada aspetta.',
              style: AppType.text(fontSize: 15, color: AppColor.inkMuted))
        else ...[
          _Fact('guide', '${w.trips}'),
          _Fact('ore al volante',
              w.hours.toStringAsFixed(1).replaceAll('.', ',')),
          _Fact('di notte', '${w.nightTrips}'),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}

class _Pilot extends StatelessWidget {
  const _Pilot(this.w);
  final WeekRecap w;

  @override
  Widget build(BuildContext context) {
    final p = w.pilot;
    return Column(
      children: [
        const SizedBox(height: 30),
        Text('IL PILOTA DELLA SETTIMANA', style: _kicker()),
        const Spacer(),
        PilotEmblem(
          monogram: p?.monogram ?? '?',
          width: 150,
          color: p == null ? AppColor.line : AppColor.accent,
          textColor: p == null ? AppColor.inkFaint : AppColor.accent,
          glow: p != null,
          locked: p == null,
        ),
        const SizedBox(height: 22),
        Text(p?.name.toUpperCase() ?? 'ANCORA NESSUNO',
            textAlign: TextAlign.center, style: _hero(AppColor.ink, size: 44)),
        const SizedBox(height: 6),
        if (p != null) ...[
          Text(p.source,
              textAlign: TextAlign.center,
              style: AppType.text(fontSize: 14, color: AppColor.inkMuted)),
          const SizedBox(height: 14),
          Text('"${p.tagline}"',
              textAlign: TextAlign.center,
              style:
                  AppType.text(fontSize: 15, color: AppColor.ink, height: 1.4)),
          const SizedBox(height: 14),
          Text(
              '${w.pilotCount} ${w.pilotCount == 1 ? 'guida' : 'guide'} su ${w.trips}',
              style: _kicker()),
        ] else
          Text('guida di più per scoprire chi sei al volante.',
              textAlign: TextAlign.center,
              style: AppType.text(fontSize: 14, color: AppColor.inkMuted)),
        const Spacer(),
      ],
    );
  }
}

class _Territory extends StatelessWidget {
  const _Territory(this.w);
  final WeekRecap w;

  @override
  Widget build(BuildContext context) {
    final net = w.hexGot - w.hexLost;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        Text('TERRITORIO', style: _kicker()),
        const SizedBox(height: 20),
        Text(net > 0 ? '+$net' : '$net', style: _hero(AppColor.accent)),
        Text('ESAGONI', style: _hero(AppColor.ink, size: 40)),
        const Spacer(),
        _Fact('conquistati', '+${w.hexGot}', color: AppColor.success),
        _Fact('persi', '−${w.hexLost}', color: AppColor.danger),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _Ranking extends StatelessWidget {
  const _Ranking(this.w);
  final WeekRecap w;

  @override
  Widget build(BuildContext context) {
    final from = w.rankBefore;
    final to = w.rankNow;
    final move = from != null && to != null ? from - to : null;
    final (moveLabel, moveColor) = move == null
        ? ('', AppColor.inkMuted)
        : move > 0
            ? (
                '▲ $move ${move == 1 ? 'POSIZIONE' : 'POSIZIONI'}',
                AppColor.success
              )
            : move < 0
                ? (
                    '▼ ${-move} ${move == -1 ? 'POSIZIONE' : 'POSIZIONI'}',
                    AppColor.danger
                  )
                : ('STESSA POSIZIONE', AppColor.inkMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        Text('CLASSIFICA AMICI', style: _kicker()),
        const SizedBox(height: 20),
        if (to == null)
          Text('classifica non ancora disponibile.',
              style: AppType.text(fontSize: 15, color: AppColor.inkMuted))
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (from != null) ...[
                Text('#$from', style: _hero(AppColor.inkFaint, size: 64)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 34, color: AppColor.inkMuted),
                ),
              ],
              Text('#$to', style: _hero(AppColor.accent, size: 100)),
            ],
          ),
          const SizedBox(height: 8),
          if (moveLabel.isNotEmpty)
            Text(moveLabel,
                style: AppType.display(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: moveColor)),
        ],
        const Spacer(),
        _Fact(
            'sfide 1 vs 1',
            w.challengesPlayed == 0
                ? '—'
                : '${w.challengesWon}/${w.challengesPlayed}'),
        _Fact('XP guadagnati', '+${w.xp}', color: AppColor.gold),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _Best extends StatelessWidget {
  const _Best(this.w);
  final WeekRecap w;

  @override
  Widget build(BuildContext context) {
    final b = w.best;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        Text('LA GUIDA MIGLIORE', style: _kicker()),
        const SizedBox(height: 16),
        if (b == null)
          Text('nessuna guida questa settimana.',
              style: AppType.text(fontSize: 15, color: AppColor.inkMuted))
        else ...[
          Text('${b.drivingScore ?? '—'}', style: _hero(AppColor.ink)),
          Text('FLOW · ${b.startedAt.day} ${_months[b.startedAt.month - 1]}',
              style: _kicker()),
          const SizedBox(height: 18),
          if (b.route.length >= 2)
            SizedBox(
              height: 150,
              width: double.infinity,
              child: CustomPaint(painter: RoutePainter(b.route)),
            ),
          const Spacer(),
          _Fact('distanza', '${_km(b.distanceKm)} km'),
          if (b.maxSpeedKmh != null)
            _Fact('velocità massima', '${b.maxSpeedKmh!.round()} km/h'),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Tracciato di una guida adattato al riquadro (proporzioni conservate),
/// in chiaro: sull'ultima slide l'accento è la CTA.
class RoutePainter extends CustomPainter {
  RoutePainter(this.route);
  final List<RoutePoint> route;

  @override
  void paint(Canvas canvas, Size size) {
    var minLat = route.first.lat, maxLat = minLat;
    var minLng = route.first.lng, maxLng = minLng;
    for (final p in route) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }
    final w = (maxLng - minLng).abs() < 1e-9 ? 1e-9 : maxLng - minLng;
    final h = (maxLat - minLat).abs() < 1e-9 ? 1e-9 : maxLat - minLat;
    const pad = 10.0;
    final scale = [(size.width - pad * 2) / w, (size.height - pad * 2) / h]
        .reduce((a, b) => a < b ? a : b);
    final dx = (size.width - w * scale) / 2;
    final dy = (size.height - h * scale) / 2;
    final path = Path();
    for (final (i, p) in route.indexed) {
      final o =
          Offset(dx + (p.lng - minLng) * scale, dy + (maxLat - p.lat) * scale);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
        path,
        stroke
          ..color = AppColor.ink.withValues(alpha: .18)
          ..strokeWidth = 12);
    canvas.drawPath(
        path,
        stroke
          ..color = AppColor.ink
          ..strokeWidth = 4);
  }

  @override
  bool shouldRepaint(RoutePainter old) => old.route != route;
}
