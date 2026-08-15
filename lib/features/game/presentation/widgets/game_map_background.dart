import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/territory_cell.dart';
import '../../domain/hex_grid.dart';
import '../../domain/territory_color.dart';
import '../providers/game_controller.dart' show GameMapMode;
import '../providers/territory_provider.dart';

// La dimensione "a schermo" di un esagono dipende da qui, non dalla
// geometria in hex_grid.dart: uno zoom più basso mostra più area nello
// stesso spazio, quindi celle (46 m di lato fisso, condiviso col server)
// più piccole a schermo. Ridotto da 16 così gli esagoni si leggono più
// piccoli — vedi anche _kViewCols/_kViewRows in game_controller.dart,
// allargati in proporzione per continuare a coprire lo schermo a questo
// zoom più ampio.
const _kDefaultZoom = 15.0;

// Sbiadimento verso la scadenza (brief, punto 1: "da 3 giorni prima della
// scadenza si mostra sbiadito"). _kDecayDays deve restare allineato a
// territory_decay_days() in 0026_territory_decay_counterattack.sql — solo
// per il calcolo visivo qui: la fonte di verità sulla scadenza reale resta
// il server (territory_cells_near non restituisce più le celle decadute).
const _kDecayDays = 14;
const _kFadeWarningDays = 3;
const _kBaseFillOpacity = 0.55;
const _kFadedFillOpacity = 0.22;

double _fillOpacityFor(TerritoryCell cell) {
  final daysLeft =
      _kDecayDays - DateTime.now().difference(cell.claimedAt).inHours / 24;
  if (daysLeft > _kFadeWarningDays) return _kBaseFillOpacity;
  final t = (daysLeft / _kFadeWarningDays).clamp(0.0, 1.0);
  return _kFadedFillOpacity + (_kBaseFillOpacity - _kFadedFillOpacity) * t;
}

/// Mappa reale (stessa MapLibre GL usata in Home/Guida), interattiva
/// (pan/zoom liberi come nella sezione Guida) con sopra le celle
/// possedute disegnate come poligoni [Fill] georeferenziati — non più un
/// overlay in pixel a parte, quindi restano sempre allineati al terreno
/// vero a qualunque zoom/posizione della camera scelga l'utente. La
/// camera segue il GPS solo al primo fix e su [recenter] esplicito (vedi
/// pulsante "centra" in game_screen.dart), mai ad ogni fix — altrimenti
/// vanificherebbe il pan/zoom libero.
class GameMapBackground extends ConsumerStatefulWidget {
  final double? lat;
  final double? lon;
  final Map<String, TerritoryCell> cells;
  final GameMapMode mode;
  final String? myProfileId;

  const GameMapBackground({
    super.key,
    required this.lat,
    required this.lon,
    required this.cells,
    required this.mode,
    required this.myProfileId,
  });

  @override
  ConsumerState<GameMapBackground> createState() => GameMapBackgroundState();
}

class GameMapBackgroundState extends ConsumerState<GameMapBackground> {
  MapLibreMapController? _controller;
  Circle? _meCircle;
  final Map<String, Fill> _cellFills = {};

  // Proprietario corrente di ogni cella disegnata, tenuto separato dal
  // colore: il colore può restare invariato tra due owner diversi (hash
  // collision sulla palette rivali), quindi non è un proxy affidabile per
  // "la proprietà è cambiata". Aggiornati ogni sync, indipendentemente dal
  // fatto che il fill venga ridisegnato o meno — usati al tap per risalire
  // a chi possiede la cella toccata.
  final Map<String, String> _ownerByCellKey = {};
  final Map<String, String> _cellKeyByFillId = {};

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
        widget.myProfileId != oldWidget.myProfileId) {
      unawaited(_syncCellFills());
    }
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.onFillTapped.add(_onFillTapped);
  }

  @override
  void dispose() {
    _controller?.onFillTapped.remove(_onFillTapped);
    super.dispose();
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
          final fill = _cellFills.remove(key)!;
          _cellKeyByFillId.remove(fill.id);
          _ownerByCellKey.remove(key);
          await controller.removeFill(fill);
        }
      }

      final addKeys = <String>[];
      final addOptions = <FillOptions>[];
      for (final entry in cells.entries) {
        final color = _colorFor(entry.value, widget.mode, widget.myProfileId);
        final existing = _cellFills[entry.key];
        if (color == null) {
          if (existing != null) {
            _cellKeyByFillId.remove(existing.id);
            _ownerByCellKey.remove(entry.key);
            await controller.removeFill(_cellFills.remove(entry.key)!);
          }
          continue;
        }
        // Aggiornato a ogni passata, non solo quando il colore cambia: è la
        // fonte di verità per il tap, indipendente da eventuali collisioni
        // di colore fra due proprietari diversi sulla palette rivali.
        _ownerByCellKey[entry.key] = entry.value.ownerId;
        final hex = _colorToHex(color);
        final opacity = _fillOpacityFor(entry.value);
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
            fillOpacity: opacity,
          ));
        } else if (existing.options.fillColor != hex ||
            existing.options.fillOpacity != opacity) {
          await controller.updateFill(
            existing,
            FillOptions(fillColor: hex, fillOutlineColor: hex, fillOpacity: opacity),
          );
        }
      }
      if (addOptions.isNotEmpty) {
        final added = await controller.addFills(addOptions);
        for (var i = 0; i < added.length; i++) {
          _cellFills[addKeys[i]] = added[i];
          _cellKeyByFillId[added[i].id] = addKeys[i];
        }
      }
    } catch (_) {
      // Il supporto Fill/Circle di maplibre_gl non è uniforme su tutte le
      // piattaforme (in particolare il target web): niente territori
      // colorati piuttosto che un'eccezione che destabilizza il render
      // tree della mappa — stesso trattamento di trip_live_screen.dart.
    }
  }

  /// Tap su una cella colorata: mostra di chi è. [cellsNear] restituisce
  /// solo l'id proprietario (non tutti sono in classifica, limitata ai top
  /// player), quindi il nome va risolto al volo con una query mirata
  /// invece di dipendere da territoryStandingsProvider.
  void _onFillTapped(Fill fill) {
    final key = _cellKeyByFillId[fill.id];
    final ownerId = key == null ? null : _ownerByCellKey[key];
    if (ownerId == null) return;
    unawaited(_showOwnerName(ownerId));
  }

  Future<void> _showOwnerName(String ownerId) async {
    if (!mounted) return;
    if (ownerId == widget.myProfileId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Questa cella è tua.')),
      );
      return;
    }
    try {
      final name =
          await ref.read(territoryRepositoryProvider).profileDisplayName(ownerId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              name == null ? 'Giocatore sconosciuto' : 'Territorio di $name'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile verificare il proprietario')),
      );
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
        circleColor: _colorToHex(AppColor.cyan),
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
      return const ColoredBox(color: AppColor.void_);
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
) {
  final isMine = owned.ownerId == myProfileId;
  if (mode == GameMapMode.mineOnly) {
    return isMine ? AppColor.cyan : null;
  }
  return territoryIdentityColor(
    ownerId: owned.ownerId,
    myProfileId: myProfileId,
  );
}

String _colorToHex(Color c) {
  String channel(double v) =>
      (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${channel(c.r)}${channel(c.g)}${channel(c.b)}';
}
