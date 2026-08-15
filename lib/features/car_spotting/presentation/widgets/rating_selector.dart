import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Selettore stelle interattivo (0.5–5, mezze stelle). Ogni stella è
/// divisa in due zone tap: metà sinistra seleziona il mezzo voto, metà
/// destra il voto pieno. Mostra sempre il voto personale dell'utente,
/// mai quello di altri (coerente con l'aggregato pubblico ma il singolo
/// voto privato).
class StarRatingSelector extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double size;

  const StarRatingSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starIndex = i + 1;
        final filled = value >= starIndex
            ? 1.0
            : value >= starIndex - 0.5
                ? 0.5
                : 0.0;

        return Builder(builder: (starContext) {
          return GestureDetector(
            onTapUp: (details) {
              final box = starContext.findRenderObject() as RenderBox;
              final local = box.globalToLocal(details.globalPosition);
              final tappedLeftHalf = local.dx < box.size.width / 2;
              onChanged(
                  tappedLeftHalf ? starIndex - 0.5 : starIndex.toDouble());
            },
            child: TweenAnimationBuilder<double>(
              key: ValueKey('$starIndex-$filled'),
              tween: Tween(begin: 1.25, end: 1.0),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Icon(
                filled == 1.0
                    ? Icons.star_rounded
                    : filled == 0.5
                        ? Icons.star_half_rounded
                        : Icons.star_border_rounded,
                size: size,
                color: AppColor.amber,
              ),
            ),
          );
        });
      }),
    );
  }
}
