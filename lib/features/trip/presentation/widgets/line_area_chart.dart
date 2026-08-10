import 'package:flutter/material.dart';

/// Grafico linea+area generico (usato per "Speed Over Time" ed "Elevation
/// Over Time" nella schermata di riepilogo). Vedi Guida.dc.html righe
/// 954-983.
class LineAreaChart extends StatelessWidget {
  final List<double> values;
  final Color lineColor;
  final Color fillColor;
  final double height;

  const LineAreaChart({
    super.key,
    required this.values,
    required this.lineColor,
    required this.fillColor,
    this.height = 130,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Dati insufficienti per questo grafico',
            style: TextStyle(
                color: lineColor.withValues(alpha: 0.6), fontSize: 12),
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ChartPainter(
          values: values,
          lineColor: lineColor,
          fillColor: fillColor,
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final Color fillColor;

  const _ChartPainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final span = (maxV - minV).abs() < 1e-6 ? 1.0 : (maxV - minV);

    Offset toOffset(int i, double v) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - ((v - minV) / span) * size.height;
      return Offset(x, y);
    }

    final line = Path()..moveTo(0, toOffset(0, values[0]).dy);
    for (var i = 1; i < values.length; i++) {
      final o = toOffset(i, values[i]);
      line.lineTo(o.dx, o.dy);
    }

    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(area, Paint()..color = fillColor);
    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) =>
      oldDelegate.values != values;
}
