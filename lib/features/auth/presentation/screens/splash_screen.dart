import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

const _bg = Color(0xFF050407);

/// INTRO (HEAT, handoff §1): notte di città — sole a strisce, skyline con
/// finestre accese, orizzonte al neon con scie di fari, logo HRR che
/// "sbatte", le cinque mascotte che salgono, "LA CITTÀ È LA TUA PISTA ·
/// TOCCA PER PARTIRE".
///
/// La prima volta l'intro resta fino al tocco (massimo ~9 s); dalle
/// aperture successive passa da sola appena il logo è atterrato. Un tocco
/// salta sempre. Intanto si controlla la sessione: si va a Home se loggati,
/// altrimenti a Login.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  static const _introSeenKey = 'heat_intro_seen';
  static const _total = 5.4; // secondi della timeline d'ingresso

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_total * 1000).round()),
  )..forward();

  /// Loop per pulsazioni, scie di fari e luccichio del logo.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  Future<Object?>? _user;
  Timer? _auto;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _user = ref.read(authRepositoryProvider).currentUser();
    _scheduleAuto();
  }

  Future<void> _scheduleAuto() async {
    var seen = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      seen = prefs.getBool(_introSeenKey) ?? false;
      if (!seen) await prefs.setBool(_introSeenKey, true);
    } catch (_) {}
    if (!mounted) return;
    _auto = Timer(Duration(milliseconds: seen ? 2600 : 9000), _go);
  }

  Future<void> _go() async {
    if (_leaving) return;
    _leaving = true;
    _auto?.cancel();
    final user = await _user;
    if (!mounted) return;
    context.go(user != null ? AppRoutes.home : AppRoutes.login);
  }

  @override
  void dispose() {
    _auto?.cancel();
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  /// Avanzamento 0..1 di un pezzo che parte a [start] s e dura [dur] s.
  double _t(double start, double dur, [Curve curve = Curves.easeOut]) {
    final s = _intro.value * _total;
    return curve.transform(((s - start) / dur).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColor.accent;
    return Scaffold(
      backgroundColor: _bg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _go,
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: 390,
              height: 844,
              child: AnimatedBuilder(
                animation: Listenable.merge([_intro, _loop]),
                builder: (context, _) => _scene(accent),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _scene(Color accent) {
    final loop = _loop.value;
    final glow = _t(.4, 2);
    final sun = _t(.2, 1.6, const Cubic(.2, .8, .2, 1));
    final city = _t(.6, 1.6);
    final horizon = _t(1.5, 1);
    final slam = _t(1.9, .7, const Cubic(.2, 1, .3, 1));
    final tag = _t(2.4, .5, const Cubic(.2, 1.2, .3, 1));
    final sub = _t(2.7, .6);
    final claim = _t(4, .6);
    final line = _t(4.5, .6, const Cubic(.7, 0, .2, 1));
    final cta = _t(4.6, .5);
    final pulse = .55 + .45 * (0.5 + 0.5 * math.cos(loop * 2 * math.pi));

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        const Positioned.fill(child: ColoredBox(color: _bg)),
        // Alone generale.
        Positioned.fill(
          child: Opacity(
            opacity: glow,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, .2),
                  radius: .75,
                  colors: [
                    accent.withValues(alpha: .16),
                    _bg.withValues(alpha: 0)
                  ],
                ),
              ),
            ),
          ),
        ),
        // Sole a strisce.
        Positioned(
          left: 55,
          top: 180,
          width: 280,
          height: 280,
          child: Opacity(
            opacity: .55 * sun,
            child: Transform.translate(
              offset: Offset(0, 60 * (1 - sun)),
              child: CustomPaint(painter: _SunPainter(accent)),
            ),
          ),
        ),
        // Katakana a sinistra, Tokyo a destra.
        Positioned(
          left: 18,
          top: 110,
          child: Opacity(
            opacity: _t(1, 1.2),
            child: Column(
              children: [
                for (final (i, ch) in 'ハイウェイ・レーサーズ'.characters.indexed)
                  Opacity(
                    opacity: _t(1.1 + i * .12, .01),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(ch,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: accent.withValues(alpha: .55))),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 20,
          top: 118,
          child: Opacity(
            opacity: _t(1.2, 1.2) * .9,
            child: Column(
              children: [
                for (final ch in '東京'.characters)
                  Text(ch,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xBFF4F1FA))),
                const SizedBox(height: 6),
                RotatedBox(
                  quarterTurns: 1,
                  child: Text('35.68°N',
                      style: AppType.display(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          italic: false,
                          letterSpacing: 3,
                          color: AppColor.inkFaint)),
                ),
              ],
            ),
          ),
        ),
        // Skyline (due piani) che sale.
        Positioned(
          left: 0,
          right: 0,
          bottom: 300,
          height: 170,
          child: Opacity(
            opacity: city,
            child: Transform.translate(
              offset: Offset(0, 40 * (1 - city)),
              child: CustomPaint(painter: _SkylinePainter(accent, loop)),
            ),
          ),
        ),
        // Riflesso sotto l'orizzonte.
        Positioned(
          left: 0,
          right: 0,
          bottom: 150,
          height: 150,
          child: Opacity(
            opacity: horizon,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accent.withValues(alpha: .2),
                    accent.withValues(alpha: .02)
                  ],
                ),
              ),
            ),
          ),
        ),
        // Linea dell'orizzonte al neon + scie di fari.
        Positioned(
          left: 0,
          right: 0,
          bottom: 299,
          height: 2,
          child: Opacity(
            opacity: horizon,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  accent.withValues(alpha: 0),
                  accent,
                  Color.lerp(accent, Colors.white, .65)!,
                  accent,
                  accent.withValues(alpha: 0),
                ]),
                boxShadow: [
                  BoxShadow(color: accent, blurRadius: 18),
                  BoxShadow(
                      color: accent.withValues(alpha: .5), blurRadius: 40),
                ],
              ),
            ),
          ),
        ),
        if (_intro.value * _total > 3.4) ...[
          _trail(loop, 70, const Color(0xFFFFF3F6), leftToRight: true),
          _trail((loop + .45) % 1, 56, accent, leftToRight: false),
        ],
        // Logo.
        Positioned(
          left: 0,
          right: 0,
          top: 200,
          child: Column(
            children: [
              Opacity(
                opacity: slam,
                child: Transform.scale(
                  scale: 2.6 - 1.6 * slam,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.skewX(-.24 * (1 - slam)),
                    child: Text(
                      'HRR',
                      style: AppType.display(
                        fontSize: 124,
                        fontWeight: FontWeight.w900,
                        height: .85,
                        letterSpacing: 2,
                        color: AppColor.ink,
                      ).copyWith(shadows: [
                        Shadow(
                            color: accent.withValues(alpha: .45),
                            blurRadius: 30),
                      ]),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -6),
                child: Opacity(
                  opacity: tag,
                  child: Transform.scale(
                    scale: .6 + .4 * tag,
                    child: Transform.rotate(
                      angle: -.105,
                      child: Text(
                        'heat racers',
                        style: AppType.graffiti(fontSize: 46, color: accent)
                            .copyWith(height: 1.1, shadows: [
                          Shadow(
                              color: accent.withValues(alpha: .6),
                              blurRadius: 18),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Opacity(
                opacity: sub,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - sub)),
                  child: Text('ストリート · ドリフト',
                      style: AppType.display(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          italic: false,
                          letterSpacing: 7,
                          color: AppColor.inkMuted)),
                ),
              ),
            ],
          ),
        ),
        // Le cinque mascotte.
        for (final m in _lineup) _mascot(m),
        // Ombra a terra e base nera.
        const Positioned(
          left: 0,
          right: 0,
          bottom: 150,
          height: 40,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00050407), _bg],
              ),
            ),
          ),
        ),
        const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 151,
            child: ColoredBox(color: _bg)),
        // Claim + tocca per partire.
        Positioned(
          left: 0,
          right: 0,
          bottom: 56,
          child: Column(
            children: [
              Opacity(
                opacity: claim,
                child: Transform.translate(
                  offset: Offset(0, 14 * (1 - claim)),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('LA CITTÀ È LA TUA PISTA',
                            style: AppType.display(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                                color: AppColor.ink)),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: line,
                            heightFactor: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: accent,
                                boxShadow: [
                                  BoxShadow(color: accent, blurRadius: 10)
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Opacity(
                opacity: cta * (_intro.isCompleted ? pulse : 1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _diamond(accent),
                    const SizedBox(width: 10),
                    Text('TOCCA PER PARTIRE',
                        style: AppType.display(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            italic: false,
                            letterSpacing: 4,
                            color: accent)),
                    const SizedBox(width: 10),
                    _diamond(accent),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Scanline.
        const Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _ScanPainter())),
        ),
      ],
    );
  }

  Widget _diamond(Color c) => Transform.rotate(
        angle: math.pi / 4,
        child: Container(width: 7, height: 7, color: c),
      );

  Widget _trail(double p, double w, Color c, {required bool leftToRight}) {
    final x = -80 + (390 + 160) * Curves.easeInOut.transform(p);
    return Positioned(
      left: leftToRight ? x : null,
      right: leftToRight ? null : x,
      bottom: 300 + (leftToRight ? 1 : 3),
      width: w,
      height: 2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: leftToRight ? Alignment.centerLeft : Alignment.centerRight,
            end: leftToRight ? Alignment.centerRight : Alignment.centerLeft,
            colors: [c.withValues(alpha: 0), c],
          ),
          boxShadow: [BoxShadow(color: c, blurRadius: 8)],
        ),
      ),
    );
  }

  Widget _mascot(_LineupSlot m) {
    final rise = _t(m.delay, .8, const Cubic(.2, .9, .2, 1));
    final lit = _t(m.delay + .35, .6);
    return Positioned(
      left: m.left,
      bottom: m.bottom,
      width: m.width,
      child: Opacity(
        opacity: rise,
        child: Transform.translate(
          offset: Offset(0, 80 * (1 - rise)),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 12,
                right: 12,
                bottom: 4,
                height: 22,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: ColoredBox(color: m.color.withValues(alpha: .6)),
                ),
              ),
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: .7 * (1 - lit)),
                  BlendMode.srcATop,
                ),
                child: Image.asset(
                  'assets/mascots/${m.id}_lineup.png',
                  width: m.width,
                  fit: BoxFit.fitWidth,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineupSlot {
  const _LineupSlot(
      this.id, this.color, this.left, this.bottom, this.width, this.delay);
  final String id;
  final Color color;
  final double left;
  final double bottom;
  final double width;
  final double delay;
}

const _lineup = [
  _LineupSlot('nitro', Color(0xFF3B7BFF), -9, 150, 96, 3.28),
  _LineupSlot('dust', Color(0xFFFFB020), 303, 150, 96, 3.28),
  _LineupSlot('r3x', Color(0xFFFF3B5C), 65, 146, 104, 3.14),
  _LineupSlot('spark', Color(0xFFFF2E88), 221, 146, 104, 3.14),
  _LineupSlot('volt', Color(0xFF8B5CF6), 135, 142, 120, 3.0),
];

class _SunPainter extends CustomPainter {
  const _SunPainter(this.accent);
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.saveLayer(rect, Paint());
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -.2),
          colors: [
            Color.lerp(accent, Colors.white, .15)!,
            Color.lerp(accent, Colors.black, .4)!,
          ],
          stops: const [0, .75],
        ).createShader(rect),
    );
    // Strisce orizzontali nella metà bassa, sempre più spesse.
    final cut = Paint()..blendMode = BlendMode.dstOut;
    for (var y = size.height * .5; y < size.height; y += 20) {
      final k = (y - size.height * .5) / (size.height * .5);
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 2 + 5 * k), cut);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SunPainter old) => old.accent != accent;
}

