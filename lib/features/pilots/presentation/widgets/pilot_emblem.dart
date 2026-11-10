import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';

/// Emblema esagonale di un pilota ("Che pilota sei"): sigla in Barlow
/// corsivo + piccola scacchiera sotto. [locked] mostra "?" in grigio.
class PilotEmblem extends StatelessWidget {
  const PilotEmblem({
    super.key,
    required this.monogram,
    this.width = 42,
    this.color,
    this.fill = AppColor.surfaceHigh,
    this.textColor,
    this.glow = false,
    this.checker = true,
    this.locked = false,
  });

  final String monogram;
  final double width;

  /// Bordo; null = grigio linea.
  final Color? color;
  final Color fill;
  final Color? textColor;
  final bool glow;
  final bool checker;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final border = color ?? AppColor.lineMuted;
    final ink = locked ? AppColor.inkFaint : (textColor ?? AppColor.ink);
    final h = width * 1.16;
    return SizedBox(
      width: width,
      height: h,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: locked ? AppColor.deep : fill,
          shape: HexEmblemBorder(
            side: BorderSide(color: border, width: width > 60 ? 2 : 1.5),
          ),
          shadows: glow
              ? [BoxShadow(color: border.withValues(alpha: .5), blurRadius: 14)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              locked ? '?' : monogram,
              style: AppType.display(
                fontWeight: FontWeight.w900,
                fontSize: width * .4,
                height: 1,
                color: ink,
              ),
            ),
            if (checker && width >= 36) ...[
              SizedBox(height: width * .07),
              _Checker(width: width * .42, color: ink.withValues(alpha: .7)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Checker extends StatelessWidget {
  const _Checker({required this.width, required this.color});
  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(width, 5), painter: _CheckerPainter(color));
}

class _CheckerPainter extends CustomPainter {
  _CheckerPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const s = 2.5;
    final p = Paint()..color = color;
    for (var x = 0; x * s < size.width; x++) {
      for (var y = 0; y < 2; y++) {
        if ((x + y).isEven) {
          canvas.drawRect(Rect.fromLTWH(x * s, y * s, s, s), p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter old) => old.color != color;
}

/// Stelle di maestria 0..5.
class MasteryStars extends StatelessWidget {
  const MasteryStars(this.level, {super.key, this.size = 16});
  final int level;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++)
            Icon(
              i < level ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i < level ? AppColor.gold : AppColor.lineMuted,
            ),
        ],
      );
}
