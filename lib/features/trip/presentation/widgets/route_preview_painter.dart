import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/route_point.dart';
import '../utils/route_smoothing.dart';

/// Disegna la forma del percorso (normalizzata, senza tile di mappa) come
/// anteprima neon nella schermata di Fine Viaggio.
class RoutePreview extends StatelessWidget {
  final List<RoutePoint> points;
  const RoutePreview({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return const SizedBox.shrink();
    }
    return CustomPaint(
      painter: _RoutePainter(points),
      child: const SizedBox.expand(),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final List<RoutePoint> points;
  _RoutePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    var minLat = points.first.lat, maxLat = points.first.lat;
    var minLng = points.first.lng, maxLng = points.first.lng;
    for (final p in points) {
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
    }
    final latSpan = (maxLat - minLat).abs() < 1e-9 ? 1e-9 : (maxLat - minLat);
    final lngSpan = (maxLng - minLng).abs() < 1e-9 ? 1e-9 : (maxLng - minLng);

    const padding = AppSpace.lg;
    Offset toOffset(RoutePoint p) {
      final x =
          padding + ((p.lng - minLng) / lngSpan) * (size.width - padding * 2);
      // lat cresce verso nord -> capovolgo per disegnare "in alto" in alto
      final y = padding +
          (1 - (p.lat - minLat) / latSpan) * (size.height - padding * 2);
      return Offset(x, y);
    }

    final smoothed = smoothRouteForDisplay(points);
    final path = Path()
      ..moveTo(toOffset(smoothed.first).dx, toOffset(smoothed.first).dy);
    for (final p in smoothed.skip(1)) {
      final o = toOffset(p);
      path.lineTo(o.dx, o.dy);
    }

    final glowPaint = Paint()
      ..color = AppColor.cyan.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, glowPaint);

    final linePaint = Paint()
      ..color = AppColor.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // Partenza neutra, arrivo sul secondo accento: il percorso "si consuma"
    // dal ciano (attivo) al magenta (finito), coerente con l'elemento firma
    // di DESIGN.md.
    final startPoint = toOffset(points.first);
    final endPoint = toOffset(points.last);
    canvas.drawCircle(startPoint, 5, Paint()..color = AppColor.ink);
    canvas.drawCircle(endPoint, 5, Paint()..color = AppColor.magenta);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.points != points;
}
