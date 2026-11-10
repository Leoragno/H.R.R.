import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/entities/app_user.dart';

/// Volto quadrato di un pilota: foto profilo se c'è, altrimenti il volto
/// della sua mascotte (assets/faces/{id}.png).
class PilotFace extends StatelessWidget {
  const PilotFace({super.key, required this.user, this.size = 48, this.ring});

  final AppUser user;
  final double size;

  /// Bordo da 2 px (es. "tu" nelle card sfida); null = nessuno.
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final url = user.avatarUrl;
    final fallback = Image.asset(
      'assets/faces/${user.mascotId ?? 'nitro'}.png',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColor.surfaceHigh,
        border: ring == null ? null : Border.all(color: ring!, width: 2),
      ),
      clipBehavior: Clip.hardEdge,
      child: url == null || url.isEmpty
          ? fallback
          : Image.network(url,
              fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
    );
  }
}

/// Riga in alto con la freccia indietro (torna alla home se non c'è
/// niente da chiudere) e un'azione opzionale a destra.
class BackRow extends StatelessWidget {
  const BackRow({super.key, this.trailing});
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'indietro',
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(AppRoutes.home),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColor.ink),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Rombo pieno (stato, punto non letto…).
class Diamond extends StatelessWidget {
  const Diamond({super.key, required this.color, this.size = 8});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: .785,
        child: SizedBox(
            width: size, height: size, child: ColoredBox(color: color)),
      );
}

/// Riquadro tratteggiato "niente da mostrare".
class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColor.deep,
        border: Border.all(color: AppColor.line),
      ),
      child: Text(text,
          textAlign: TextAlign.center,
          style: AppType.text(fontSize: 14, color: AppColor.inkMuted)),
    );
  }
}
