import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';

/// Tachimetro HEAT (handoff, "Guida in corso"): arco di 270° da 0 a
/// [maxSpeed], riempito in accento con glow, tacche ogni 10 km/h (grandi
/// ogni 40, con etichetta), numero grande al centro e fascia di zona sotto.
/// È l'unico elemento con glow della vista tachimetro.
class SpeedometerGauge extends StatelessWidget {
  final double speed;
  final double maxSpeed;

  const SpeedometerGauge({
    super.key,
    required this.speed,
    this.maxSpeed = 200,
  });

  static (String, Color) zoneFor(double kmh) {
    if (kmh > 130) return ('OLTRE IL LIMITE', AppColor.danger);
    if (kmh > 90) return ('EXTRAURBANO', AppColor.gold);
    if (kmh > 0.5) return ('URBANO', AppColor.info);
    return ('IN ATTESA GPS', AppColor.inkMuted);
  }

  @override
  Widget build(BuildContext context) {
    final a = AppColor.accent;
    final (zone, zoneColor) = zoneFor(speed);
    return AspectRatio(
      aspectRatio: 300 / 262,
      child: LayoutBuilder(builder: (context, c) {
        final scale = c.maxWidth / 300;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: c.maxWidth,
              height: c.maxWidth,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: speed.clamp(0, maxSpeed)),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                builder: (_, v, __) => CustomPaint(
                  painter: _GaugePainter(
                      speed: v, maxSpeed: maxSpeed, accent: a),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 66 * scale,
              child: Column(
                children: [
                  Text(
                    speed.round().toString(),
                    style: AppType.score.copyWith(
                      fontSize: 104 * scale,
                      height: 1,
                      letterSpacing: -3,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      shadows: [
                        Shadow(color: a.withValues(alpha: .5), blurRadius: 24),
                      ],
                    ),
                  ),
                  Text('KM/H',
                      style: AppType.label.copyWith(
                          fontSize: 16 * scale,
                          letterSpacing: 3,
                          color: AppColor.info)),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 4,
              child: Center(
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                  decoration: ShapeDecoration(
                    color: zoneColor,
                    shape: const SlantBorder.all(6),
                  ),
                  child: Text(
                    zone,
                    style: AppType.display(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 1.4,
                      color: AppColor.onAccent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final Color accent;

  _GaugePainter(
      {required this.speed, required this.maxSpeed, required this.accent});

  static const _start = 135 * math.pi / 180;
  static const _sweep = 270 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 300;
    final center = Offset(150 * s, 150 * s);
    final rect = Rect.fromCircle(center: center, radius: 120 * s);
    final frac = (speed / maxSpeed).clamp(0.0, 1.0);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18 * s
      ..color = AppColor.surfaceHigh;
    canvas.drawArc(rect, _start, _sweep, false, track);

    if (frac > 0) {
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18 * s
        ..color = accent.withValues(alpha: .6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      final fill = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18 * s
        ..color = accent;
      canvas.drawArc(rect, _start, _sweep * frac, false, glow);
      canvas.drawArc(rect, _start, _sweep * frac, false, fill);
    }

    final labelStyle = AppType.display(
      fontWeight: FontWeight.w700,
      fontSize: 13 * s,
      italic: false,
      color: AppColor.inkFaint,
    );
    for (var v = 0; v <= maxSpeed; v += 10) {
      final ang = _start + _sweep * (v / maxSpeed);
      final big = v % 40 == 0;
      final dir = Offset(math.cos(ang), math.sin(ang));
      final tick = Paint()
        ..strokeWidth = (big ? 2.5 : 1.2) * s
        ..color = v <= speed ? AppColor.ink : AppColor.lineMuted;
      canvas.drawLine(
          center + dir * (104 * s), center + dir * ((big ? 92 : 98) * s), tick);
      if (big) {
        final tp = TextPainter(
          text: TextSpan(text: '$v', style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas,
            center + dir * (78 * s) - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.speed != speed || old.accent != accent || old.maxSpeed != maxSpeed;
}
