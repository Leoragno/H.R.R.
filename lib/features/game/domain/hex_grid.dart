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
  /// painter), leggermente ristretti (0.92×) per un filo di margine fra
  /// celle adiacenti senza spezzare la continuità visiva di un territorio:
  /// due celle vicine dello stesso proprietario devono ancora leggersi come
  /// un blocco unico, non come tessere sparse. La dimensione "a schermo"
  /// degli esagoni non dipende da qui ma dallo zoom della mappa (vedi
  /// _kDefaultZoom in game_map_background.dart) — questo fattore serve solo
  /// a separare i bordi, non a rimpicciolire l'esagono. Puramente estetico:
  /// non tocca [cellOf]/[centerOf]/[hexMeters], quindi la griglia di gioco
  /// resta invariata e identica lato server.
  static List<(double lat, double lon)> polygonOf(HexCoord cell) {
    final (centerLat, centerLon) = centerOf(cell);
    final cosLat = math.cos(centerLat * math.pi / 180);
    const radius = hexMeters * 0.92;
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
}
