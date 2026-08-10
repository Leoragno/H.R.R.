import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/trip_live_provider.dart';

class SpeedBand {
  final String label;
  final Color color;
  final double fraction;
  const SpeedBand(this.label, this.color, this.fraction);
}

const _bandColors = [
  Color(0xFF35E0FF),
  Color(0xFF2F6BFF),
  Color(0xFF7B3BFF),
  Color(0xFFC23DFF),
  Color(0xFFFF2D55),
];
const _bandLabels = ['0-30', '30-60', '60-90', '90-120', '120+'];
const _bandUpperBounds = [30.0, 60.0, 90.0, 120.0, double.infinity];

/// Ripartizione del tempo di guida per fascia di velocità — calcolata dai
/// campioni di telemetria reali raccolti durante il viaggio (vedi
/// TelemetrySample), non un valore inventato. Guida.dc.html righe 893-914.
List<SpeedBand> computeSpeedBands(List<TelemetrySample> samples) {
  if (samples.isEmpty) {
    return [
      for (var i = 0; i < 5; i++) SpeedBand(_bandLabels[i], _bandColors[i], 0)
    ];
  }
  final counts = List<int>.filled(5, 0);
  for (final s in samples) {
    for (var i = 0; i < _bandUpperBounds.length; i++) {
      if (s.speedKmh < _bandUpperBounds[i]) {
        counts[i]++;
        break;
      }
    }
  }
  final total = samples.length;
  return [
    for (var i = 0; i < 5; i++)
      SpeedBand(_bandLabels[i], _bandColors[i], counts[i] / total),
  ];
}

class SpeedDistributionBar extends StatelessWidget {
  final List<SpeedBand> bands;
  const SpeedDistributionBar({super.key, required this.bands});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                for (final b in bands)
                  Expanded(
                    flex: (b.fraction * 1000).round().clamp(0, 100000) + 1,
                    child: Container(color: b.color),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final b in bands)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              color: b.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(b.label,
                              style: AppTheme.archivo(
                                  fontSize: 12, color: const Color(0xFFCFDCEC)),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${(b.fraction * 100).round()}%',
                        style: AppTheme.archivo(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
