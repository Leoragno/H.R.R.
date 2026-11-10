import 'package:flutter_test/flutter_test.dart';
import 'package:hrr_app/features/progression/domain/bond.dart';

void main() {
  test('livello del legame con le soglie di bond_level', () {
    expect(bondLevel(0), 1);
    expect(bondLevel(59), 1);
    expect(bondLevel(60), 2);
    expect(bondLevel(170), 3);
    expect(bondLevel(2800), 10);
    expect(bondLevel(-5), 1);
  });

  test('avanzamento, bonus e prossimo sblocco', () {
    const b = BondProgress(110);
    expect(b.level, 2);
    expect(b.toNext, 50);
    expect(b.fraction, closeTo(.5, 1e-9));
    expect(b.bonusPercent, 5);
    expect(b.nextUnlock, (3, 'frasi nuove in radio'));
    expect(b.unlocked(2), isTrue);
    expect(b.unlocked(5), isFalse);
  });

  test('legame massimo', () {
    const b = BondProgress(5000);
    expect(b.maxed, isTrue);
    expect(b.toNext, 0);
    expect(b.fraction, 1);
    expect(b.nextUnlock, isNull);
  });
}
