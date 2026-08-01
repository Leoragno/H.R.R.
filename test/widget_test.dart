// Smoke test minimo: verifica che il tema HRR si costruisca senza errori.
// Un test end-to-end che monta HrrApp richiederebbe di mockare
// Supabase/Firebase (inizializzati in main()) — fuori scopo per questo
// smoke test, che serve solo a validare la pipeline di build/test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hrr_app/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppTheme.dark si costruisce senza eccezioni', () {
    final theme = AppTheme.dark;
    expect(theme.useMaterial3, isTrue);
    expect(theme.brightness, Brightness.dark);
  });
}
