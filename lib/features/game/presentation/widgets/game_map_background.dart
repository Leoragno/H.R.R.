import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/hex_grid.dart';
import 'hex_map_painter.dart' show kHexRadiusPx;

/// Mappa reale (stessa MapLibre GL usata in Home) dietro la griglia
/// esagonale del gioco. Non interattiva e sempre ricentrata su [lat]/[lon]
/// (l'ultimo fix GPS del controller, non arrotondato a cella): la griglia
/// sopra è già vincolata al focus live, lasciare l'utente libero di
/// pan/zoom la mappa la scollegherebbe dagli esagoni disegnati.
class GameMapBackground extends StatefulWidget {
  final double? lat;
  final double? lon;
  const GameMapBackground({super.key, required this.lat, required this.lon});

  @override
  State<GameMapBackground> createState() => _GameMapBackgroundState();
}

class _GameMapBackgroundState extends State<GameMapBackground> {
  MapLibreMapController? _controller;

  @override
  void didUpdateWidget(covariant GameMapBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lat = widget.lat;
    final lon = widget.lon;
    if (lat == null || lon == null) return;
    if (lat == oldWidget.lat && lon == oldWidget.lon) return;
    _controller?.moveCamera(CameraUpdate.newLatLngZoom(
      LatLng(lat, lon),
      _zoomForLatitude(lat),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lat = widget.lat;
    final lon = widget.lon;
    if (lat == null || lon == null) {
      // Nessun fix GPS ancora: stesso sfondo pieno di prima, la griglia
      // sopra non disegna comunque nulla finché focus è null.
      return const ColoredBox(color: AppColors.guidaBg);
    }
    return IgnorePointer(
      // Sempre ricentrata via codice: niente gesture dell'utente, o la
      // mappa si scollegherebbe dalla griglia esagonale sopra.
      child: MapLibreMap(
        styleString: dotenv.env['MAP_STYLE_URL'] ?? MapLibreStyles.demo,
        initialCameraPosition: CameraPosition(
          target: LatLng(lat, lon),
          zoom: _zoomForLatitude(lat),
        ),
        onMapCreated: (c) => _controller = c,
        rotateGesturesEnabled: false,
        scrollGesturesEnabled: false,
        zoomGesturesEnabled: false,
        tiltGesturesEnabled: false,
        doubleClickZoomEnabled: false,
        myLocationEnabled: false,
        compassEnabled: false,
      ),
    );
  }
}

// Zoom alla quale i metri/pixel di MapLibre coincidono con quelli usati
// dal painter esagonale (kHexRadiusPx px = HexGrid.hexMeters m), così i
// due layer restano in scala fra loro. Formula standard Web Mercator:
// metri/pixel = 156543.03392 * cos(lat) / 2^zoom.
double _zoomForLatitude(double latDeg) {
  const metersPerPixel = HexGrid.hexMeters / kHexRadiusPx;
  final metersPerPixelAtEquatorZoom0 =
      156543.03392 * math.cos(latDeg * math.pi / 180);
  return math.log(metersPerPixelAtEquatorZoom0 / metersPerPixel) / math.ln2;
}
