import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/route_point.dart';
import '../../domain/entities/trip.dart' show Trip;
import 'route_preview_painter.dart';
import 'speed_distribution_bar.dart';

/// Overlay "TripRank" — la card condivisibile a 3 pagine dal design
/// (Guida.dc.html righe 994-1134): statistiche, mappa+distribuzione
/// velocità, report dettagliato+grafici. Il toggle "Trasparente" agisce
/// davvero sull'opacità dello sfondo della card; "Condividi" non ha un
/// backend di export reale in questa build (nessun package share/screenshot
/// installato) quindi mostra un messaggio onesto invece di fingere.
class TripRankCard extends StatefulWidget {
  final Trip trip;
  final List<RoutePoint> routePoints;
  final List<double> speedSeries;
  final List<SpeedBand> speedBands;

  const TripRankCard({
    super.key,
    required this.trip,
    required this.routePoints,
    required this.speedSeries,
    required this.speedBands,
  });

  @override
  State<TripRankCard> createState() => _TripRankCardState();
}

class _TripRankCardState extends State<TripRankCard> {
  final _pageController = PageController();
  int _page = 0;
  bool _transparent = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}min';
    return '$m min';
  }

  String _formatDateLong(DateTime d) {
    const months = [
      'gen', 'feb', 'mar', 'apr', 'mag', 'giu', //
      'lug', 'ago', 'set', 'ott', 'nov', 'dic',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    return Container(
      color: AppColor.void_.withValues(alpha: 0.86),
      padding: const EdgeInsets.fromLTRB(
          AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.lg),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _RoundButton(
                icon: Icons.close_rounded,
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColor.surfaceHigh
                        .withValues(alpha: _transparent ? 0.35 : 1),
                    AppColor.void_.withValues(alpha: _transparent ? 0.35 : 1),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.md, AppSpace.lg, AppSpace.md, AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'TripRank',
                    textAlign: TextAlign.center,
                    style: AppType.text(
                      fontWeight: FontWeight.w800,
                      fontSize: 34,
                      color: AppColor.cyan,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _page = i),
                      children: [
                        _Page0(
                            trip: trip,
                            speedSeries: widget.speedSeries,
                            formatDuration: _formatDuration,
                            formatDateLong: _formatDateLong),
                        _Page1(
                            routePoints: widget.routePoints,
                            speedBands: widget.speedBands),
                        _Page2(
                            trip: trip,
                            speedSeries: widget.speedSeries,
                            formatDuration: _formatDuration,
                            formatDateLong: _formatDateLong),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                GestureDetector(
                  onTap: () => _pageController.animateToPage(i,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
                    width: i == _page ? 42 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: i == _page ? AppColor.ink : AppColor.line,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Trasparente',
                  style: AppType.text(fontSize: 18, color: AppColor.ink)),
              const SizedBox(width: AppSpace.sm),
              GestureDetector(
                onTap: () => setState(() => _transparent = !_transparent),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  width: 62,
                  height: 34,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _transparent ? AppColor.cyan : AppColor.line,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  alignment: _transparent
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: const DecoratedBox(
                    decoration:
                        BoxDecoration(color: AppColor.ink, shape: BoxShape.circle),
                    child: SizedBox(width: 26, height: 26),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Material(
            color: AppColor.surfaceHigh,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.card),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Condivisione non ancora disponibile in questa build')),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.ios_share_rounded,
                        color: AppColor.ink, size: 20),
                    const SizedBox(width: AppSpace.sm),
                    Text('Condividi',
                        style: AppType.text(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            color: AppColor.ink)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Page0 extends StatelessWidget {
  final Trip trip;
  final List<double> speedSeries;
  final String Function(int) formatDuration;
  final String Function(DateTime) formatDateLong;

  const _Page0({
    required this.trip,
    required this.speedSeries,
    required this.formatDuration,
    required this.formatDateLong,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(
                  child: _Stat(
                      '${trip.distanceKm.toStringAsFixed(1)} km', 'DISTANCE')),
              Expanded(
                  child: _Stat(
                      formatDuration(trip.durationSeconds), 'TOTAL TIME')),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          _Stat('${trip.maxSpeedKmh?.toStringAsFixed(0) ?? '—'} km/h',
              'TOP SPEED',
              big: true),
          const SizedBox(height: AppSpace.lg),
          if (speedSeries.length >= 2)
            SizedBox(
              height: 90,
              child: CustomPaint(
                painter: _SparkPainter(speedSeries),
                child: const SizedBox.expand(),
              ),
            ),
          const SizedBox(height: AppSpace.lg),
          Text(formatDateLong(trip.startedAt),
              style: AppType.text(fontSize: 18, color: AppColor.inkMuted)),
        ],
      ),
    );
  }
}

class _Page1 extends StatelessWidget {
  final List<RoutePoint> routePoints;
  final List<SpeedBand> speedBands;
  const _Page1({required this.routePoints, required this.speedBands});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpace.md),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppColor.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            clipBehavior: Clip.antiAlias,
            child: routePoints.length >= 2
                ? RoutePreview(points: routePoints)
                : const Center(
                    child: Icon(Icons.map_rounded, color: AppColor.line)),
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SPEED DISTRIBUTION', style: AppType.label),
              Text('KM/H', style: AppType.label),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          SpeedDistributionBar(bands: speedBands),
        ],
      ),
    );
  }
}

class _Page2 extends StatelessWidget {
  final Trip trip;
  final List<double> speedSeries;
  final String Function(int) formatDuration;
  final String Function(DateTime) formatDateLong;

  const _Page2({
    required this.trip,
    required this.speedSeries,
    required this.formatDuration,
    required this.formatDateLong,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Distanza', '${trip.distanceKm.toStringAsFixed(1)} km'),
      ('Durata totale', formatDuration(trip.durationSeconds)),
      ('Velocità media', '${trip.avgSpeedKmh?.toStringAsFixed(0) ?? '—'} km/h'),
      (
        'Velocità massima',
        '${trip.maxSpeedKmh?.toStringAsFixed(0) ?? '—'} km/h'
      ),
      ('XP guadagnati', '${trip.xpEarned}'),
      ('REP guadagnati', '${trip.repEarned}'),
    ];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Expanded(
                  child: _Stat(
                      '${trip.distanceKm.toStringAsFixed(1)} km', 'DISTANCE',
                      small: true)),
              Expanded(
                  child: _Stat(
                      formatDuration(trip.durationSeconds), 'TOTAL TIME',
                      small: true)),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text('Detailed Report', style: AppType.title),
          const SizedBox(height: AppSpace.sm),
          for (final r in rows)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpace.sm),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.md, vertical: AppSpace.sm),
              decoration: BoxDecoration(
                color: AppColor.surfaceHigh,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(r.$1,
                      style: AppType.text(fontSize: 16, color: AppColor.inkMuted)),
                  Text(r.$2,
                      style: AppType.text(fontWeight: FontWeight.w700, fontSize: 18)),
                ],
              ),
            ),
          const SizedBox(height: AppSpace.lg),
          if (speedSeries.length >= 2) ...[
            Text('SPEED OVER TIME', style: AppType.label),
            const SizedBox(height: AppSpace.sm),
            SizedBox(
              height: 110,
              child: CustomPaint(
                painter: _SparkPainter(speedSeries, filled: true),
                child: const SizedBox.expand(),
              ),
            ),
          ],
          const SizedBox(height: AppSpace.lg),
          Text(formatDateLong(trip.startedAt),
              textAlign: TextAlign.center,
              style: AppType.text(fontSize: 16, color: AppColor.inkMuted)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final bool big;
  final bool small;
  const _Stat(this.value, this.label, {this.big = false, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: AppType.text(
                fontWeight: FontWeight.w800,
                fontSize: big ? 38 : (small ? 28 : 34),
                color: AppColor.ink)),
        const SizedBox(height: AppSpace.sm),
        Text(label,
            style: AppType.label.copyWith(fontSize: small ? 13 : 14)),
      ],
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> values;
  final bool filled;
  const _SparkPainter(this.values, {this.filled = false});

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final span = (maxV - minV).abs() < 1e-6 ? 1.0 : (maxV - minV);

    Offset toOffset(int i, double v) {
      final x = size.width * i / (values.length - 1);
      final y = size.height -
          ((v - minV) / span) * size.height * 0.9 -
          size.height * 0.05;
      return Offset(x, y);
    }

    final path = Path()..moveTo(0, toOffset(0, values[0]).dy);
    for (var i = 1; i < values.length; i++) {
      final o = toOffset(i, values[i]);
      path.lineTo(o.dx, o.dy);
    }

    if (filled) {
      final area = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
          area, Paint()..color = AppColor.cyan.withValues(alpha: 0.22));
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColor.cyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = filled ? 2.4 : 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) => true;
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.surfaceHigh.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: AppColor.ink, size: 22),
        ),
      ),
    );
  }
}
