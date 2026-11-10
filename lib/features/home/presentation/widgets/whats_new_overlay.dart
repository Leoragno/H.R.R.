import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../rival/presentation/providers/active_mascot_provider.dart';

const _seenKey = 'heat_whats_new_seen';

/// Testi delle 7 slide "novità" (handoff, Update · tutorial).
const whatsNewSlides = <(String, String, String)>[
  (
    'HRR 2.0',
    'LA CITTÀ È CAMBIATA',
    'nuovo look, nuove sfide, nuovi modi di guadagnare XP. 30 secondi e sei pronto a ripartire.'
  ),
  (
    'GUIDA IN CORSO',
    'TUTTO SOTTO CONTROLLO',
    'tachimetro grande o mappa live con un tocco. parla con gli amici in radio, segnala velox e ricevi avvisi mentre guidi.'
  ),
  (
    'HEAT',
    'LA NOTTE PAGA DOPPIO',
    'ogni guida notturna alza il tuo HEAT, fino a 5 fiamme. più HEAT hai, più XP prendi. di giorno si raffredda.'
  ),
  (
    'CHE PILOTA SEI',
    'GUIDI COME UNA LEGGENDA',
    'ogni guida ti abbina a un pilota famoso. quello che esce più spesso negli ultimi 10 viaggi diventa il tuo. collezionali tutti.'
  ),
  (
    'SFIDE 1 VS 1',
    'SFIDA UN AMICO',
    'scegli amico, metrica e posta. avete 24 ore o 3 giorni: ogni guida aggiorna il tuo punteggio. chi fa meglio prende gli XP.'
  ),
  (
    'OGNI LUNEDÌ',
    'LA TUA SETTIMANA',
    'km, pilota della settimana, esagoni presi e chi ti ha superato. scorrilo come una storia e condividilo.'
  ),
  (
    'TUTTO PRONTO',
    'IN STRADA',
    'puoi rivedere queste novità quando vuoi da impostazioni. ora vai a prenderti la città.'
  ),
];

/// Mostra le novità la prima volta che si apre la Home dopo l'aggiornamento.
Future<void> maybeShowWhatsNew(BuildContext context) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seenKey) ?? false) return;
    await prefs.setBool(_seenKey, true);
  } catch (_) {
    return;
  }
  if (context.mounted) await showWhatsNew(context);
}

/// Apre le novità (anche da Impostazioni › Aiuto).
Future<void> showWhatsNew(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => const WhatsNewOverlay(),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
    ),
  );
}

class WhatsNewOverlay extends ConsumerStatefulWidget {
  const WhatsNewOverlay({super.key});

  @override
  ConsumerState<WhatsNewOverlay> createState() => _WhatsNewOverlayState();
}

class _WhatsNewOverlayState extends ConsumerState<WhatsNewOverlay> {
  int _i = 0;

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final n = whatsNewSlides.length;
    final last = _i == n - 1;
    final (kicker, title0, text) = whatsNewSlides[_i];
    final username =
        ref.watch(myProfileProvider).valueOrNull?.username.toUpperCase();
    final title = last && username != null ? '$title0, $username' : title0;
    final pad = MediaQuery.paddingOf(context);

