import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Tachimetro digitale del design Guida: anello di tacche colorate per
/// fascia di velocità (verde→ciano→viola→magenta man mano che ci si
/// avvicina a [maxSpeed]) con il numero grande al centro — non un
/// tachimetro analogico con lancetta.
class SpeedometerGauge extends StatelessWidget {
  final double speed;
  final double maxSpeed;

  const SpeedometerGauge({
    super.key,
    required this.speed,
    this.maxSpeed = 220,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            painter: _GaugePainter(
              speed: speed.clamp(0, maxSpeed),
              maxSpeed: maxSpeed,
            ),
            child: const SizedBox.expand(),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                speed.round().toString(),
                style: AppTheme.archivo(
                  fontWeight: FontWeight.w700,
                  fontSize: 88,
                  color: Colors.white,
                  letterSpacing: -3,
                ),
              ),
              Text(
                'km/h',
                style: AppTheme.archivo(
                  fontWeight: FontWeight.w500,
                  fontSize: 22,
                  color: AppColors.guidaCyan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double speed;
  final double maxSpeed;

  const _GaugePainter({required this.speed, required this.maxSpeed});

  static const _tickCount = 60;
  static const _sweep = 270 * math.pi / 180;
  static const _start = (90 + (360 - 270) / 2) * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0xFF16224A), Color(0xFF080C18), Color(0xFF04060C)],
        stops: const [0, 0.62, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.94));
    canvas.drawCircle(center, radius * 0.94, bgPaint);

    final progress = maxSpeed <= 0 ? 0.0 : (speed / maxSpeed).clamp(0, 1);
    final litTicks = (progress * _tickCount).round();

    for (var i = 0; i < _tickCount; i++) {
      final t = i / (_tickCount - 1);
      final angle = _start + _sweep * t;
      final lit = i <= litTicks;
      final color = lit ? _colorForT(t) : const Color(0xFF232B45);

      final outer = Offset(
        center.dx + radius * 0.98 * math.cos(angle),
        center.dy + radius * 0.98 * math.sin(angle),
      );
      final inner = Offset(
        center.dx + radius * 0.86 * math.cos(angle),
        center.dy + radius * 0.86 * math.sin(angle),
      );

      final tickPaint = Paint()
        ..color = color
        ..strokeWidth = lit ? 4 : 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  Color _colorForT(double t) {
    const colors = [
      Color(0xFF7EE0A5),
      Color(0xFF35E0FF),
      Color(0xFF2F6BFF),
      Color(0xFFC23DFF),
      Color(0xFFFF2D55),
    ];
    final scaled = t * (colors.length - 1);
    final i = scaled.floor().clamp(0, colors.length - 2);
    final localT = scaled - i;
    return Color.lerp(colors[i], colors[i + 1], localT)!;
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.speed != speed || oldDelegate.maxSpeed != maxSpeed;
}
