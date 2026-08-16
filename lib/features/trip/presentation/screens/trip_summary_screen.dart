import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/neon_cta_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/trip_live_provider.dart';
import '../providers/trip_provider.dart';
import '../widgets/line_area_chart.dart';
import '../widgets/route_preview_painter.dart';
import '../widgets/speed_distribution_bar.dart';
import '../widgets/trip_rank_card.dart';
import '../widgets/trip_stat_card.dart';

/// Riepilogo di fine viaggio — versione ricca secondo Guida.dc.html righe
/// 837-992 (report) + 994-1134 (card condivisibile "TripRank", dietro il
/// bottone Condividi). Non include il confronto "previsto vs effettivo"
/// del mockup: richiederebbe un motore di stima ETA che non esiste in
/// questa app, e inventare quei numeri sarebbe fuorviante.
///
/// Il protagonista della schermata è il punteggio di guida (DESIGN.md:
/// "Report di fine viaggio → il punteggio"), rivelato con l'unica
/// animazione elaborata dell'app (conteggio + glow che sale, vedi
/// _DriveScoreReveal). Tutto il resto — anteprima percorso, reward,
/// statistiche, grafici — resta grigio su superficie, senza accenti
/// concorrenti: un solo elemento acceso per schermata.
class TripSummaryScreen extends ConsumerWidget {
  const TripSummaryScreen({super.key});

  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String tripId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColor.surfaceHigh,
        title: const Text('Eliminare il trip?'),
        content: const Text(
            'Il viaggio verrà rimosso dal tuo storico. XP e REP già assegnati restano.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina',
                style: TextStyle(color: AppColor.danger)),
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
      // Nessun riepilogo in sospeso (es. refresh diretto su questa route):
      // non c'è nulla da mostrare, torniamo alla Home invece di andare in
      // crash su un dato che non esiste.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.home);
      });
      return const Scaffold(
        backgroundColor: AppColor.void_,
        body: SizedBox.shrink(),
      );
    }
    final trip = summary.trip;
    // La REP non arriva mai da un viaggio guidato da soli (0025_livello_
    // rep_separation.sql): repEarned a 0 è la norma, non un segnale che
    // "non è stato assegnato nulla" — solo xpEarned lo è.
    final earnedNothing = trip.xpEarned == 0;
    final speedSeries = summary.samples.map((s) => s.speedKmh).toList();
    final elevationSeries = summary.samples
        .where((s) => s.elevationM != null && s.elevationM != 0)
        .map((s) => s.elevationM!)
        .toList();
    final speedBands = computeSpeedBands(summary.samples);
    final motion = summary.motionStats;

    return Scaffold(
      backgroundColor: AppColor.void_,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.lg),
          children: [
            Center(
              child: Text(
                earnedNothing ? 'VIAGGIO REGISTRATO' : 'DRIVE COMPLETED',
                style: AppType.label.copyWith(fontSize: 16, color: AppColor.ink),
              ),
            ).animate().fadeIn().slideY(begin: -0.2, end: 0),
            const SizedBox(height: AppSpace.md),

            if (trip.drivingScore != null) ...[
              Center(child: _DriveScoreReveal(score: trip.drivingScore!)),
              const SizedBox(height: AppSpace.lg),
            ],

            // Hero: anteprima percorso (elemento firma, DESIGN.md) + top
            // speed + condividi. Unico elemento acceso della schermata.
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Container(
                height: 220,
                color: AppColor.surface,
                child: Stack(
                  children: [
                    if (summary.routePoints.length >= 2)
                      Positioned.fill(
                          child: RoutePreview(points: summary.routePoints)),
                    Positioned(
                      right: AppSpace.sm,
                      top: AppSpace.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.sm, vertical: AppSpace.xs),
                        decoration: BoxDecoration(
                          color: AppColor.surfaceHigh.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(AppRadius.control),
                          border: Border.all(color: AppColor.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('TOP SPEED', style: AppType.label),
                            Text.rich(
                              TextSpan(
                                text:
                                    trip.maxSpeedKmh?.toStringAsFixed(0) ?? '—',
                                style: AppType.metric.copyWith(fontSize: 17),
                                children: [
                                  TextSpan(
                                    text: ' km/h',
                                    style: AppType.caption,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: AppSpace.sm,
                      bottom: AppSpace.sm,
                      child: Material(
                        color: AppColor.surfaceHigh.withValues(alpha: 0.85),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder: (_) => TripRankCard(
                                trip: trip,
                                routePoints: summary.routePoints,
                                speedSeries: speedSeries,
                                speedBands: speedBands,
                              ),
                            ),
                          ),
                          child: const SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(Icons.ios_share_rounded,
                                color: AppColor.ink, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: AppSpace.md),

            Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 15, color: AppColor.inkMuted),
                const SizedBox(width: AppSpace.sm),
                Text(
                    '${trip.startedAt.day.toString().padLeft(2, '0')}/${trip.startedAt.month.toString().padLeft(2, '0')}/${trip.startedAt.year}',
                    style: AppType.caption),
                const SizedBox(width: AppSpace.md),
                const Icon(Icons.schedule_rounded,
                    size: 15, color: AppColor.inkMuted),
                const SizedBox(width: AppSpace.sm),
                Text(
                  trip.endedAt == null
                      ? _hm(trip.startedAt)
                      : '${_hm(trip.startedAt)} – ${_hm(trip.endedAt!)}',
                  style: AppType.caption,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),

            Row(
              children: [
                Expanded(
                  child: _RewardCard(label: 'XP', value: trip.xpEarned),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: _RewardCard(label: 'REP', value: trip.repEarned),
                ),
              ],
            ).animate().fadeIn(delay: 200.ms),
            if (earnedNothing) ...[
              const SizedBox(height: AppSpace.sm),
              Text(
                'Nessun livello assegnato per questo viaggio (troppo corto, '
                'velocità incompatibile con un\'auto, o hai già raggiunto il '
                'tetto giornaliero/ripetuto lo stesso percorso più volte oggi).',
                style: AppType.caption,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpace.lg),

            // Hero stats (3 colonne) — tutto grigio, nessun accento: il
            // protagonista resta l'anteprima del percorso sopra.
            Container(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpace.md, horizontal: AppSpace.sm),
              decoration: AppGlow.card,
              child: Row(
                children: [
                  Expanded(
                      child: _HeroStat(
                          label: 'DISTANZA',
                          value: trip.distanceKm.toStringAsFixed(1),
                          unit: 'km')),
                  Expanded(
                      child: _HeroStat(
                          label: 'DURATA',
                          value: formatTripDuration(trip.durationSeconds),
                          unit: '')),
                  Expanded(
                      child: _HeroStat(
                          label: 'VEL. MEDIA',
                          value: trip.avgSpeedKmh?.toStringAsFixed(0) ?? '—',
                          unit: 'km/h')),
                ],
              ),
            ).animate().fadeIn(delay: 250.ms),
            const SizedBox(height: AppSpace.lg),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SPEED DISTRIBUTION', style: AppType.label),
                Text('KM/H', style: AppType.caption),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            SpeedDistributionBar(bands: speedBands),
            const SizedBox(height: AppSpace.lg),

            Text('Statistiche del trip', style: AppType.title),
            const SizedBox(height: AppSpace.sm),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpace.sm,
              mainAxisSpacing: AppSpace.sm,
              childAspectRatio: 1.4,
              children: [
                TripStatCard('Distanza', trip.distanceKm.toStringAsFixed(1), 'km'),
                TripStatCard(
                    'Durata', formatTripDuration(trip.durationSeconds), ''),
                TripStatCard('Velocità media',
                    trip.avgSpeedKmh?.toStringAsFixed(0) ?? '—', 'km/h'),
                TripStatCard('Velocità massima',
                    trip.maxSpeedKmh?.toStringAsFixed(0) ?? '—', 'km/h'),
                TripStatCard('XP guadagnati', '${trip.xpEarned}', ''),
                TripStatCard('REP guadagnati', '${trip.repEarned}', ''),
                if (trip.drivingScore != null)
                  TripStatCard(
                      'Punteggio di guida', '${trip.drivingScore}', '/100'),
                TripStatCard('Tempo da fermo',
                    formatStoppedTime(motion.stoppedTime), ''),
                TripStatCard('Soste totali', '${motion.totalStops}', ''),
                TripStatCard(
                    'Tempo 0-100',
                    motion.zeroToHundredSeconds != null
                        ? motion.zeroToHundredSeconds!.toStringAsFixed(2)
                        : '—',
                    's'),
                TripStatCard('Frenate', '${motion.brakingEvents}', ''),
                TripStatCard('Svolte a sinistra', '${motion.turnsLeft}', ''),
                TripStatCard('Svolte a destra', '${motion.turnsRight}', ''),
                TripStatCard('Cambi di corsia', '${motion.laneChanges}', ''),
                TripStatCard('Picco forza G', motion.peakGForce.toStringAsFixed(2),
                    'G',
                    hint: gForceHint(motion.peakGForce)),
                TripStatCard(
                    'Velocità max in curva',
                    motion.maxCorneringSpeedKmh != null
                        ? motion.maxCorneringSpeedKmh!.toStringAsFixed(0)
                        : '—',
                    'km/h'),
                TripStatCard(
                    'Accelerazione max',
                    motion.maxAccelerationMs2 != null
                        ? motion.maxAccelerationMs2!.toStringAsFixed(1)
                        : '—',
                    'm/s²',
                    hint: motion.maxAccelerationMs2 != null
                        ? accelHint(motion.maxAccelerationMs2!)
                        : null),
                TripStatCard(
                    'Decelerazione max',
                    motion.maxDecelerationMs2 != null
                        ? motion.maxDecelerationMs2!.abs().toStringAsFixed(1)
                        : '—',
                    'm/s²',
                    hint: motion.maxDecelerationMs2 != null
                        ? decelHint(motion.maxDecelerationMs2!)
                        : null),
                TripStatCard('Dislivello',
                    motion.elevationGainM.round().toString(), 'm'),
                TripStatCard(
                    'Altitudine max',
                    motion.maxAltitudeM != null
                        ? motion.maxAltitudeM!.round().toString()
                        : '—',
                    'm'),
              ],
            ),
            const SizedBox(height: AppSpace.lg),

            Text('Speed Over Time', style: AppType.title),
            const SizedBox(height: AppSpace.sm),
            Container(
              padding: const EdgeInsets.all(AppSpace.sm),
              decoration: AppGlow.card,
              child: LineAreaChart(
                values: speedSeries,
                lineColor: AppColor.cyan,
                fillColor: AppColor.cyan.withValues(alpha: 0.18),
              ),
            ),

            if (elevationSeries.length >= 2) ...[
              const SizedBox(height: AppSpace.lg),
              Text('Elevation Over Time', style: AppType.title),
              const SizedBox(height: AppSpace.sm),
              Container(
                padding: const EdgeInsets.all(AppSpace.sm),
                decoration: AppGlow.card,
                child: LineAreaChart(
                  values: elevationSeries,
                  lineColor: AppColor.cyan,
                  fillColor: AppColor.inkMuted.withValues(alpha: 0.18),
                ),
              ),
            ],
            const SizedBox(height: AppSpace.xl),

            Material(
              color: AppColor.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.card),
                onTap: () => _confirmDelete(context, ref, trip.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border:
                        Border.all(color: AppColor.danger.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.delete_outline_rounded,
                          color: AppColor.danger, size: 20),
                      const SizedBox(width: AppSpace.sm),
                      Text('Elimina trip',
                          style: AppType.text(
                              color: AppColor.danger,
                              fontWeight: FontWeight.w700,
                              fontSize: 18)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.md),

            NeonCtaButton(
              label: 'Continua',
              minHeight: 60,
              onPressed: () {
                ref.invalidate(myProfileProvider);
                context.go(AppRoutes.home);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Rivelazione del punteggio di guida — l'unica animazione elaborata
/// dell'app (DESIGN.md: "il numero conta da 0 al valore finale in
/// AppMotion.reveal, il glow sale con lui"). Colore a soglie fisse, mai un
/// gradiente: pulito/buono → ciano, scarso/sporco → magenta (stesso
/// vocabolario di "km puliti" nel resto del prodotto), mediocre → grigio,
/// niente da segnalare.
class _DriveScoreReveal extends StatelessWidget {
  final int score;
  const _DriveScoreReveal({required this.score});

  Color get _accent {
    if (score >= 75) return AppColor.cyan;
    if (score <= 40) return AppColor.magenta;
    return AppColor.inkMuted;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.reveal,
      curve: AppMotion.curve,
      builder: (context, t, _) {
        final shown = (score * t).round();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('PUNTEGGIO DI GUIDA', style: AppType.label),
            const SizedBox(height: AppSpace.sm),
            Container(
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: accent.withValues(alpha: 0.50 * t),
                      blurRadius: 40 * t),
                  BoxShadow(
                      color: accent.withValues(alpha: 0.20 * t),
                      blurRadius: 90 * t),
                ],
              ),
              child: Text('$shown',
                  style: AppType.score.copyWith(color: accent, fontSize: 64)),
            ),
          ],
        );
      },
    );
  }
}

class _RewardCard extends StatelessWidget {
  final String label;
  final int value;
  const _RewardCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
      decoration: AppGlow.card,
      child: Column(
        children: [
          Text('+$value', style: AppType.metric),
          const SizedBox(height: AppSpace.xs),
          Text(label, style: AppType.label),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _HeroStat(
      {required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(label, style: AppType.label, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(height: AppSpace.xs),
        Text.rich(
          TextSpan(
            text: value,
            style: AppType.metric.copyWith(fontSize: 20),
            children: [
              if (unit.isNotEmpty)
                TextSpan(text: ' $unit', style: AppType.caption),
            ],
          ),
        ),
      ],
    );
  }
}
