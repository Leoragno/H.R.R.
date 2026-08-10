import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Le 4 immagini marker (Velox/Pattuglia × arancione-API/ciano-Crew),
/// rasterizzate una sola volta e registrate sulla mappa via
/// `controller.addImage` — i marker MapLibre sono layer nativi (Symbol),
/// servono bitmap, non widget Flutter, per restare fluidi anche con
/// centinaia di punti durante pan/zoom.
class RadarIconSet {
  RadarIconSet._();

  static const veloxApiId = 'radar-velox-api';
  static const pattugliaApiId = 'radar-pattuglia-api';
  static const veloxCrewId = 'radar-velox-crew';
  static const pattugliaCrewId = 'radar-pattuglia-crew';

  // Arancione SOLO per le fonti API, ciano SOLO per le fonti Crew — mai
  // altri colori, per restare leggibili come "chi ha segnalato cosa".
  static const _apiColor = Color(0xFFFF8A1F);
  static const _crewColor = Color(0xFF35E0FF);

  /// Nomi immagine -> bytes PNG, pronti per `controller.addImage`.
  static Future<Map<String, Uint8List>> render({double size = 96}) async {
    return {
      veloxApiId:
          await _rasterizeIcon(Icons.videocam_rounded, _apiColor, size),
      veloxCrewId:
          await _rasterizeIcon(Icons.videocam_rounded, _crewColor, size),
      pattugliaCrewId:
          await _rasterizeIcon(Icons.shield_rounded, _crewColor, size),
      // Pattuglia API: ESCLUSIVAMENTE il cappello, mai un'auto — nessuna
      // icona Material esistente rappresenta un berretto da polizia da
      // solo, quindi lo disegniamo a mano con forme semplici (cupola +
      // visiera + placca), non un path complesso da azzeccare a occhio.
      pattugliaApiId: await _rasterizePoliceCap(_apiColor, size),
    };
  }

  static Future<Uint8List> _rasterizeIcon(
      IconData icon, Color color, double size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size * 0.72,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      )
      ..layout();
    painter.paint(
      canvas,
      Offset((size - painter.width) / 2, (size - painter.height) / 2),
    );
    return _finish(recorder, size);
  }

  static Future<Uint8List> _rasterizePoliceCap(
      Color color, double size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = color;
    final center = size / 2;

    final domeRect = Rect.fromCenter(
      center: Offset(center, size * 0.40),
      width: size * 0.56,
      height: size * 0.32,
    );
    canvas.drawArc(domeRect, math.pi, math.pi, true, paint);

    final brimRect = Rect.fromCenter(
      center: Offset(center, size * 0.56),
      width: size * 0.74,
      height: size * 0.16,
    );
    canvas.drawOval(brimRect, paint);

    canvas.drawCircle(
      Offset(center, size * 0.40),
      size * 0.05,
      Paint()..color = Colors.white,
    );

    return _finish(recorder, size);
  }

  static Future<Uint8List> _finish(
      ui.PictureRecorder recorder, double size) async {
    final image =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  /// Nome immagine per un evento, in base a categoria + fonte.
  static String imageIdFor(bool isVelox, bool isCrew) {
    if (isVelox) return isCrew ? veloxCrewId : veloxApiId;
    return isCrew ? pattugliaCrewId : pattugliaApiId;
  }
}
