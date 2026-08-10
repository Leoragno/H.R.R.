import 'package:flutter/material.dart';

/// Silhouette auto riusata in tutto il design "Guida" (icona tab, icone
/// voto rarità, decorazioni). Ricreata come CustomPainter dal path SVG
/// originale (viewBox 86x42) invece di importare un asset SVG.
class CarGlyphIcon extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const CarGlyphIcon({
    super.key,
    this.size = 24,
    required this.color,
    this.opacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: size,
        height: size * 42 / 86,
        child: CustomPaint(
          painter: _CarGlyphPainter(color: color),
        ),
      ),
    );
  }
}

class _CarGlyphPainter extends CustomPainter {
  final Color color;
  const _CarGlyphPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 86;
    final sy = size.height / 42;
    final paint = Paint()..color = color;

    final body = Path()
      ..moveTo(6 * sx, 30 * sy)
      ..cubicTo(4 * sx, 24 * sy, 6 * sx, 20 * sy, 12 * sx, 18 * sy)
      ..lineTo(24 * sx, 8 * sy)
      ..cubicTo(27 * sx, 5.6 * sy, 31 * sx, 4.5 * sy, 35 * sx, 4.5 * sy)
      ..lineTo(52 * sx, 4.5 * sy)
      ..cubicTo(57 * sx, 4.5 * sy, 61 * sx, 6 * sy, 65 * sx, 9 * sy)
      ..lineTo(74 * sx, 17 * sy)
      ..cubicTo(80 * sx, 18.5 * sy, 83 * sx, 21 * sy, 83 * sx, 26 * sy)
      ..lineTo(83 * sx, 30 * sy)
      ..cubicTo(83 * sx, 31.6 * sy, 82 * sx, 32.5 * sy, 80.5 * sx, 32.5 * sy)
      ..lineTo(72 * sx, 32.5 * sy)
      ..lineTo(72 * sx, 29 * sy)
      ..lineTo(18 * sx, 29 * sy)
      ..lineTo(18 * sx, 32.5 * sy)
      ..lineTo(9 * sx, 32.5 * sy)
      ..cubicTo(7.2 * sx, 32.5 * sy, 6.3 * sx, 31.7 * sy, 6 * sx, 30 * sy)
      ..close();
    canvas.drawPath(body, paint);

    canvas.drawCircle(Offset(23 * sx, 32 * sy), 6 * sx, paint);
    canvas.drawCircle(Offset(66 * sx, 32 * sy), 6 * sx, paint);
  }

  @override
  bool shouldRepaint(covariant _CarGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}
