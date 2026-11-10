import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../missions/presentation/providers/economy_providers.dart';
import '../../../pilots/presentation/widgets/pilot_emblem.dart';
import '../../../progression/domain/progression.dart';
import '../../../rival/domain/entities/mascot.dart';
import '../../../rival/presentation/providers/active_mascot_provider.dart';
import '../../domain/driver_archetype.dart';
import '../../domain/entities/trip.dart';
import '../providers/trip_live_provider.dart';
import '../providers/trip_provider.dart';
import '../widgets/route_preview_painter.dart';
import '../widgets/speed_distribution_bar.dart';
import '../widgets/trip_rank_card.dart';

/// Risultato di fine viaggio (handoff HEAT, schermata 8): banda FLOW con
/// contatore e grado graffiti, tracciato, commento della mascotte, "OGGI
/// HAI GUIDATO COME" con affinità, ricompense. L'unico elemento acceso è
/// la banda FLOW; tutto il resto resta su superficie.
///
/// Il tracciato non evidenzia i tratti di frenata: le frenate sono contate
/// ma non hanno una posizione registrata, e inventarla sarebbe falso.
class TripSummaryScreen extends ConsumerWidget {
  const TripSummaryScreen({super.key});

  void _continue(BuildContext context, WidgetRef ref) {
    ref.invalidate(myProfileProvider);
    ref.invalidate(recentTripsProvider);
    context.go(AppRoutes.home);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String tripId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColor.surfaceHigh,
        title: const Text('Eliminare il viaggio?'),
        content: const Text(
            'Il viaggio verrà rimosso dal tuo storico. XP e REP già assegnati restano.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Elimina', style: TextStyle(color: AppColor.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(tripRepositoryProvider).discardTrip(tripId);
    if (!context.mounted) return;
    ref.invalidate(recentTripsProvider);
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(lastTripSummaryControllerProvider);
    if (summary == null) {
      // Nessun riepilogo in sospeso (es. refresh diretto su questa route).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.home);
      });
      return const Scaffold(
        backgroundColor: AppColor.void_,
        body: SizedBox.shrink(),
      );
    }
    final trip = summary.trip;
    final motion = summary.motionStats;
    final mascot = ref.watch(activeMascotProvider);

    // Storico SENZA questo viaggio (la lista recente potrebbe già
    // contenerlo dopo il salvataggio).
    final previous = [
      for (final t
          in ref.watch(recentTripsProvider).valueOrNull ?? const <Trip>[])
        if (t.id != trip.id) t,
    ];
    final prevScores = [
      for (final t in previous)
        if (t.drivingScore != null) t.drivingScore!,
    ];
    final avgFlow = prevScores.isEmpty
        ? null
        : prevScores.reduce((a, b) => a + b) / prevScores.length;

    final match = matchDriverArchetype(DrivingStyleInput(
      distanceKm: trip.distanceKm,
      durationSeconds: trip.durationSeconds,
      avgSpeedKmh: trip.avgSpeedKmh,
      drivingScore: trip.drivingScore,
      maxAccelerationMs2: motion.maxAccelerationMs2,
      zeroToHundredSeconds: motion.zeroToHundredSeconds,
      peakGForce: motion.peakGForce,
      maxCorneringSpeedKmh: motion.maxCorneringSpeedKmh,
      turns: motion.turnsLeft + motion.turnsRight,
      laneChanges: motion.laneChanges,
      brakingEvents: motion.brakingEvents,
      totalStops: motion.totalStops,
      stoppedSeconds: motion.stoppedTime.inSeconds,
      elevationGainM: motion.elevationGainM,
    ));
    final prevArchetypes = archetypesOf(previous);
    final before = buildPilotHistory(prevArchetypes);
    final after = buildPilotHistory(
        [if (match != null) match.archetype, ...prevArchetypes]);
    final newPilot =
        match != null && after.main != null && after.main != before.main;

    final top = MediaQuery.paddingOf(context).top;
    var i = 0;

    return Scaffold(
      backgroundColor: AppColor.base,
      body: HeatBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(0, top + 4, 0, 0),
          children: [
            _Header(trip: trip, onClose: () => _continue(context, ref)),
            const SizedBox(height: 4),
            _FlowBand(score: trip.drivingScore, average: avgFlow),
            HeatEnter(
              index: i++,
              child: _RouteBox(
                points: summary.routePoints,
                brakePoints: summary.brakePoints,
                brakes: motion.brakingEvents,
              ),
            ),
            if (trip.drivingScore != null)
              HeatEnter(
                index: i++,
                child: _MascotComment(
                    mascot: mascot,
                    grade: flowGrade(trip.drivingScore!),
                    celebration: ref.watch(cosmeticsProvider).celebration),
              ),
            if (match != null)
              HeatEnter(
                index: i++,
                child: _PilotCard(
                  trip: trip,
                  match: match,
                  brakes: motion.brakingEvents,
                  newMain: newPilot ? after.main : null,
                  keeps: !newPilot &&
                          after.main != null &&
                          after.main != match.archetype
                      ? after.main
                      : null,
                ),
              ),
            HeatEnter(
              index: i++,
              child: _Rewards(trip: trip, mascot: mascot),
            ),
            HeatEnter(
              index: i++,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: HeatGhostButton(
                        icon: Icons.ios_share_rounded,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => TripRankCard(
                              trip: trip,
                              routePoints: summary.routePoints,
                              speedSeries: [
                                for (final s in summary.samples) s.speedKmh
                              ],
                              speedBands: computeSpeedBands(summary.samples),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 10,
                      child: HeatGhostButton(
                        label: 'DETTAGLI',
                        onPressed: () => context.push(AppRoutes.tripDetail
                            .replaceFirst(':tripId', trip.id)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 13, // 1.3× DETTAGLI, come nel prototipo
                      child: HeatButton(
                        label: 'CONTINUA',
                        height: 56,
                        fontSize: 21,
                        color: AppColor.ink,
                        glow: false,
                        icon: Icons.double_arrow_rounded,
                        onPressed: () => _continue(context, ref),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: () => _confirmDelete(context, ref, trip.id),
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppColor.inkFaint),
                label: Text('Elimina viaggio',
                    style: AppType.caption.copyWith(color: AppColor.inkFaint)),
              ),
            ),
            SizedBox(height: 12 + MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

class _Header extends StatelessWidget {
  const _Header({required this.trip, required this.onClose});
  final Trip trip;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final d = trip.startedAt;
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              trip.xpEarned == 0
                  ? 'VIAGGIO REGISTRATO · ${_two(d.day)}/${_two(d.month)}'
                  : 'GUIDA COMPLETATA · ${_two(d.day)}/${_two(d.month)} '
                      '${_two(d.hour)}:${_two(d.minute)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.label.copyWith(fontSize: 14, letterSpacing: 1.8),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: AppColor.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// Banda FLOW: il numero conta da 0 al valore, il glow sale con lui, poi
/// compare il grado graffiti.
class _FlowBand extends StatelessWidget {
  const _FlowBand({required this.score, required this.average});
  final int? score;
  final double? average;

  @override
  Widget build(BuildContext context) {
    final a = AppColor.accent;
    final s = score;
    final delta = s == null || average == null ? null : (s - average!).round();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [a.withValues(alpha: .3), a.withValues(alpha: 0)],
          stops: const [0, .75],
        ),
        border: Border.symmetric(
            horizontal: BorderSide(color: a.withValues(alpha: .5))),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.reveal,
        curve: AppMotion.curve,
        builder: (context, t, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FLOW',
                      style: AppType.label
                          .copyWith(fontSize: 16, letterSpacing: 3, color: a)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14, top: 4),
                      child: Text(
                        s == null ? '—' : '${(s * t).round()}',
                        style: AppType.score.copyWith(
                          fontSize: 120,
                          height: .92,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          shadows: [
                            Shadow(
                                color: a.withValues(alpha: .8 * t),
                                blurRadius: 28 * t),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s == null
                        ? 'punteggio non disponibile per questo viaggio'
                        : delta == null
                            ? 'il tuo primo FLOW'
                            : delta == 0
                                ? 'IN LINEA CON LA TUA MEDIA'
                                : '${delta > 0 ? '+' : ''}$delta SULLA TUA MEDIA',
                    style: s == null
                        ? AppType.caption
                        : AppType.display(
                            fontSize: 17,
                            italic: false,
                            letterSpacing: 1,
                            color: delta == null || delta == 0
                                ? AppColor.inkMuted
                                : delta > 0
                                    ? AppColor.success
                                    : AppColor.danger,
                          ),
                  ),
                ],
              ),
            ),
            if (s != null)
              Opacity(
                opacity: ((t - .6) / .4).clamp(0, 1),
                child: Column(
                  children: [
                    Text('GRADO', style: AppType.label),
                    const SizedBox(height: 6),
                    Transform.rotate(
                      angle: -0.14,
                      child: Text(
                        flowGrade(s),
                        style: AppType.graffiti(fontSize: 96, color: a)
                            .copyWith(height: 1.15, shadows: [
                          Shadow(
                              color: a.withValues(alpha: .5), blurRadius: 24),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RouteBox extends StatelessWidget {
  const _RouteBox({
    required this.points,
    required this.brakes,
    this.brakePoints = const [],
  });
  final List<RoutePoint> points;
  final List<RoutePoint> brakePoints;
  final int brakes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: HeatPanel(
        shape: const ChamferBorder(cut: 14, bottomLeft: true),
        color: AppColor.deep,
        borderColor: AppColor.line,
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 140,
          child: Stack(
            children: [
              if (points.length >= 2)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: RoutePreview(points: points, brakes: brakePoints),
                  ),
                ),
              Positioned(
                left: 12,
                top: 10,
                child: Text.rich(
                  TextSpan(
                    text: 'TRACCIATO · ',
                    children: [
                      TextSpan(
                        text: brakes == 0
                            ? 'NESSUNA FRENATA BRUSCA'
                            : '$brakes ${brakes == 1 ? 'FRENATA' : 'FRENATE'}',
                        style: TextStyle(
                            color: brakes == 0
                                ? AppColor.inkMuted
                                : AppColor.gold),
                      ),
                    ],
                  ),
                  style: AppType.label.copyWith(letterSpacing: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _gradeQuote(String grade) => switch (grade) {
      'S' => 'pulitissima. così si guida, niente da aggiungere.',
      'A' => 'bella guida. la prossima la voglio da S.',
      'B' => 'niente male, ma qualche frenata di troppo.',
      _ => 'mmh. la prossima volta con più calma, ok?',
    };

class _MascotComment extends StatelessWidget {
  const _MascotComment(
      {required this.mascot, required this.grade, this.celebration = false});
  final Mascot mascot;
  final String grade;

  /// Emote esultanza sbloccata (pass o legame LV2): sulle guide da S/A la
  /// mascotte festeggia con la posa più carica.
  final bool celebration;

  @override
  Widget build(BuildContext context) {
    final happy = grade == 'S' || grade == 'A';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Image.asset(
              'assets/emotes/${mascot.id}_emote_${happy && !celebration ? 'a' : 'b'}.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: HeatPanel(
                shape: const SlantBorder(left: 12, right: 0),
                borderColor: AppColor.line,
                padding: const EdgeInsets.fromLTRB(18, 11, 16, 11),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: '${mascot.name} ',
                      style: AppType.display(
                          fontSize: 16,
                          italic: false,
                          letterSpacing: 1,
                          color: mascot.accentColor),
                    ),
                    TextSpan(text: _gradeQuote(grade)),
                  ]),
                  style: AppType.body.copyWith(height: 1.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PilotCard extends StatelessWidget {
  const _PilotCard({
    required this.trip,
    required this.match,
    required this.brakes,
    required this.newMain,
    required this.keeps,
  });
  final Trip trip;
  final DriverArchetypeMatch match;
  final int brakes;

  /// Pilota principale appena cambiato (banner NUOVO PILOTA).
  final DriverArchetype? newMain;

  /// Pilota principale che resta, se diverso da quello di oggi.
  final DriverArchetype? keeps;

  @override
  Widget build(BuildContext context) {
    final a = match.archetype;
    final accent = AppColor.accent;
    final avg = trip.avgSpeedKmh;
    final chips = <(IconData, String)>[
      (Icons.route_rounded, '${trip.distanceKm.toStringAsFixed(1)} km'),
      if (avg != null) (Icons.speed_rounded, '${avg.round()} km/h media'),
      (
        Icons.do_not_step_rounded,
        '$brakes ${brakes == 1 ? 'frenata' : 'frenate'}'
      ),
    ];
    final aff = match.affinities.take(3).toList();
    void openPilots() => context.push(AppRoutes.pilots);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColor.surface,
          border: Border.all(color: AppColor.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (newMain != null)
              HeatPressable(
                onTap: openPilots,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      accent.withValues(alpha: .3),
                      accent.withValues(alpha: 0),
                    ]),
                    border: Border(bottom: BorderSide(color: accent)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.swap_vert_rounded, color: accent, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: 'NUOVO PILOTA',
                              style: AppType.display(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: 1,
                                  color: accent),
                            ),
                            TextSpan(text: ' · ora sei ${newMain!.name}'),
                          ]),
                          style: AppType.body.copyWith(fontSize: 13),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColor.inkMuted),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('OGGI HAI GUIDATO COME', style: AppType.label),
                  const SizedBox(height: 10),
                  HeatPressable(
                    onTap: openPilots,
                    child: Row(
                      children: [
                        PilotEmblem(monogram: a.monogram),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.name,
                                  style: AppType.display(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 22,
                                      height: 1)),
                              Text(a.source, style: AppType.caption),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColor.inkFaint),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(a.tagline, style: AppType.body.copyWith(height: 1.4)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final (icon, label) in chips)
                        Container(
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColor.surfaceHigh,
                            border: Border.all(color: AppColor.line),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 16, color: AppColor.inkMuted),
                              const SizedBox(width: 6),
                              Text(label,
                                  style: AppType.display(
                                      fontSize: 15,
                                      italic: false,
                                      letterSpacing: .5)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (aff.length > 1) ...[
                    const SizedBox(height: 14),
                    Text('AFFINITÀ',
                        style: AppType.label
                            .copyWith(fontSize: 12, letterSpacing: 1.6)),
                    const SizedBox(height: 6),
                    for (final (k, e) in aff.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _AffinityRow(
                          name: e.key.name,
                          value: e.value.clamp(0.0, 1.0),
                          highlight: k == 0,
                        ),
                      ),
                  ],
                  if (keeps != null) ...[
                    const SizedBox(height: 4),
                    const Divider(color: AppColor.line, height: 1),
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'il tuo pilota resta '),
                        TextSpan(
                          text: keeps!.name,
                          style: AppType.display(
                              fontSize: 15, italic: false, letterSpacing: 1),
                        ),
                      ]),
                      style: AppType.body
                          .copyWith(fontSize: 13, color: AppColor.inkMuted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AffinityRow extends StatelessWidget {
  const _AffinityRow(
      {required this.name, required this.value, required this.highlight});
  final String name;
  final double value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = highlight ? AppColor.ink : AppColor.inkMuted;
    return Row(
      children: [
        SizedBox(
          width: 118,
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.display(
                  fontSize: 13, italic: false, letterSpacing: .6, color: c)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(milliseconds: 1000),
            curve: AppMotion.enterCurve,
            builder: (_, v, __) => SkewBar(
              value: v,
              height: 6,
              color: highlight ? AppColor.ink : AppColor.lineMuted,
              track: AppColor.surfaceHigh,
            ),
          ),
        ),
        SizedBox(
          width: 42,
          child: Text('${(value * 100).round()}%',
              textAlign: TextAlign.right,
              style: AppType.display(fontSize: 14, italic: false, color: c)),
        ),
      ],
    );
  }
}

class _Rewards extends StatelessWidget {
  const _Rewards({required this.trip, required this.mascot});
  final Trip trip;
  final Mascot mascot;

  @override
  Widget build(BuildContext context) {
    final bondGain = (trip.xpEarned * 0.10).round();
    final rows = [
      ('XP', '+${trip.xpEarned}', AppColor.gold),
      if (bondGain > 0 && trip.xpBreakdown.isNotEmpty)
        ('LEGAME ${mascot.name}', '+$bondGain', mascot.accentColor),
      ('REP', '+${trip.repEarned}', AppColor.ink),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (label, value, color) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: HeatPanel(
                shape: const SlantBorder.all(10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(label,
                          style: AppType.label
                              .copyWith(fontSize: 15, letterSpacing: 1.6)),
                    ),
                    Text(value,
                        style: AppType.display(
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                            color: color)),
                  ],
                ),
              ),
            ),
          if (trip.xpBreakdown.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
              child: Column(
                children: [
                  for (final l in trip.xpBreakdown)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.label,
                              style: AppType.display(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                italic: false,
                                letterSpacing: 1.2,
                                color: AppColor.inkMuted,
                              ),
                            ),
                          ),
                          Text(
                            l.xp < 0 ? '−${-l.xp}' : '+${l.xp}',
                            style: AppType.display(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: l.xp < 0
                                  ? AppColor.danger
                                  : AppColor.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (trip.xpEarned == 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Nessun XP per questo viaggio: troppo corto, velocità '
                'incompatibile con un\'auto, tetto giornaliero raggiunto o '
                'stesso percorso ripetuto troppe volte oggi.',
                style: AppType.caption,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
