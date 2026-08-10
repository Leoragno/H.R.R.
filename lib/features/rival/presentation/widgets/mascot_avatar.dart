import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/deterministic_pick.dart';
import '../../domain/entities/mascot.dart';

/// Ritratto/posa della mascotte. Ruota deterministicamente (stessa scelta
/// per tutto il giorno, niente flicker tra rebuild) tra il ritratto hero e
/// le 3 pose alternative — così "ogni giorno cambia posa" senza dover
/// mappare un asset specifico per ciascun mood. Se il file manca
/// (mascotte futura senza asset pronti), `errorBuilder` mostra un badge
/// placeholder col colore della mascotte invece di rompere il layout.
class MascotAvatar extends StatelessWidget {
  final Mascot mascot;
  final double size;

  const MascotAvatar({super.key, required this.mascot, this.size = 64});

  String get _assetPath {
    final today = DateTime.now();
    final daySeed = '${today.year}-${today.month}-${today.day}';
    final variants = [
      'assets/mascots/${mascot.id}_hero.png',
      'assets/poses/${mascot.id}_pose_1.png',
      'assets/poses/${mascot.id}_pose_2.png',
      'assets/poses/${mascot.id}_pose_3.png',
    ];
    return pickDeterministic(daySeed, mascot.id, variants);
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Image.asset(
      _assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _PlaceholderBadge(mascot: mascot, size: size),
    );
    if (!mascot.hasCrown) return avatar;
    // R3X e DUST nel materiale originale hanno una corona — badge in alto
    // a destra, dimensionato in proporzione all'avatar.
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            top: -size * 0.08,
            right: -size * 0.08,
            child: Text('👑', style: TextStyle(fontSize: size * 0.32)),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderBadge extends StatelessWidget {
  final Mascot mascot;
  final double size;

  const _PlaceholderBadge({required this.mascot, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: mascot.accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: mascot.accentColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: mascot.accentColor.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        mascot.name.substring(0, 1),
        style: AppTheme.orbitron(
          fontWeight: FontWeight.w900,
          fontSize: size * 0.4,
          color: mascot.accentColor,
        ),
      ),
    );
  }
}
