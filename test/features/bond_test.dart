import 'package:flutter_test/flutter_test.dart';
import 'package:hrr_app/features/progression/domain/bond.dart';
import 'package:hrr_app/features/rival/data/rival_dialogue.dart';
import 'package:hrr_app/features/rival/domain/entities/rival_popup.dart';

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

  test('legame LV3: frasi in più in radio, base sempre presenti', () {
    for (final id in ['nitro', 'r3x', 'volt', 'spark', 'dust']) {
      final base = phrasesFor(id, RivalMood.greeting);
      final bonded = phrasesFor(id, RivalMood.greeting, bonded: true);
      expect(bonded.length, greaterThan(base.length), reason: id);
      expect(bonded.take(base.length), base);
    }
    expect(phrasesFor('ignota', RivalMood.greeting, bonded: true), isNotEmpty);
  });
}
