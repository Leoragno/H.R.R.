import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/driver_archetype.dart';

/// Card "CHE PILOTA SEI" — mostra il pilota di film/serie più vicino allo
/// stile del viaggio (vedi driver_archetype.dart). Volutamente grigia su
/// superficie, senza accento né glow: nel report il protagonista resta il
/// punteggio di guida (DESIGN.md, un solo elemento acceso per schermata).
/// Non mostra nulla se il viaggio non basta per un abbinamento onesto.
class DriverArchetypeCard extends StatelessWidget {
  final DrivingStyleInput? input;

  /// Spazio sotto la card, incluso qui così sparisce insieme a lei quando
  /// non c'è abbinamento (niente buchi vuoti nella lista).
  final double bottomSpacing;
  const DriverArchetypeCard(
      {super.key, required this.input, this.bottomSpacing = 0});

  @override
  Widget build(BuildContext context) {
    final data = input;
    final match = data == null ? null : matchDriverArchetype(data);
    if (match == null) return const SizedBox.shrink();
    final a = match.archetype;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: bottomSpacing),
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: AppGlow.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.movie_filter_rounded,
                  size: 16, color: AppColor.inkMuted),
              const SizedBox(width: AppSpace.sm),
              Text('CHE PILOTA SEI', style: AppType.label),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Text(a.name.toUpperCase(),
              style: AppType.metric.copyWith(fontSize: 26)),
          const SizedBox(height: 2),
          Text(a.source, style: AppType.caption),
          const SizedBox(height: AppSpace.sm),
          Text(a.tagline, style: AppType.body),
          if (match.reasons.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.xs,
              children: [
                for (final r in match.reasons)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.sm, vertical: AppSpace.xs),
                    decoration: BoxDecoration(
                      color: AppColor.surfaceHigh,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColor.line),
                    ),
                    child: Text(r, style: AppType.caption),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
