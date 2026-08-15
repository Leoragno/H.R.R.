import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Badge rarità — predisposto: oggi `detected_rarity` è sempre null finché
/// non esiste una pipeline (AI o manuale) che lo valorizza, quindi il
/// widget si nasconde da solo quando non c'è nulla da mostrare.
class RarityBadge extends StatelessWidget {
  final String? rarity;

  const RarityBadge({super.key, required this.rarity});

  static const _colors = {
    'common': AppColor.rarityCommon,
    'uncommon': AppColor.rarityUncommon,
    'rare': AppColor.rarityRare,
    'epic': AppColor.rarityEpic,
    'legendary': AppColor.rarityLegendary,
  };

  @override
  Widget build(BuildContext context) {
    final r = rarity;
    if (r == null || !_colors.containsKey(r)) return const SizedBox.shrink();
    final color = _colors[r]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        r.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
