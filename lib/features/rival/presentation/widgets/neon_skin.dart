import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Skin neon (pass di guida / legame LV5): alone del colore della mascotte
/// dietro l'arte, come il `drop-shadow` doppio del prototipo. Spento =
/// restituisce [child] così com'è.
class NeonSkin extends StatelessWidget {
  const NeonSkin({
    super.key,
    required this.on,
    required this.color,
    required this.child,
  });

  final bool on;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!on) return child;
    Widget halo(double sigma, double alpha) => ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
                color.withValues(alpha: alpha), BlendMode.srcIn),
            child: child,
          ),
        );
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: halo(11, .8)),
        Positioned.fill(child: halo(5, .9)),
        child,
      ],
    );
  }
}
