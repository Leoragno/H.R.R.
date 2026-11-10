import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrr_app/features/progression/presentation/level_up_overlay.dart';

Future<void> _show(WidgetTester tester, int from, int to) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () => showLevelUp(context, from: from, to: to),
        child: const Text('su'),
      ),
    ),
  ));
  await tester.tap(find.text('su'));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  test('prossimo titolo', () {
    expect(nextTitleLevel(1), 5);
    expect(nextTitleLevel(5), 10);
    expect(nextTitleLevel(44), 45);
    expect(nextTitleLevel(45), isNull);
  });

  testWidgets('level up: numero, titolo nuovo, chiusura', (tester) async {
    await _show(tester, 4, 5);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('nuovo titolo sbloccato.'), findsOneWidget);
    await tester.tap(find.text('AVANTI'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.text('LIVELLO SUPERIORE'), findsNothing);
  });

  testWidgets('level up senza cambio titolo', (tester) async {
    await _show(tester, 6, 7);
    expect(find.text('a LV 10 diventi pro.'), findsOneWidget);
  });
}
