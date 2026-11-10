import 'package:flutter_test/flutter_test.dart';
import 'package:hrr_app/features/game/domain/hex_grid.dart';
import 'package:hrr_app/features/game/domain/territory_attack.dart';

void main() {
  final t0 = DateTime(2026, 11, 10, 12);

  test('sotto attacco: ladro più recente, celle uniche, FLOW da battere', () {
    final a = TerritoryAttack.latest([
      LostCell(
          cell: const HexCoord(1, 1), thiefId: 'x', at: t0, thiefScore: 70),
      LostCell(
          cell: const HexCoord(2, 1),
          thiefId: 'y',
          at: t0.add(const Duration(hours: 2)),
          thiefScore: 81),
      LostCell(
          cell: const HexCoord(3, 1),
          thiefId: 'y',
          at: t0.add(const Duration(hours: 1)),
          thiefScore: 88),
      LostCell(
          cell: const HexCoord(2, 1),
          thiefId: 'y',
          at: t0.add(const Duration(minutes: 30))),
    ], (id) => 'pilota_$id')!;
    expect(a.thiefName, 'pilota_y');
    expect(a.count, 2);
    expect(a.flowToBeat, 88);
    expect(a.lastAt, t0.add(const Duration(hours: 2)));
  });

  test('nessun furto: nessuna card', () {
    expect(TerritoryAttack.latest(const [], (id) => id), isNull);
  });

  test('tempo trascorso', () {
    expect(attackAgo(t0, t0.add(const Duration(seconds: 20))), 'adesso');
    expect(attackAgo(t0, t0.add(const Duration(minutes: 5))), 'da 5 min');
    expect(attackAgo(t0, t0.add(const Duration(hours: 3))), 'da 3 h');
  });
}
