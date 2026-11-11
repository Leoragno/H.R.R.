// Confronto versioni dell'aggiornamento in-app con APK divise per ABI.
import 'package:flutter_test/flutter_test.dart';
import 'package:hrr_app/features/app_update/app_update_provider.dart';

void main() {
  test('toglie il prefisso ABI di --split-per-abi', () {
    expect(buildNumberOf(2002), 2); // arm64-v8a 0.1.1+2
    expect(buildNumberOf(1003), 3); // armeabi-v7a
    expect(buildNumberOf(4004), 4); // x86_64
    expect(buildNumberOf(3), 3); // release registrata senza prefisso
    expect(buildNumberOf(9004), 4); // riga di transizione per le app vecchie
  });

  test('una release più nuova è proposta, la stessa no', () {
    expect(buildNumberOf(4) > buildNumberOf(2003), isTrue);
    expect(buildNumberOf(9004) > buildNumberOf(2004), isFalse);
  });
}
