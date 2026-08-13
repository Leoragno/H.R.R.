import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/territory_cell.dart';
import '../../domain/hex_grid.dart';
import '../providers/game_controller.dart' show GameMapMode;

const _kDefaultZoom = 16.0;

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

/// Mappa reale (stessa MapLibre GL usata in Home/Guida), interattiva
/// (pan/zoom liberi come nella sezione Guida) con sopra le celle
/// possedute disegnate come poligoni [Fill] georeferenziati — non più un
/// overlay in pixel a parte, quindi restano sempre allineati al terreno
/// vero a qualunque zoom/posizione della camera scelga l'utente. La
/// camera segue il GPS solo al primo fix e su [recenter] esplicito (vedi
/// pulsante "centra" in game_screen.dart), mai ad ogni fix — altrimenti
/// vanificherebbe il pan/zoom libero.
class GameMapBackground extends StatefulWidget {
  final double? lat;
  final double? lon;
  final Map<String, TerritoryCell> cells;
  final GameMapMode mode;
  final String? myProfileId;
  final String? myCrewId;

  const GameMapBackground({
    super.key,
    required this.lat,
    required this.lon,
    required this.cells,
    required this.mode,
    required this.myProfileId,
    required this.myCrewId,
  });

  @override
  State<GameMapBackground> createState() => GameMapBackgroundState();
}

class GameMapBackgroundState extends State<GameMapBackground> {
  MapLibreMapController? _controller;
  Circle? _meCircle;
  final Map<String, Fill> _cellFills = {};

  /// Ricentra la camera sulla posizione live corrente — chiamato dal
  /// pulsante "centra" di GameScreen via GlobalKey, dato che la camera
  /// non segue più automaticamente ogni fix GPS.
  Future<void> recenter() async {
    final controller = _controller;
    final lat = widget.lat;
    final lon = widget.lon;
    if (controller == null || lat == null || lon == null) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lon), _kDefaultZoom),
    );
  }

  @override
  void didUpdateWidget(covariant GameMapBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lat != oldWidget.lat || widget.lon != oldWidget.lon) {
      unawaited(_updateMeMarker());
    }
    if (!identical(widget.cells, oldWidget.cells) ||
        widget.mode != oldWidget.mode ||
        widget.myProfileId != oldWidget.myProfileId ||
        widget.myCrewId != oldWidget.myCrewId) {
      unawaited(_syncCellFills());
    }
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  Future<void> _onStyleLoaded() async {
    await _syncCellFills();
    await _updateMeMarker();
  }

  /// Disegna solo le celle con un proprietario noto in [widget.cells]:
  /// quelle libere non hanno mai una riga lato server, quindi non c'è
  /// nulla da rimuovere/aggiungere per loro — si vede la mappa reale.
  Future<void> _syncCellFills() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      final cells = widget.cells;
      for (final key in _cellFills.keys.toList()) {
        if (!cells.containsKey(key)) {
          await controller.removeFill(_cellFills.remove(key)!);
        }
      }

      final addKeys = <String>[];
      final addOptions = <FillOptions>[];
      for (final entry in cells.entries) {
        final color =
            _colorFor(entry.value, widget.mode, widget.myProfileId, widget.myCrewId);
        final existing = _cellFills[entry.key];
        if (color == null) {
          if (existing != null) {
            await controller.removeFill(_cellFills.remove(entry.key)!);
          }
          continue;
        }
        final hex = _colorToHex(color);
        if (existing == null) {
          addKeys.add(entry.key);
          addOptions.add(FillOptions(
            geometry: [
              [
                for (final (lat, lon) in HexGrid.polygonOf(entry.value.coord))
                  LatLng(lat, lon),
              ],
            ],
            fillColor: hex,
            fillOutlineColor: hex,
            fillOpacity: 0.55,
          ));
        } else if (existing.options.fillColor != hex) {
          await controller.updateFill(
            existing,
            FillOptions(fillColor: hex, fillOutlineColor: hex),
          );
        }
      }
      if (addOptions.isNotEmpty) {
        final added = await controller.addFills(addOptions);
        for (var i = 0; i < added.length; i++) {
          _cellFills[addKeys[i]] = added[i];
        }
      }
    } catch (_) {
      // Il supporto Fill/Circle di maplibre_gl non è uniforme su tutte le
      // piattaforme (in particolare il target web): niente territori
      // colorati piuttosto che un'eccezione che destabilizza il render
      // tree della mappa — stesso trattamento di trip_live_screen.dart.
    }
  }

  Future<void> _updateMeMarker() async {
    final controller = _controller;
    final lat = widget.lat;
    final lon = widget.lon;
    if (controller == null || lat == null || lon == null) return;
    try {
      final options = CircleOptions(
        geometry: LatLng(lat, lon),
        circleRadius: 9,
        circleColor: '#35E0FF',
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2.5,
        circleOpacity: 0.95,
      );
      final existing = _meCircle;
      if (existing == null) {
        _meCircle = await controller.addCircle(options);
      } else {
        await controller.updateCircle(existing, options);
      }
    } catch (_) {
      // Vedi commento in _syncCellFills.
    }
  }

  @override
  Widget build(BuildContext context) {
    final lat = widget.lat;
    final lon = widget.lon;
    if (lat == null || lon == null) {
      // Nessun fix GPS ancora: sfondo pieno, niente mappa con centro
      // arbitrario/sbagliato mostrato nel frattempo.
      return const ColoredBox(color: AppColors.guidaBg);
    }
    return MapLibreMap(
      styleString: dotenv.env['MAP_STYLE_URL'] ?? MapLibreStyles.demo,
      initialCameraPosition:
          CameraPosition(target: LatLng(lat, lon), zoom: _kDefaultZoom),
      onMapCreated: _onMapCreated,
      // addFill/addCircle prima che lo stile sia caricato lancia
      // "Annotation Manager has not been initialized" — va agganciato
      // qui, non in onMapCreated (che spara prima del caricamento stile).
      onStyleLoadedCallback: _onStyleLoaded,
      myLocationEnabled: false,
      compassEnabled: false,
    );
  }
}

// Le celle libere (owned == null, mai presenti in `cells`) restano sempre
// trasparenti: si vede solo la mappa dove qualcuno l'ha colorata.
Color? _colorFor(
  TerritoryCell owned,
  GameMapMode mode,
  String? myProfileId,
  String? myCrewId,
) {
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

String _colorToHex(Color c) {
  String channel(double v) =>
      (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${channel(c.r)}${channel(c.g)}${channel(c.b)}';
}
