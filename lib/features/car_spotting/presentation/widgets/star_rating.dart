import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Rendering di sola lettura di una media stelle (0.5–5, mezze stelle
/// incluse). Per la selezione interattiva vedi [RatingSelector].
class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  final Color color;

  const StarRating({
    super.key,
    required this.rating,
    this.size = 16,
    this.color = AppColors.neonAmber,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final threshold = i + 1;
        IconData icon;
        if (rating >= threshold) {
          icon = Icons.star_rounded;
        } else if (rating >= threshold - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }
        return Icon(icon, size: size, color: color);
      }),
    );
  }
}
