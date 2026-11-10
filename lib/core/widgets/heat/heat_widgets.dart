// HEAT — componenti base condivisi da tutte le schermate.
// Vedi DESIGN.md: un solo elemento acceso (accento + glow) per schermata.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/heat_shapes.dart';

bool _reduceMotion(BuildContext c) => MediaQuery.disableAnimationsOf(c);

/// Feedback di pressione del prototipo: `scale(.97)` + `brightness(.85)`.
class HeatPressable extends StatefulWidget {
  const HeatPressable({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<HeatPressable> createState() => _HeatPressableState();
}

class _HeatPressableState extends State<HeatPressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        child: AnimatedOpacity(
          // Approssima `brightness(.85)` senza ColorFilter costosi.
          opacity: _down ? 0.85 : 1,
          duration: AppMotion.fast,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Pannello HEAT: superficie scura, bordo 1px, forma inclinata/smussata.
class HeatPanel extends StatelessWidget {
  const HeatPanel({
    super.key,
    required this.child,
    this.shape = const SlantBorder(),
    this.color = AppColor.surface,
    this.gradient,
    this.borderColor = AppColor.line,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.glow,
    this.onTap,
  });

  final Widget child;
  final OutlinedBorder shape;
  final Color color;
  final Gradient? gradient;

  /// `null` = senza bordo.
  final Color? borderColor;
  final EdgeInsetsGeometry padding;

  /// Colore del glow (drop-shadow). Solo per l'elemento acceso dello schermo.
  final Color? glow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final side =
        borderColor == null ? BorderSide.none : BorderSide(color: borderColor!);
    final box = DecoratedBox(
      decoration: ShapeDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        shape: shape.copyWith(side: side),
        shadows: glow == null
            ? null
            : [BoxShadow(color: glow!.withValues(alpha: .5), blurRadius: 22)],
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: Padding(padding: padding, child: child),
      ),
    );
    if (onTap == null) return box;
    return HeatPressable(onTap: onTap, child: box);
  }
}

/// CTA primaria: parallelogramma pieno d'accento, display corsivo 900,
/// glow morbido e riflesso che scorre. Una per schermata.
class HeatButton extends StatelessWidget {
  const HeatButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.keyboard_double_arrow_right_rounded,
    this.subtitle,
    this.height = 60,
    this.fontSize = 26,
    this.color,
    this.gradientEnd,
    this.glow = true,
    this.alignStart = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? subtitle;
  final double height;
  final double fontSize;

  /// Default: [AppColor.accent].
  final Color? color;

  /// Se presente, gradiente a 100° accento → [gradientEnd] (es. AVVIA GUIDA).
  final Color? gradientEnd;
  final bool glow;

  /// Testo a sinistra e icona a destra (stile AVVIA GUIDA).
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColor.accent;
    final cut = (height / 4).clamp(6.0, 20.0);
    final shape = SlantBorder.all(cut);
    final disabled = onPressed == null;
    final textStyle = AppType.display(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      color: AppColor.onAccent,
      letterSpacing: 1.5,
      height: .9,
    );

