import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../../rival/domain/entities/mascot.dart';
import '../providers/auth_provider.dart';

/// Stile e statistiche (0..5: precisione, aggressività, costanza) delle
/// mascotte, dal design HEAT (hrr-data.js). Solo presentazione: i
/// bonus/malus di gioco del prototipo non sono ancora implementati, quindi
/// qui non si promettono.
const _profiles = <String, (String, List<int>)>{
  'nitro': ('PRECISIONE', [4, 2, 5]),
  'r3x': ('AGGRESSIVITÀ', [2, 5, 2]),
  'volt': ('NOTTE', [3, 3, 4]),
  'spark': ('SPOTTING', [3, 2, 3]),
  'dust': ('COSTANZA', [3, 1, 5]),
};

const _statLabels = ['PRECISIONE', 'AGGRESSIVITÀ', 'COSTANZA'];

/// Onboarding "scegli il pilota" (HEAT, handoff §5 · PASSO 3 DI 3):
/// carosello delle cinque mascotte con hero, nome, stile, tre barre e la
/// CTA "CORRI CON {NOME}". Mostrata una volta dopo la registrazione (gate
/// nel router): nessuna navigazione esplicita al termine, il router
/// osserva myProfileProvider e ci porta via appena mascot_id è valorizzato.
class MascotOnboardingScreen extends ConsumerStatefulWidget {
  const MascotOnboardingScreen({super.key});

  @override
  ConsumerState<MascotOnboardingScreen> createState() =>
      _MascotOnboardingScreenState();
}

class _MascotOnboardingScreenState
    extends ConsumerState<MascotOnboardingScreen> {
  final _pages = PageController();
  int _index = 0;

  Mascot get _current => kMascotCatalog[_index];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    final n = kMascotCatalog.length;
    final target = (i % n + n) % n;
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) {
      _pages.jumpToPage(target);
    } else {
      _pages.animateToPage(target,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic);
    }
  }

  Future<void> _choose() async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return;
    await ref
        .read(authControllerProvider.notifier)
        .updateProfileSettings(userId: userId, mascotId: _current.id);
    if (!mounted) return;
    if (ref.read(authControllerProvider).hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('scelta non salvata. riprova.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).isLoading;
    final m = _current;
    final (style, stats) = _profiles[m.id] ?? ('', const [3, 3, 3]);

    return Scaffold(
      backgroundColor: AppColor.base,
      body: Stack(
        children: [
          // Alone nel colore della mascotte.
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -.28),
                  radius: .9,
                  colors: [
                    m.accentColor.withValues(alpha: .35),
                    AppColor.base.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('PASSO 3 DI 3 · SCEGLI IL PILOTA',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.display(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                italic: false,
                                letterSpacing: 2.4,
                                color: AppColor.inkMuted)),
                      ),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: (_index + 1).toString().padLeft(2, '0')),
                          TextSpan(
                              text:
                                  ' / ${kMascotCatalog.length.toString().padLeft(2, '0')}',
                              style: const TextStyle(color: AppColor.inkFaint)),
                        ]),
                        style: AppType.display(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColor.ink),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: kMascotCatalog.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(30, 10, 30, 0),
                      child: Image.asset(
                        'assets/mascots/${kMascotCatalog[i].id}_hero.png',
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomCenter,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: [
                      _ArrowButton(
                        icon: Icons.chevron_left_rounded,
                        label: 'pilota precedente',
                        onTap: () => _goTo(_index - 1),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            GraffitiText(m.name,
                                fontSize: 40,
                                color: m.accentColor,
                                angle: -.07),
                            const SizedBox(height: 4),
                            Text('STILE · $style',
                                style: AppType.display(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    italic: false,
                                    letterSpacing: 2.4,
                                    color: AppColor.inkMuted)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0; i < kMascotCatalog.length; i++)
                                  GestureDetector(
                                    onTap: () => _goTo(i),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 3, vertical: 6),
                                      child: Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.skewX(-.52),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          width: i == _index ? 22 : 10,
                                          height: 6,
                                          color: i == _index
                                              ? AppColor.ink
                                              : AppColor.line,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _ArrowButton(
                        icon: Icons.chevron_right_rounded,
                        label: 'pilota successivo',
                        onTap: () => _goTo(_index + 1),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                  child: Row(
                    children: [
                      for (var s = 0; s < 3; s++) ...[
                        if (s > 0) const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_statLabels[s],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.display(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      italic: false,
                                      letterSpacing: 1.4,
                                      color: AppColor.inkMuted)),
                              const SizedBox(height: 6),
                              SkewBar(
                                value: stats[s] / 5,
                                segments: 5,
                                gap: 3,
                                height: 7,
                                color: AppColor.ink,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.personalityTag.toLowerCase(),
                          style: AppType.text(
                              fontSize: 14, color: AppColor.ink, height: 1.4)),
                      const SizedBox(height: 2),
                      Text('"${m.tagline}"',
                          style: AppType.text(
                              fontSize: 14,
                              color: AppColor.inkMuted,
                              height: 1.4)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                  child: HeatButton(
                    label: loading ? 'UN ATTIMO…' : 'CORRI CON ${m.name}',
                    onPressed: loading ? null : _choose,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: HeatPanel(
        onTap: onTap,
        shape: const SlantBorder(left: 10, right: 10),
        color: AppColor.surface,
        padding: EdgeInsets.zero,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, size: 26, color: AppColor.ink),
        ),
      ),
    );
  }
}
