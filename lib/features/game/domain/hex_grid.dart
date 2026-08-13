import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// Coordinata assiale di una cella esagonale ("odd-r offset", stesso
/// layout del mockup Guida.dc.html righe 1678-1928). Nessuna dipendenza
/// Flutter qui: è pura matematica, condivisa fra il calcolo della cella
/// sotto al giocatore e il painter che disegna la griglia.
class HexCoord extends Equatable {
  final int q;
  final int r;
  const HexCoord(this.q, this.r);

  /// Chiave stabile usata come chiave di mappa lato client e come
  /// colonne (q, r) lato server — mai ricalcolata in modi diversi.
  String get key => '$q,$r';

  @override
  List<Object?> get props => [q, r];

  @override
  String toString() => key;
}

/// Offset locale in "unità esagono" (multiplo del raggio) rispetto a una
/// cella di riferimento — usato dal painter per posizionare ogni cella
/// sullo schermo senza dover ripassare da lat/lon.
class HexOffset {
  final double dx; // positivo verso est
  final double dy; // positivo verso nord
  const HexOffset(this.dx, this.dy);
}

/// Griglia geografica fissa: origine e dimensione esagono (~80 m da
/// bordo a bordo) sono costanti condivise 1:1 col server
/// (`supabase/migrations/0008_territory_game.sql`) — la stessa
/// posizione produce sempre la stessa (q, r) su qualunque device,
/// nessuna negoziazione della griglia.
class HexGrid {
  HexGrid._();

  static const double hexMeters = 46;
  static const double _gridOriginLat = 45.7205;
  static const double _gridOriginLon = 8.7460;
  static const double _metersPerDegreeLat = 111320;

  /// Porta 1:1 di `toGrid(lat, lon)` dal mockup: proiezione locale
  /// piatta (sufficiente su scala urbana/regionale, stessa approssimazione
  /// già accettata altrove nell'app per le distanze GPS).
  static HexCoord cellOf(double lat, double lon) {
    final north = (lat - _gridOriginLat) * _metersPerDegreeLat;
    final east = (lon - _gridOriginLon) *
        _metersPerDegreeLat *
        math.cos(lat * math.pi / 180);
    final r = (north / (hexMeters * 1.5)).round();
    final rOdd = r % 2 != 0;
    final q = (east / (hexMeters * 1.732) - (rOdd ? 0.5 : 0)).round();
    return HexCoord(q, r);
  }

  /// Area di una cella in km² — costante geometrica pura (esagono
  /// regolare di lato `hexMeters`).
  static double cellAreaKm2() {
    return (3 * math.sqrt(3) / 2) * hexMeters * hexMeters / 1e6;
  }

  /// Inversa di [cellOf]: coordinate geografiche del centro di [cell].
  /// Usata per disegnare la cella come poligono reale sulla mappa (Fill
  /// georeferenziato in game_map_background.dart) invece che come overlay
  /// in pixel scollegabile da pan/zoom.
  static (double lat, double lon) centerOf(HexCoord cell) {
    final rOdd = cell.r % 2 != 0;
    final north = cell.r * hexMeters * 1.5;
    final east = (cell.q + (rOdd ? 0.5 : 0)) * hexMeters * 1.732;
    final lat = _gridOriginLat + north / _metersPerDegreeLat;
    final lon = _gridOriginLon +
        east / (_metersPerDegreeLat * math.cos(lat * math.pi / 180));
    return (lat, lon);
  }

  /// I 6 vertici di [cell] come coordinate geografiche (stesso orientamento
  /// "pointy-top", vertici a -30°+60k°, già usato in pixel dal vecchio
  /// painter), leggermente ristretti (0.94×) per lasciare un filo di
  /// margine visibile fra celle adiacenti sulla mappa reale.
  static List<(double lat, double lon)> polygonOf(HexCoord cell) {
    final (centerLat, centerLon) = centerOf(cell);
    final cosLat = math.cos(centerLat * math.pi / 180);
    const radius = hexMeters * 0.94;
    return [
      for (var k = 0; k < 6; k++)
        _cornerLatLon(centerLat, centerLon, cosLat, radius, k),
    ];
  }

  static (double lat, double lon) _cornerLatLon(
    double centerLat,
    double centerLon,
    double cosLat,
    double radius,
    int k,
  ) {
    final angle = (math.pi / 180) * (60 * k - 30);
    final eastM = radius * math.cos(angle);
    final northM = -radius * math.sin(angle);
    final lat = centerLat + northM / _metersPerDegreeLat;
    final lon = centerLon + eastM / (_metersPerDegreeLat * cosLat);
    return (lat, lon);
  }

  /// Offset (in raggi esagono) di [cell] rispetto a [focus], per il
  /// rendering: stessa formula di `playHexes` nel mockup, generalizzata
  /// a qualunque dimensione in pixel scelga il painter.
  static HexOffset offsetFrom(HexCoord focus, HexCoord cell) {
    final cellOdd = cell.r % 2 != 0;
    final focusOdd = focus.r % 2 != 0;
    final dx = 1.732 *
        (cell.q - focus.q + ((cellOdd ? 0.5 : 0) - (focusOdd ? 0.5 : 0)));
    final dy = -1.5 * (cell.r - focus.r);
    return HexOffset(dx, dy);
  }
}