    final text = subtitle == null
        ? Text(label.toUpperCase(), style: textStyle)
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: textStyle),
              Text(
                subtitle!,
                style: AppType.text(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColor.onAccent.withValues(alpha: .75),
                ),
              ),
            ],
          );

    final ic = icon == null
        ? null
        : Icon(icon, color: AppColor.onAccent, size: fontSize * 1.15);

    return Opacity(
      opacity: disabled ? .45 : 1,
      child: HeatPressable(
        onTap: onPressed,
        child: Container(
          height: height,
          decoration: ShapeDecoration(
            shape: shape,
            color: gradientEnd == null ? c : null,
            gradient: gradientEnd == null
                ? null
                : LinearGradient(
                    // 100deg ≈ quasi orizzontale, leggermente in discesa.
                    begin: const Alignment(-1, -.18),
                    end: const Alignment(1, .18),
                    colors: [c, c, gradientEnd!],
                    stops: const [0, .55, 1],
                  ),
            shadows: glow && !disabled
                ? [BoxShadow(color: c.withValues(alpha: .5), blurRadius: 22)]
                : null,
          ),
          child: ClipPath(
            clipper: ShapeBorderClipper(shape: shape),
            child: Stack(
              children: [
                if (!disabled && !_reduceMotion(context))
                  const Positioned.fill(child: _Shine()),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: alignStart ? cut + 12 : cut,
                  ),
                  child: Row(
                    mainAxisAlignment: alignStart
                        ? MainAxisAlignment.spaceBetween
                        : MainAxisAlignment.center,
                    children: [
                      Flexible(child: text),
                      if (ic != null) ...[const SizedBox(width: 8), ic],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottone secondario a parallelogramma: superficie scura, bordo linea,
/// testo chiaro. Con [label] null mostra solo l'icona.
class HeatGhostButton extends StatelessWidget {
  const HeatGhostButton({
    super.key,
    this.label,
    this.icon,
    required this.onPressed,
    this.height = 56,
    this.fontSize = 18,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    const shape = SlantBorder.all(12, side: BorderSide(color: AppColor.line));
    return Opacity(
      opacity: onPressed == null ? .45 : 1,
      child: HeatPressable(
        onTap: onPressed,
        child: Container(
          height: height,
          decoration:
              const ShapeDecoration(shape: shape, color: AppColor.surface),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Icon(icon, color: AppColor.ink, size: fontSize + 4),
              if (icon != null && label != null) const SizedBox(width: 6),
              if (label != null)
                Flexible(
                  child: Text(
                    label!.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.display(
                      fontSize: fontSize,
                      italic: false,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Riflesso bianco che attraversa la CTA ogni ~3.4s.
class _Shine extends StatefulWidget {
  const _Shine();

  @override
  State<_Shine> createState() => _ShineState();
}

class _ShineState extends State<_Shine> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // 0→60% attraversa, poi pausa.
          final t = (_c.value / .6).clamp(0.0, 1.0);
          return FractionallySizedBox(
            widthFactor: .34,
            alignment: Alignment(-2.2 + 4.4 * t, 0),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0x00FFFFFF),
                    Color(0x6BFFFFFF),
                    Color(0x00FFFFFF),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Chip/bottone secondario inclinato (NOTTE, RADAR ON, filtri).
class HeatChip extends StatelessWidget {
  const HeatChip({
    super.key,
    required this.label,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.height = 36,
  });

  final String label;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColor.onAccent : AppColor.ink;
    return HeatPanel(
      onTap: onTap,
      shape: const SlantBorder.all(8),
      color:
          selected ? AppColor.accent : AppColor.surface.withValues(alpha: .92),
      borderColor: selected ? null : AppColor.line,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: SizedBox(
        height: height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            Text(
              label.toUpperCase(),
              style: AppType.display(
                fontSize: 15,
                letterSpacing: 1.4,
                color: fg,
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 6), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Barra di progresso segmentata e inclinata (`skewX(-30deg)`).
/// [value] 0..1; con [segments] = 1 è una barra continua.
class SkewBar extends StatelessWidget {
  const SkewBar({
    super.key,
    required this.value,
    this.segments = 1,
    this.height = 5,
    this.gap = 3,
    this.color,
    this.track = AppColor.line,
  });

  final double value;
  final int segments;
  final double height;
  final double gap;
  final Color? color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColor.accent;
    final v = value.clamp(0.0, 1.0);
    return SizedBox(
      height: height,
      child: Transform(
        transform: Matrix4.skewX(-kHeatBarSkew),
        alignment: Alignment.center,
        child: segments <= 1
            ? Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: track)),
                  FractionallySizedBox(
                    widthFactor: v,
                    child: ColoredBox(color: c),
                  ),
                ],
              )
            : Row(
                children: [
                  for (var i = 0; i < segments; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    Expanded(
                      child: ColoredBox(
                        color: (i + 1) <= (v * segments + 1e-6) ? c : track,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Etichetta di sezione: `ULTIME GUIDE` … con eventuale testo a destra.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: AppType.label
                .copyWith(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        if (trailing != null)
          Text(trailing!, style: AppType.caption.copyWith(fontSize: 13)),
      ],
    );
  }
}

/// Titolo di schermata: Barlow 900 corsivo 50px, entra scivolando da sinistra.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key, this.color, this.fontSize = 50});

  final String text;
  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = Padding(
      // Spazio per l'inclinazione del corsivo.
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        text.toUpperCase(),
        style: AppType.screenTitle.copyWith(
          fontSize: fontSize,
          color: color,
          shadows: [
            Shadow(
              color: AppColor.accent.withValues(alpha: .25),
              blurRadius: 22,
            ),
          ],
        ),
      ),
    );
    if (_reduceMotion(context)) return t;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.title,
      curve: AppMotion.enterCurve,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(-24 * (1 - v), 0),
          child: child,
        ),
      ),
      child: t,
    );
  }
}

/// Accento graffiti (Sedgwick Ave Display) ruotato.
class GraffitiText extends StatelessWidget {
  const GraffitiText(
    this.text, {
    super.key,
    this.fontSize = 28,
    this.color,
    this.angle = -0.09, // ≈ −5°
  });

  final String text;
  final double fontSize;
  final Color? color;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Text(
        text,
        style: AppType.graffiti(fontSize: fontSize, color: color),
      ),
    );
  }
}

/// Sfondo standard delle schermate: griglia di punti + alone d'accento in
/// alto a destra. Niente strisce diagonali.
class HeatBackground extends StatelessWidget {
  const HeatBackground({super.key, required this.child, this.glow = true});

  final Widget child;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotGridPainter(glow ? AppColor.accent : null),
      child: child,
    );
  }
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter(this.glow);

  final Color? glow;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColor.base);
    if (glow != null) {
      final center = Offset(size.width * .88, 0);
      final rect = Rect.fromCenter(center: center, width: 520, height: 400);
      canvas.drawOval(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [glow!.withValues(alpha: .30), glow!.withValues(alpha: 0)],
            stops: const [0, .7],
          ).createShader(rect),
      );
    }
    final dot = Paint()..color = const Color(0x0FFFFFFF);
    for (double y = 8; y < size.height; y += 16) {
      for (double x = 8; x < size.width; x += 16) {
        canvas.drawCircle(Offset(x, y), 1, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.glow != glow;
}

/// Ingresso standard di schermata/item: `translateY(10px)` + fade, 380ms.
/// [index] sfasa gli item di una lista di 50ms ciascuno.
class HeatEnter extends StatelessWidget {
  const HeatEnter({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return child;
    final delay = AppMotion.stagger.inMilliseconds * index;
    final total = AppMotion.enter.inMilliseconds + delay;
    final start = delay / total;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (context, raw, c) {
        final v = AppMotion.enterCurve
            .transform(((raw - start) / (1 - start)).clamp(0.0, 1.0));
        return Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: c),
        );
      },
      child: child,
    );
  }
}
