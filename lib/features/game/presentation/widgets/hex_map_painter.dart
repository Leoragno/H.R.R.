import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/territory_cell.dart';
import '../../domain/hex_grid.dart';
import '../providers/game_controller.dart';

/// Griglia esagonale a schermo intero, centrata su [focus], da disegnare
/// sopra la mappa reale (game_map_background.dart). Disegna solo le
/// celle con un proprietario noto (in [cells]): quelle libere restano
/// trasparenti, così si vede la mappa sotto — coerente col fatto che
/// lato server non esiste una riga per le celle mai rivendicate (vedi
/// territory_cells_near).
class HexMapView extends StatelessWidget {
  final HexCoord? focus;
  final Map<String, TerritoryCell> cells;
  final GameMapMode mode;
  final String? myProfileId;
  final String? myCrewId;

  const HexMapView({
    super.key,
    required this.focus,
    required this.cells,
    required this.mode,
    required this.myProfileId,
    required this.myCrewId,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HexMapPainter(
        focus: focus,
        cells: cells,
        mode: mode,
        myProfileId: myProfileId,
        myCrewId: myCrewId,
      ),
      child: const SizedBox.expand(),
    );
  }
}

// Palette stabile per i territori rivali: serve solo a distinguerli
// visivamente fra loro sulla mappa, non rappresenta un'identità reale.
const _kRivalPalette = [
  AppColors.neonRed,
  AppColors.neonMagenta,
  AppColors.guidaPurple,
  AppColors.neonAmber,
  AppColors.neonGreen,
  AppColors.neonPurple,
];

// Raggio (in px logici) di ogni esagono — pubblico perché la mappa reale
// dietro la griglia (game_map_background.dart) deve usare lo stesso
// rapporto metri/pixel per restare allineata in scala.
const kHexRadiusPx = 15.0;

class _HexMapPainter extends CustomPainter {
  final HexCoord? focus;
  final Map<String, TerritoryCell> cells;
  final GameMapMode mode;
  final String? myProfileId;
  final String? myCrewId;

  _HexMapPainter({
    required this.focus,
    required this.cells,
    required this.mode,
    required this.myProfileId,
    required this.myCrewId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Nessuno sfondo disegnato qui: sotto c'è la mappa reale
    // (game_map_background.dart), le celle libere restano trasparenti.
    final focusCell = focus;
    if (focusCell == null) return; // nessun fix GPS ancora: niente da disegnare

    final center = size.center(Offset.zero);
    final cols = (size.width / (kHexRadiusPx * 1.732)).ceil() + 2;
    final rows = (size.height / (kHexRadiusPx * 1.5)).ceil() + 2;
    final fillPaint = Paint()..style = PaintingStyle.fill;

    for (var dr = -rows; dr <= rows; dr++) {
      for (var dq = -cols; dq <= cols; dq++) {
        final cell = HexCoord(focusCell.q + dq, focusCell.r + dr);
        final offset = HexGrid.offsetFrom(focusCell, cell);
        final cx = center.dx + offset.dx * kHexRadiusPx;
        final cy = center.dy - offset.dy * kHexRadiusPx;
        if (cx < -kHexRadiusPx * 2 ||
            cx > size.width + kHexRadiusPx * 2 ||
            cy < -kHexRadiusPx * 2 ||
            cy > size.height + kHexRadiusPx * 2) {
          continue;
        }

        final color = _colorFor(cells[cell.key]);
        if (color == null) continue;
        fillPaint.color = color;
        canvas.drawPath(
          _hexPath(Offset(cx, cy), kHexRadiusPx * 0.94),
          fillPaint,
        );
      }
    }
  }

  // Le celle libere (owned == null) restano sempre trasparenti in ogni
  // modalità: si vede solo la griglia dove qualcuno l'ha colorata,
  // altrove resta visibile la mappa reale sotto.
  Color? _colorFor(TerritoryCell? owned) {
    if (owned == null) return null;
    final isMine = owned.ownerId == myProfileId;
    switch (mode) {
      case GameMapMode.mineOnly:
        return isMine ? AppColors.guidaCyan : null;
      case GameMapMode.crew:
        if (isMine) return AppColors.guidaCyan;
        if (myCrewId != null && owned.ownerCrewId == myCrewId) {
          return AppColors.guidaBlue;
        }
        return _rivalColor(owned.ownerId);
      case GameMapMode.solo:
        return isMine ? AppColors.guidaCyan : _rivalColor(owned.ownerId);
    }
  }

  Color _rivalColor(String ownerId) {
    final idx = ownerId.hashCode.abs() % _kRivalPalette.length;
    return _kRivalPalette[idx];
  }

  Path _hexPath(Offset c, double radius) {
    final path = Path();
    for (var k = 0; k < 6; k++) {
      final angle = (math.pi / 180) * (60 * k - 30);
      final p = Offset(
        c.dx + radius * math.cos(angle),
        c.dy + radius * math.sin(angle),
      );
      if (k == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HexMapPainter oldDelegate) {
    return oldDelegate.focus != focus ||
        oldDelegate.cells != cells ||
        oldDelegate.mode != mode ||
        oldDelegate.myProfileId != myProfileId ||
        oldDelegate.myCrewId != myCrewId;
  }
}
