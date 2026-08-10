import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/rival_popup.dart';
import '../providers/rival_controller_provider.dart';
import 'mascot_avatar.dart';

/// Overlay globale del Rival — stessa forma di NotificationToastOverlay
/// (stack sopra `child`, ascolto di un provider "impulso" via `ref.listen`)
/// ma posizionato in alto a destra per non sovrapporsi al toast notifiche
/// (in basso), e con un'animazione di ingresso vera (flutter_animate) per
/// realizzare lo "spunta dallo schermo" richiesto.
class RivalOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const RivalOverlay({super.key, required this.child});

  @override
  ConsumerState<RivalOverlay> createState() => _RivalOverlayState();
}

class _RivalOverlayState extends ConsumerState<RivalOverlay> {
  RivalPopup? _visible;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onArrival(RivalPopup popup) {
    _hideTimer?.cancel();
    setState(() => _visible = popup);
    final autoDismiss = popup.mood == RivalMood.greeting
        ? const Duration(milliseconds: 2500)
        : const Duration(milliseconds: 4500);
    _hideTimer = Timer(autoDismiss, () {
      if (mounted) setState(() => _visible = null);
    });
  }

  void _dismiss() {
    _hideTimer?.cancel();
    setState(() => _visible = null);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RivalPopup?>(rivalControllerProvider, (previous, next) {
      if (next != null) _onArrival(next);
    });

    final visible = _visible;
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 12,
          right: 12,
          child: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: visible == null
                  ? const SizedBox.shrink(key: ValueKey('rival-empty'))
                  : _RivalCard(
                      key: ValueKey(visible.id),
                      popup: visible,
                      onTap: _dismiss,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RivalCard extends StatelessWidget {
  final RivalPopup popup;
  final VoidCallback onTap;

  const _RivalCard({super.key, required this.popup, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = popup.mascot.accentColor;

    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xF00A0E1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MascotAvatar(mascot: popup.mascot, size: 48),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      popup.mascot.name,
                      style: AppTheme.orbitron(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      popup.phrase,
                      style: AppTheme.archivo(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return card
        .animate()
        .fadeIn(duration: 250.ms)
        .slideX(
            begin: 0.35,
            end: 0,
            curve: Curves.easeOutBack,
            duration: 380.ms)
        .scale(
            begin: const Offset(0.85, 0.85),
            end: const Offset(1, 1),
            duration: 380.ms);
  }
}