    return Material(
      color: const Color(0xF706050A),
      child: HeatBackground(
        child: Padding(
          padding: EdgeInsets.fromLTRB(22, pad.top + 14, 22, pad.bottom + 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('NOVITÀ · ${_i + 1} / $n',
                        style: AppType.label.copyWith(
                            fontSize: 13,
                            letterSpacing: 2.4,
                            color: AppColor.inkMuted)),
                  ),
                  if (!last)
                    TextButton(
                      onPressed: _close,
                      child: Text('salta',
                          style: AppType.text(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColor.inkMuted)),
                    ),
                ],
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: (d) {
                    final v = d.primaryVelocity ?? 0;
                    if (v < -200 && !last) setState(() => _i++);
                    if (v > 200 && _i > 0) setState(() => _i--);
                  },
                  child: Center(
                    child: KeyedSubtree(
                      key: ValueKey(_i),
                      child: _Illustration(index: _i)
                          .animate()
                          .fadeIn(duration: 250.ms)
                          .scale(
                              begin: const Offset(.9, .9),
                              duration: 450.ms,
                              curve: Curves.easeOutBack),
                    ),
                  ),
                ),
              ),
              Text(kicker,
                  style: AppType.label.copyWith(
                      fontSize: 14,
                      letterSpacing: 2.4,
                      color: AppColor.inkMuted)),
              const SizedBox(height: 4),
              Text(title,
                      style: AppType.display(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          height: .95))
                  .animate(key: ValueKey('t$_i'))
                  .fadeIn(duration: 300.ms)
                  .slideX(begin: -.06, duration: 400.ms),
              const SizedBox(height: 10),
              Text(text,
                  style: AppType.text(
                      fontSize: 15, color: AppColor.inkMuted, height: 1.45)),
              const SizedBox(height: 18),
              Row(
                children: [
                  for (var k = 0; k < n; k++)
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: Transform(
                        transform: Matrix4.skewX(-.52),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: k == _i ? 22 : 10,
                          height: 6,
                          color: k == _i ? AppColor.ink : AppColor.line,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_i > 0) ...[
                    SizedBox(
                      width: 64,
                      child: HeatGhostButton(
                        icon: Icons.chevron_left_rounded,
                        onPressed: () => setState(() => _i--),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: HeatButton(
                      label: last
                          ? 'IN STRADA'
                          : _i == 0
                              ? 'SCOPRI'
                              : 'AVANTI',
                      onPressed: last ? _close : () => setState(() => _i++),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Disegno di ogni slide, tutto neutro: l'unico accento della schermata è
/// il pulsante AVANTI (DESIGN.md, un solo elemento acceso).
class _Illustration extends ConsumerWidget {
  const _Illustration({required this.index});
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mascot = ref.watch(activeMascotProvider);
    const a = AppColor.ink;
    Widget hero() => Image.asset(
          'assets/mascots/${mascot.id}_hero.png',
          height: 240,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(height: 240),
        );
    Widget chip(IconData icon, String label) => Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const ShapeDecoration(
            color: AppColor.surface,
            shape: SlantBorder.all(8, side: BorderSide(color: AppColor.line)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColor.ink),
              const SizedBox(width: 6),
              Text(label,
                  style: AppType.display(
                      fontSize: 15, letterSpacing: .8, italic: false)),
            ],
          ),
        );

    switch (index) {
      case 0:
        return Stack(
          clipBehavior: Clip.none,
          children: [
            hero(),
            Positioned(
              right: -6,
              top: 6,
              child: Transform.rotate(
                angle: .1,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: const ShapeDecoration(
                    color: a,
                    shape: SlantBorder.all(6),
                  ),
                  child: Text('NUOVO',
                      style: AppType.display(
                          fontSize: 16,
                          letterSpacing: 1.4,
                          color: AppColor.deep)),
                ),
              ),
            ),
          ],
        );
      case 1:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: .44,
                      strokeWidth: 14,
                      color: a,
                      backgroundColor: AppColor.surfaceHigh,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('87',
                          style: AppType.display(fontSize: 64, height: 1)),
                      Text('KM/H',
                          style: AppType.label.copyWith(
                              fontSize: 14,
                              letterSpacing: 3,
                              color: AppColor.inkMuted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                chip(Icons.map_rounded, 'TACHIMETRO ⇄ MAPPA'),
                chip(Icons.mic_rounded, 'RADIO AMICI'),
                chip(Icons.videocam_rounded, 'AVVISI VELOX'),
              ],
            ),
          ],
        );
      case 2:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var f = 0; f < 5; f++)
                  Icon(Icons.local_fire_department_rounded,
                          size: 50, color: f < 4 ? AppColor.inkMuted : a)
                      .animate(delay: (80 * f).ms)
                      .fadeIn(duration: 250.ms),
              ],
            ),
            const SizedBox(height: 8),
            Text('×2 XP', style: AppType.display(fontSize: 60, height: 1)),
            const SizedBox(height: 4),
            Text('A HEAT 5 · SOLO DI NOTTE',
                style: AppType.label.copyWith(
                    fontSize: 14, letterSpacing: 2, color: AppColor.inkMuted)),
          ],
        );
      case 3:
        Widget badge(String t, double w, bool on) => SizedBox(
              width: w,
              height: w * 1.15,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: AppColor.deep,
                  shape: _HexShape(on ? a : AppColor.line),
                ),
                child: Center(
                  child: Text(t,
                      style: AppType.display(
                          fontSize: w * .36,
                          color: on ? a : AppColor.inkMuted)),
                ),
              ),
            );
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Opacity(opacity: .55, child: badge('DT', 58, false)),
            const SizedBox(width: 14),
            badge('FM', 96, true),
            const SizedBox(width: 14),
            Opacity(opacity: .55, child: badge('HL', 58, false)),
          ],
        );
      case 4:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/faces/${mascot.id}.png',
                width: 90,
                height: 90,
                errorBuilder: (_, __, ___) => const SizedBox(width: 90)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('VS', style: AppType.display(fontSize: 46, color: a)),
            ),
            Container(
              width: 90,
              height: 90,
              color: AppColor.surface,
              alignment: Alignment.center,
              child: const Icon(Icons.person_rounded,
                  size: 54, color: AppColor.inkMuted),
            ),
          ],
        );
      case 5:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GraffitiText('la tua settimana', fontSize: 46, angle: -.08),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var k = 0; k < 5; k++)
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: k < 2 ? AppColor.ink : AppColor.line,
                  ),
              ],
            ),
          ],
        );
      default:
        return hero();
    }
  }
}

/// Esagono a punta in alto con bordo (emblema pilota).
class _HexShape extends ShapeBorder {
  const _HexShape(this.color);
  final Color color;

  Path _path(Rect r) => Path()
    ..moveTo(r.center.dx, r.top)
    ..lineTo(r.right, r.top + r.height * .16)
    ..lineTo(r.right, r.top + r.height * .72)
    ..lineTo(r.center.dx, r.bottom)
    ..lineTo(r.left, r.top + r.height * .72)
    ..lineTo(r.left, r.top + r.height * .16)
    ..close();

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect);
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    canvas.drawPath(
        _path(rect.deflate(.75)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color);
  }

  @override
  ShapeBorder scale(double t) => this;
}