class _SkylinePainter extends CustomPainter {
  _SkylinePainter(this.accent, this.loop);
  final Color accent;
  final double loop;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    // Piano lontano.
    final far = Paint()..color = const Color(0xFF1C1222);
    var x = -4.0;
    while (x < size.width) {
      final w = 16 + rnd.nextDouble() * 16;
      final h = 40 + rnd.nextDouble() * 90;
      canvas.drawRect(Rect.fromLTWH(x, size.height - h - 40 + 40, w, h), far);
      x += w;
    }
    // Piano vicino con finestre.
    final near = Paint()..color = const Color(0xFF0C0A10);
    final edge = Paint()..color = accent.withValues(alpha: .22);
    final win = Paint()..color = const Color(0xFFFFBE8C).withValues(alpha: .5);
    x = -2;
    var i = 0;
    while (x < size.width) {
      final w = 30 + rnd.nextDouble() * 30;
      final h = 30 + rnd.nextDouble() * 110;
      final top = size.height - h;
      canvas.drawRect(Rect.fromLTWH(x, top, w, h), near);
      canvas.drawRect(Rect.fromLTWH(x, top, w, 1), edge);
      for (var wy = top + 8; wy < size.height - 4; wy += 8) {
        for (var wx = x + 4; wx < x + w - 6; wx += 7) {
          final on = rnd.nextDouble();
          // Qualche finestra "respira" col loop.
          final flicker = on > .97 && (loop + wx / 400) % 1 > .5;
          if (on > .78 && !flicker) {
            canvas.drawRect(Rect.fromLTWH(wx, wy, 3, 4), win);
          }
        }
      }
      // Insegna al neon su qualche palazzo.
      if (i % 4 == 1 && h > 80) {
        canvas.drawRect(
          Rect.fromLTWH(x + w / 2 - 2, top + 12, 4, 26),
          Paint()
            ..color = accent.withValues(alpha: .85)
            ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
        );
      }
      x += w;
      i++;
    }
  }

  @override
  bool shouldRepaint(_SkylinePainter old) =>
      old.accent != accent || (old.loop * 4).floor() != (loop * 4).floor();
}

class _ScanPainter extends CustomPainter {
  const _ScanPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x05FFFFFF);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(_ScanPainter old) => false;
}
