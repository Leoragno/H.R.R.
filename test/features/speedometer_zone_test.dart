// Fascia sotto il tachimetro: "IN ATTESA GPS" solo senza segnale,
// "FERMO" da fermi col segnale buono.
import 'package:flutter_test/flutter_test.dart';
import 'package:hrr_app/features/trip/presentation/providers/trip_live_provider.dart';
import 'package:hrr_app/features/trip/presentation/widgets/speedometer_gauge.dart';

void main() {
  test('senza fix GPS: IN ATTESA GPS anche se la velocità è nota', () {
    expect(SpeedometerGauge.zoneFor(0, hasGpsFix: false).$1, 'IN ATTESA GPS');
    expect(SpeedometerGauge.zoneFor(50, hasGpsFix: false).$1, 'IN ATTESA GPS');
  });

  test('con fix GPS: FERMO a zero, poi le zone di velocità', () {
    expect(SpeedometerGauge.zoneFor(0).$1, 'FERMO');
    expect(SpeedometerGauge.zoneFor(40).$1, 'URBANO');
    expect(SpeedometerGauge.zoneFor(100).$1, 'EXTRAURBANO');
    expect(SpeedometerGauge.zoneFor(140).$1, 'OLTRE IL LIMITE');
  });

  test('il fix scade dopo 15 secondi', () {
    final t = DateTime(2026, 11, 11, 10);
    final s = TripLiveState(lastGoodFixAt: t);
    expect(const TripLiveState().hasGpsFix(t), isFalse);
    expect(s.hasGpsFix(t.add(const Duration(seconds: 5))), isTrue);
    expect(s.hasGpsFix(t.add(const Duration(seconds: 20))), isFalse);
  });
}
