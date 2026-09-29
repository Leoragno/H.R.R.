import 'dart:async';
import 'dart:convert';
import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
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
  // Bordi (sud, ovest, nord, est) dell'area inquadrata a camera ferma —
  // il chiamante ricarica le celle di quella zona.
  final void Function(
          double southLat, double westLon, double northLat, double eastLon)?
      onViewportChanged;

  const GameMapBackground({
    super.key,
    required this.lat,
    required this.lon,
    required this.cells,
    required this.mode,
    required this.myProfileId,
    this.onViewportChanged,
  });

  @override
  ConsumerState<GameMapBackground> createState() => GameMapBackgroundState();
}

// Tutte le celle stanno in un'unica sorgente GeoJSON + un layer fill con
// colore/opacità letti dalle proprietà di ogni feature: un solo
// setGeoJsonSource per aggiornare l'intera mappa. Prima ogni cella era
// un'annotazione Fill separata, aggiunta/rimossa/aggiornata con una
// chiamata di piattaforma a testa — con centinaia di celle e un refresh a
// ogni pan la mappa laggava vistosamente.
const _kCellsSourceId = 'hrr-cells';
const _kCellsLayerId = 'hrr-cells-fill';

class GameMapBackgroundState extends ConsumerState<GameMapBackground> {
  MapLibreMapController? _controller;
  Circle? _meCircle;
  bool _cellsLayerReady = false;
  // Ultimo GeoJSON inviato: evita di ricaricare la sorgente se niente è
  // cambiato (es. rebuild per un fix GPS o un cambio di pannello).
  String? _lastCellsSignature;

  // Lo stile MapLibre (tile, colori) arriva in modo asincrono dopo che il
  // widget nativo è già montato: senza questo la mappa resta un riquadro
  // nero per un momento prima di popolarsi di scatto. Il fade (sotto, in
  // build) copre quella finestra con lo stesso nero di sfondo, poi lascia
  // apparire la mappa gradualmente invece che di colpo.
  bool _styleLoaded = false;

  // Proprietario di ogni feature disegnata, indicizzato per id numerico
  // della feature GeoJSON (posizione nella lista): MapLibre GL JS scarta
  // gli id stringa, quindi sul web il tap non saprebbe quale cella è.
  final List<String> _ownerByFeatureId = [];

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
    controller.onFeatureTapped.add(_onFeatureTapped);
  }

  @override
  void dispose() {
    _controller?.onFeatureTapped.remove(_onFeatureTapped);
    super.dispose();
  }

  Future<void> _onCameraIdle() async {
    final controller = _controller;
    final callback = widget.onViewportChanged;
    if (controller == null || callback == null) return;
    try {
      final bounds = await controller.getVisibleRegion();
      if (!mounted) return;
      callback(
        bounds.southwest.latitude,
        bounds.southwest.longitude,
        bounds.northeast.latitude,
        bounds.northeast.longitude,
      );
    } catch (_) {
      // Regione visibile non disponibile su questa piattaforma: resta la
      // finestra attorno al GPS caricata dal controller.
    }
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller != null) {
      try {
        await controller.addGeoJsonSource(
            _kCellsSourceId, _featureCollection(const []));
        await controller.addFillLayer(
          _kCellsSourceId,
          _kCellsLayerId,
          const FillLayerProperties(
            fillColor: [Expressions.get, 'color'],
            fillOutlineColor: [Expressions.get, 'color'],
            fillOpacity: [Expressions.get, 'opacity'],
          ),
        );
        _cellsLayerReady = true;
        _lastCellsSignature = null;
      } catch (_) {
        // Vedi commento in _syncCellFills.
      }
    }
    await _syncCellFills();
    await _updateMeMarker();
    unawaited(_onCameraIdle());
    if (!mounted) return;
    setState(() => _styleLoaded = true);
  }

  /// Disegna solo le celle con un proprietario noto in [widget.cells]:
  /// quelle libere non hanno mai una riga lato server, quindi non c'è
  /// nulla da rimuovere/aggiungere per loro — si vede la mappa reale.
  Future<void> _syncCellFills() async {
    final controller = _controller;
    if (controller == null || !_cellsLayerReady) return;

    try {
      final features = <Map<String, dynamic>>[];
      final owners = <String>[];
      for (final entry in widget.cells.entries) {
        final color = _colorFor(entry.value, widget.mode, widget.myProfileId);
        if (color == null) continue;
        final featureId = owners.length;
        owners.add(entry.value.ownerId);
        final ring = [
          for (final (lat, lon) in HexGrid.polygonOf(entry.value.coord))
            [lon, lat],
        ];
        ring.add(ring.first); // GeoJSON: anello chiuso.
        features.add({
          'type': 'Feature',
          'id': featureId,
          'properties': {
            'key': entry.key,
            'color': _colorToHex(color),
            // Arrotondata: lo sbiadimento dipende da DateTime.now(), e
            // senza arrotondare la firma sotto cambierebbe a ogni sync.
            'opacity': (_fillOpacityFor(entry.value) * 100).round() / 100,
          },
          'geometry': {
            'type': 'Polygon',
            'coordinates': [ring],
          },
        });
      }
      _ownerByFeatureId
        ..clear()
        ..addAll(owners);

      final collection = _featureCollection(features);
      final signature = jsonEncode(collection);
      if (signature == _lastCellsSignature) return;
      _lastCellsSignature = signature;
      await controller.setGeoJsonSource(_kCellsSourceId, collection);
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
  void _onFeatureTapped(
    Point<double> point,
    LatLng coordinates,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (layerId != _kCellsLayerId) return;
    // Nativo restituisce "3", web a volte "3.0": entrambi validi.
    final index = int.tryParse(id) ?? double.tryParse(id)?.toInt();
    final ownerId =
        index != null && index >= 0 && index < _ownerByFeatureId.length
            ? _ownerByFeatureId[index]
            : null;
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
      // arbitrario/sbagliato mostrato nel frattempo — ma uno spinner
      // sommesso invece del nero muto, così è chiaro che sta caricando e
      // non che lo schermo sia bloccato.
      return const ColoredBox(
        color: AppColor.void_,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColor.inkMuted,
            ),
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        MapLibreMap(
          styleString: dotenv.env['MAP_STYLE_URL'] ?? MapLibreStyles.demo,
          initialCameraPosition:
              CameraPosition(target: LatLng(lat, lon), zoom: _kDefaultZoom),
          onMapCreated: _onMapCreated,
          // addFill/addCircle prima che lo stile sia caricato lancia
          // "Annotation Manager has not been initialized" — va agganciato
          // qui, non in onMapCreated (che spara prima del caricamento stile).
          onStyleLoadedCallback: _onStyleLoaded,
          onCameraIdle: () => unawaited(_onCameraIdle()),
          myLocationEnabled: false,
          compassEnabled: false,
        ),
        // Stesso nero di sfondo sopra la mappa finché lo stile non è
        // pronto: senza, il riquadro nativo resta vuoto/nero di suo per
        // un istante e poi si popola di scatto. IgnorePointer perché
        // altrimenti, mentre svanisce, ruberebbe i tap destinati alla
        // mappa sotto.
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _styleLoaded ? 0 : 1,
            duration: AppMotion.base,
            curve: AppMotion.curve,
            child: const ColoredBox(
              color: AppColor.void_,
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColor.inkMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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

Map<String, dynamic> _featureCollection(List<Map<String, dynamic>> features) =>
    {'type': 'FeatureCollection', 'features': features};

String _colorToHex(Color c) {
  String channel(double v) =>
      (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${channel(c.r)}${channel(c.g)}${channel(c.b)}';
}
