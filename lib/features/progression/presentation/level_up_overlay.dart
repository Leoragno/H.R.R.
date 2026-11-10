import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/heat/heat_widgets.dart';
import '../domain/progression.dart';
import 'progression_providers.dart';

/// Primo livello con un titolo diverso da quello di [level] (null se è
/// già l'ultimo titolo).
int? nextTitleLevel(int level) {
  final t = levelTitle(level);
  for (var l = level + 1; l <= 60; l++) {
    if (levelTitle(l) != t) return l;
  }
  return null;
}

/// Osserva il livello del profilo e, quando sale mentre l'app è aperta,
/// mostra l'overlay "LIVELLO SUPERIORE". Il primo valore (avvio, login)
/// non conta: solo i salti successivi.
class LevelUpWatcher extends ConsumerWidget {
  const LevelUpWatcher({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<LevelProgress?>(levelProgressProvider, (prev, next) {
      if (prev == null || next == null || next.level <= prev.level) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          showLevelUp(context, from: prev.level, to: next.level);
        }
      });
    });
    return child;
  }
}

Future<void> showLevelUp(BuildContext context,
    {required int from, required int to}) {
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'chiudi',
    barrierColor: const Color(0xD906050A),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) => LevelUpOverlay(from: from, to: to),
    transitionBuilder: (_, a, __, child) =>
        FadeTransition(opacity: a, child: child),
  );
}

class LevelUpOverlay extends StatelessWidget {
  const LevelUpOverlay({super.key, required this.from, required this.to});
  final int from;
  final int to;

  @override
  Widget build(BuildContext context) {
    final newTitle = levelTitle(to) != levelTitle(from);
    final next = nextTitleLevel(to);
    final reduce = MediaQuery.disableAnimationsOf(context);

    Widget number = Text('$to',
        style: AppType.display(fontSize: 150, height: .9, letterSpacing: -2));
    if (!reduce) {
      number = number
          .animate()
          .scale(
              begin: const Offset(.4, .4),
              duration: 550.ms,
              curve: Curves.easeOutBack)
          .fadeIn(duration: 200.ms);
    }

    return SafeArea(
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text('LIVELLO SUPERIORE',
                  textAlign: TextAlign.center,
                  style: AppType.label.copyWith(
                      fontSize: 14,
                      letterSpacing: 3,
                      color: AppColor.inkMuted)),
              Center(child: number),
              Center(
                child: GraffitiText(levelTitle(to).toLowerCase(),
                    fontSize: 44, angle: -.07),
              ),
              const SizedBox(height: 14),
              Text(
                newTitle
                    ? 'nuovo titolo sbloccato.'
                    : next != null
                        ? 'a LV $next diventi ${levelTitle(next).toLowerCase()}.'
                        : 'sei al titolo più alto.',
                textAlign: TextAlign.center,
                style: AppType.text(
                    fontSize: 15, color: AppColor.inkMuted, height: 1.4),
              ),
              const Spacer(),
              HeatButton(
                label: 'AVANTI',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}
