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
      color: Colors.black.withValues(alpha: 0.86),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
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
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF16211F)
                        .withValues(alpha: _transparent ? 0.35 : 1),
                    const Color(0xFF0C1211)
                        .withValues(alpha: _transparent ? 0.35 : 1),
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'TripRank',
                    textAlign: TextAlign.center,
                    style: AppTheme.archivo(
                      fontWeight: FontWeight.w800,
                      fontSize: 34,
                      color: const Color(0xFF9DD4FF),
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                GestureDetector(
                  onTap: () => _pageController.animateToPage(i,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: i == _page ? 42 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color:
                          i == _page ? Colors.white : const Color(0xFF4A4A4A),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Trasparente',
                  style: AppTheme.archivo(
                      fontSize: 18, color: const Color(0xFFDCE7F4))),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () => setState(() => _transparent = !_transparent),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 62,
                  height: 34,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _transparent
                        ? AppColors.guidaCyan
                        : const Color(0xFF4A4A4A),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: _transparent
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Material(
            color: const Color(0xFF2A3450),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Condivisione non ancora disponibile in questa build')),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.ios_share_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text('Condividi',
                        style: AppTheme.archivo(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            color: Colors.white)),
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
          const SizedBox(height: 20),
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
          const SizedBox(height: 26),
          _Stat('${trip.maxSpeedKmh?.toStringAsFixed(0) ?? '—'} km/h',
              'TOP SPEED',
              big: true),
          const SizedBox(height: 26),
          if (speedSeries.length >= 2)
            SizedBox(
              height: 90,
              child: CustomPaint(
                painter: _SparkPainter(speedSeries),
                child: const SizedBox.expand(),
              ),
            ),
          const SizedBox(height: 22),
          Text(formatDateLong(trip.startedAt),
              style: AppTheme.archivo(
                  fontSize: 18, color: const Color(0xFFCFDCEC))),
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
          const SizedBox(height: 14),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E18),
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.antiAlias,
            child: routePoints.length >= 2
                ? RoutePreview(points: routePoints)
                : const Center(
                    child: Icon(Icons.map_rounded, color: Color(0xFF2A3450))),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SPEED DISTRIBUTION',
                  style: AppTheme.archivo(
                      fontSize: 15,
                      letterSpacing: 1,
                      color: const Color(0xFFC2D2E6))),
              Text('KM/H',
                  style: AppTheme.archivo(
                      fontSize: 15, color: const Color(0xFFC2D2E6))),
            ],
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
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
          const SizedBox(height: 18),
          Text('Detailed Report',
              style:
                  AppTheme.archivo(fontWeight: FontWeight.w800, fontSize: 22)),
          const SizedBox(height: 10),
          for (final r in rows)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF131A19),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(r.$1,
                      style: AppTheme.archivo(
                          fontSize: 16, color: const Color(0xFFC2D2E6))),
                  Text(r.$2,
                      style: AppTheme.archivo(
                          fontWeight: FontWeight.w700, fontSize: 18)),
                ],
              ),
            ),
          const SizedBox(height: 22),
          if (speedSeries.length >= 2) ...[
            Text('SPEED OVER TIME',
                style: AppTheme.archivo(
                    fontSize: 15,
                    letterSpacing: 1,
                    color: const Color(0xFFC2D2E6))),
            const SizedBox(height: 10),
            SizedBox(
              height: 110,
              child: CustomPaint(
                painter: _SparkPainter(speedSeries, filled: true),
                child: const SizedBox.expand(),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Text(formatDateLong(trip.startedAt),
              textAlign: TextAlign.center,
              style: AppTheme.archivo(
                  fontSize: 16, color: const Color(0xFFCFDCEC))),
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
            style: AppTheme.archivo(
                fontWeight: FontWeight.w800,
                fontSize: big ? 38 : (small ? 28 : 34),
                color: Colors.white)),
        const SizedBox(height: 8),
        Text(label,
            style: AppTheme.archivo(
                fontSize: small ? 13 : 14,
                letterSpacing: 1,
                color: const Color(0xFF8FA3BD))),
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
          area, Paint()..color = AppColors.guidaCyan.withValues(alpha: 0.22));
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF9DD4FF)
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
      color: const Color(0xF21C2640),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
