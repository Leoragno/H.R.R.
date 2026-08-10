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

/// Riepilogo di fine viaggio — versione ricca secondo Guida.dc.html righe
/// 837-992 (report) + 994-1134 (card condivisibile "TripRank", dietro il
/// bottone Condividi). Non include il confronto "previsto vs effettivo"
/// del mockup: richiederebbe un motore di stima ETA che non esiste in
/// questa app, e inventare quei numeri sarebbe fuorviante.
class TripSummaryScreen extends ConsumerWidget {
  const TripSummaryScreen({super.key});

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}min';
    return '$m min';
  }

  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _formatStoppedTime(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m}m ${s}s';
  }

  // Etichette contestuali sotto il valore, in stile "racing" coerente col
  // resto dell'app (XP/REP, gradient) — calcolate da soglie sul dato reale,
  // non inventate.
  String _gForceHint(double g) {
    if (g >= 1.0) return 'Impatto forte';
    if (g >= 0.6) return 'Frenata/curva decisa';
    if (g >= 0.3) return 'Guida sportiva';
    return 'Guida regolare';
  }

  String _accelHint(double a) {
    if (a >= 6) return 'Partenza sportiva';
    if (a >= 3) return 'Accelerazione decisa';
    return 'Accelerazione regolare';
  }

  String _decelHint(double a) {
    final abs = a.abs();
    if (abs >= 8) return 'Frenata di emergenza';
    if (abs >= 4) return 'Frenata decisa';
    return 'Frenata regolare';
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String tripId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1522),
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
                style: TextStyle(color: AppColors.danger)),
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
        backgroundColor: AppColors.guidaBg,
        body: SizedBox.shrink(),
      );
    }
    final trip = summary.trip;
    final earnedNothing = trip.xpEarned == 0 && trip.repEarned == 0;
    final speedSeries = summary.samples.map((s) => s.speedKmh).toList();
    final elevationSeries = summary.samples
        .where((s) => s.elevationM != null && s.elevationM != 0)
        .map((s) => s.elevationM!)
        .toList();
    final speedBands = computeSpeedBands(summary.samples);
    final motion = summary.motionStats;

    return Scaffold(
      backgroundColor: AppColors.guidaBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Center(
              child: ShaderMask(
                shaderCallback: (b) =>
                    const LinearGradient(colors: AppColors.guidaGradientCta)
                        .createShader(b),
                child: Text(
                  earnedNothing ? 'VIAGGIO REGISTRATO' : 'DRIVE COMPLETED',
                  style: AppTheme.archivo(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: Colors.white),
                ),
              ),
            ).animate().fadeIn().slideY(begin: -0.2, end: 0),
            const SizedBox(height: 16),

            // Hero: anteprima percorso + top speed + condividi
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Container(
                height: 220,
                color: const Color(0xFF171717),
                child: Stack(
                  children: [
                    if (summary.routePoints.length >= 2)
                      Positioned.fill(
                          child: RoutePreview(points: summary.routePoints)),
                    Positioned(
                      right: 14,
                      top: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xD90A1414),
                          border: Border.all(color: const Color(0xFF2F6F6B)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('TOP SPEED',
                                style: AppTheme.archivo(
                                    fontSize: 10,
                                    letterSpacing: 1.4,
                                    color: AppColors.guidaCyan)),
                            Text.rich(
                              TextSpan(
                                text:
                                    trip.maxSpeedKmh?.toStringAsFixed(0) ?? '—',
                                style: AppTheme.archivo(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white),
                                children: [
                                  TextSpan(
                                    text: ' km/h',
                                    style: AppTheme.archivo(
                                        fontSize: 12,
                                        color: AppColors.guidaTextSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Material(
                        color: const Color(0xD90F0F0F),
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
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 16),

            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 15, color: AppColors.guidaTextSecondary),
                const SizedBox(width: 8),
                Text(
                    '${trip.startedAt.day.toString().padLeft(2, '0')}/${trip.startedAt.month.toString().padLeft(2, '0')}/${trip.startedAt.year}',
                    style: AppTheme.archivo(
                        color: const Color(0xFFCFDCEC), fontSize: 15)),
                const SizedBox(width: 20),
                Icon(Icons.schedule_rounded,
                    size: 15, color: AppColors.guidaTextSecondary),
                const SizedBox(width: 8),
                Text(
                  trip.endedAt == null
                      ? _hm(trip.startedAt)
                      : '${_hm(trip.startedAt)} – ${_hm(trip.endedAt!)}',
                  style: AppTheme.archivo(
                      color: const Color(0xFFCFDCEC), fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: _RewardCard(
                      label: 'XP',
                      value: trip.xpEarned,
                      colors: AppColors.gradientXp),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _RewardCard(
                      label: 'REP',
                      value: trip.repEarned,
                      colors: AppColors.gradientRep),
                ),
              ],
            ).animate().fadeIn(delay: 200.ms),
            if (earnedNothing) ...[
              const SizedBox(height: 12),
              Text(
                'Nessun premio assegnato per questo viaggio (velocità media o '
                'distanza fuori dai limiti previsti).',
                style: AppTheme.archivo(
                    color: AppColors.guidaTextSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 22),

            // Hero stats (3 colonne)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xEB111A2A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                      child: _HeroStat(
                          label: 'DISTANZA',
                          value: trip.distanceKm.toStringAsFixed(1),
                          unit: 'km',
                          dotColor: AppColors.guidaCyan)),
                  Expanded(
                      child: _HeroStat(
                          label: 'DURATA',
                          value: _formatDuration(trip.durationSeconds),
                          unit: '',
                          dotColor: AppColors.guidaBlue)),
                  Expanded(
                      child: _HeroStat(
                          label: 'VEL. MEDIA',
                          value: trip.avgSpeedKmh?.toStringAsFixed(0) ?? '—',
                          unit: 'km/h',
                          dotColor: AppColors.guidaPurple)),
                ],
              ),
            ).animate().fadeIn(delay: 250.ms),
            const SizedBox(height: 22),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SPEED DISTRIBUTION',
                    style: AppTheme.archivo(
                        fontSize: 12,
                        letterSpacing: 1.4,
                        color: AppColors.guidaTextSecondary)),
                Text('KM/H',
                    style: AppTheme.archivo(
                        fontSize: 12, color: AppColors.guidaTextSecondary)),
              ],
            ),
            const SizedBox(height: 10),
            SpeedDistributionBar(bands: speedBands),
            const SizedBox(height: 26),

            Text('Statistiche del trip',
                style: AppTheme.archivo(
                    fontWeight: FontWeight.w800, fontSize: 22)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.4,
              children: [
                _StatCard('Distanza', trip.distanceKm.toStringAsFixed(1), 'km',
                    AppColors.guidaCyan),
                _StatCard('Durata', _formatDuration(trip.durationSeconds), '',
                    AppColors.guidaBlue),
                _StatCard(
                    'Velocità media',
                    trip.avgSpeedKmh?.toStringAsFixed(0) ?? '—',
                    'km/h',
                    AppColors.guidaPurple),
                _StatCard(
                    'Velocità massima',
                    trip.maxSpeedKmh?.toStringAsFixed(0) ?? '—',
                    'km/h',
                    const Color(0xFFFF8A1F)),
                _StatCard('XP guadagnati', '${trip.xpEarned}', '',
                    const Color(0xFF8B5CF6)),
                _StatCard('REP guadagnati', '${trip.repEarned}', '',
                    AppColors.neonAmber),
                _StatCard(
                    'Tempo da fermo',
                    _formatStoppedTime(motion.stoppedTime),
                    '',
                    const Color(0xFF4A90E2)),
                _StatCard('Soste totali', '${motion.totalStops}', '',
                    const Color(0xFF35E0FF)),
                _StatCard(
                    'Tempo 0-100',
                    motion.zeroToHundredSeconds != null
                        ? motion.zeroToHundredSeconds!.toStringAsFixed(2)
                        : '—',
                    's',
                    AppColors.guidaCyan),
                _StatCard('Frenate', '${motion.brakingEvents}', '',
                    const Color(0xFFFF4A4A)),
                _StatCard('Svolte a sinistra', '${motion.turnsLeft}', '',
                    const Color(0xFF7B3BFF)),
                _StatCard('Svolte a destra', '${motion.turnsRight}', '',
                    const Color(0xFFC23DFF)),
                _StatCard('Picco forza G', motion.peakGForce.toStringAsFixed(2),
                    'G', const Color(0xFFFF8A1F),
                    hint: _gForceHint(motion.peakGForce)),
                _StatCard(
                    'Velocità max in curva',
                    motion.maxCorneringSpeedKmh != null
                        ? motion.maxCorneringSpeedKmh!.toStringAsFixed(0)
                        : '—',
                    'km/h',
                    const Color(0xFFFF2D55)),
                _StatCard(
                    'Accelerazione max',
                    motion.maxAccelerationMs2 != null
                        ? motion.maxAccelerationMs2!.toStringAsFixed(1)
                        : '—',
                    'm/s²',
                    const Color(0xFF2ED47A),
                    hint: motion.maxAccelerationMs2 != null
                        ? _accelHint(motion.maxAccelerationMs2!)
                        : null),
                _StatCard(
                    'Decelerazione max',
                    motion.maxDecelerationMs2 != null
                        ? motion.maxDecelerationMs2!.abs().toStringAsFixed(1)
                        : '—',
                    'm/s²',
                    const Color(0xFFFF8A1F),
                    hint: motion.maxDecelerationMs2 != null
                        ? _decelHint(motion.maxDecelerationMs2!)
                        : null),
                _StatCard(
                    'Dislivello',
                    motion.elevationGainM.round().toString(),
                    'm',
                    const Color(0xFF4A90E2)),
                _StatCard(
                    'Altitudine max',
                    motion.maxAltitudeM != null
                        ? motion.maxAltitudeM!.round().toString()
                        : '—',
                    'm',
                    const Color(0xFF8B5CF6)),
              ],
            ),
            const SizedBox(height: 26),

            Text('Speed Over Time',
                style: AppTheme.archivo(
                    fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1414),
                borderRadius: BorderRadius.circular(16),
              ),
              child: LineAreaChart(
                values: speedSeries,
                lineColor: AppColors.guidaCyan,
                fillColor: AppColors.guidaCyan.withValues(alpha: 0.18),
              ),
            ),

            if (elevationSeries.length >= 2) ...[
              const SizedBox(height: 22),
              Text('Elevation Over Time',
                  style: AppTheme.archivo(
                      fontWeight: FontWeight.w800, fontSize: 20)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1118),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: LineAreaChart(
                  values: elevationSeries,
                  lineColor: AppColors.guidaCyan,
                  fillColor: const Color(0xFF4A90E2).withValues(alpha: 0.18),
                ),
              ),
            ],
            const SizedBox(height: 28),

            Material(
              color: const Color(0x1FF04A4A),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _confirmDelete(context, ref, trip.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x59F04A4A)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.delete_outline_rounded,
                          color: AppColors.danger, size: 20),
                      const SizedBox(width: 10),
                      Text('Elimina trip',
                          style: AppTheme.archivo(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w700,
                              fontSize: 18)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

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

class _RewardCard extends StatelessWidget {
  final String label;
  final int value;
  final List<Color> colors;
  const _RewardCard(
      {required this.label, required this.value, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      child: Column(
        children: [
          Text('+$value',
              style: AppTheme.archivo(
                  fontWeight: FontWeight.w900,
                  fontSize: 32,
                  color: Colors.black)),
          const SizedBox(height: 4),
          Text(label,
              style: AppTheme.archivo(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color dotColor;
  const _HeroStat(
      {required this.label,
      required this.value,
      required this.unit,
      required this.dotColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  style: AppTheme.archivo(
                      fontSize: 11, color: const Color(0xFF9DB0C8)),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            text: value,
            style: AppTheme.archivo(
                fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
            children: [
              if (unit.isNotEmpty)
                TextSpan(
                    text: ' $unit',
                    style: AppTheme.archivo(
                        fontSize: 13, color: const Color(0xFF9DB0C8))),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final String? hint;
  const _StatCard(this.label, this.value, this.unit, this.color, {this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xEB111A2A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.9),
                    shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: AppTheme.archivo(
                        fontSize: 13, color: const Color(0xFFC2D2E6)),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const Spacer(),
          Text.rich(
            TextSpan(
              text: value,
              style: AppTheme.archivo(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
              children: [
                if (unit.isNotEmpty)
                  TextSpan(
                      text: ' $unit',
                      style: AppTheme.archivo(
                          fontSize: 13, color: const Color(0xFF9DB0C8))),
              ],
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!,
                style: AppTheme.archivo(fontSize: 11, color: color),
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}
