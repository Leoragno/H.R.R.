import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

// Etichette contestuali sotto il valore, in stile "racing" coerente col
// resto dell'app — calcolate da soglie sul dato reale, non inventate.
// Condivise tra TripSummaryScreen (report appena finita la corsa) e
// TripDetailScreen (stesso viaggio riaperto più tardi dallo storico,
// 0030_persist_trip_motion_stats.sql): stessa soglia, stesso testo.
String gForceHint(double g) {
  if (g >= 1.0) return 'Impatto forte';
  if (g >= 0.6) return 'Frenata/curva decisa';
  if (g >= 0.3) return 'Guida sportiva';
  return 'Guida regolare';
}

String accelHint(double a) {
  if (a >= 6) return 'Partenza sportiva';
  if (a >= 3) return 'Accelerazione decisa';
  return 'Accelerazione regolare';
}

String decelHint(double a) {
  final abs = a.abs();
  if (abs >= 8) return 'Frenata di emergenza';
  if (abs >= 4) return 'Frenata decisa';
  return 'Frenata regolare';
}

String formatTripDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m}min';
  return '$m min';
}

String formatStoppedTime(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '${m}m ${s}s';
}

class TripStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String? hint;
  const TripStatCard(this.label, this.value, this.unit,
      {super.key, this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm, vertical: AppSpace.sm),
      decoration: AppGlow.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppType.caption, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Text.rich(
            TextSpan(
              text: value,
              style: AppType.metric.copyWith(fontSize: 22),
              children: [
                if (unit.isNotEmpty)
                  TextSpan(text: ' $unit', style: AppType.caption),
              ],
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!, style: AppType.caption, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}
