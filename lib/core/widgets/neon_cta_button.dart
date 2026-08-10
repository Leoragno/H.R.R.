import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// CTA primaria del design "Guida": pill col gradiente tri-stop
/// ciano→blu→magenta, testo scuro in maiuscolo e una sheen animata che
/// scorre in loop (`om-sheen` nel design originale).
class NeonCtaButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double minHeight;
  final double fontSize;

  const NeonCtaButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.minHeight = 58,
    this.fontSize = 18,
  });

  @override
  State<NeonCtaButton> createState() => _NeonCtaButtonState();
}

class _NeonCtaButtonState extends State<NeonCtaButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;

    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            child: Ink(
              height: widget.minHeight,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1, -0.4),
                  end: Alignment(1, 0.4),
                  colors: AppColors.guidaGradientCta,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x662F6BFF),
                    blurRadius: 30,
                    offset: Offset(0, 12),
                  ),
                  BoxShadow(
                    color: Color(0x52FF2FD0),
                    blurRadius: 26,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return Positioned.fill(
                        child: FractionallySizedBox(
                          alignment: Alignment(
                            -1 + 4 * _controller.value,
                            0,
                          ),
                          widthFactor: 0.34,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.34),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon,
                              color: AppColors.guidaOnAccent, size: 22),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          widget.label.toUpperCase(),
                          style: AppTheme.archivo(
                            fontWeight: FontWeight.w800,
                            fontSize: widget.fontSize,
                            color: AppColors.guidaOnAccent,
                            letterSpacing: widget.fontSize * 0.05,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
