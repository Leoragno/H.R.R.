import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/entities/trip.dart';
import '../providers/trip_provider.dart';
import '../widgets/route_preview_painter.dart';
import '../widgets/trip_stat_card.dart';

class TripDetailScreen extends ConsumerWidget {
  final String tripId;
  const TripDetailScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripByIdProvider(tripId));

    return Scaffold(
      backgroundColor: AppColor.void_,
      body: SafeArea(
        child: tripAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColor.cyan)),
          error: (e, _) => Center(
            child: Text('Viaggio non trovato',
                style: AppType.text(color: AppColor.danger)),
          ),
          data: (trip) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                Row(
                  children: [
                    _RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.pop()),
                    Expanded(
                      child: Text(
                        'Dettaglio viaggio',
                        textAlign: TextAlign.center,
                        style: AppType.text(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: AppColor.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 46),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  '${trip.startedAt.day.toString().padLeft(2, '0')}/'
                  '${trip.startedAt.month.toString().padLeft(2, '0')}/'
                  '${trip.startedAt.year} · ${trip.startedAt.hour.toString().padLeft(2, '0')}:'
                  '${trip.startedAt.minute.toString().padLeft(2, '0')}',
                  textAlign: TextAlign.center,
                  style: AppType.text(color: AppColor.inkMuted),
                ),
                const SizedBox(height: 20),
                if (trip.route.length >= 2) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      height: 180,
                      color: const Color(0xFF171717),
                      child: RoutePreview(points: trip.route),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _RewardChip(
                          label: 'XP',
                          value: trip.xpEarned,
                          color: AppMascot.volt),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RewardChip(
                          label: 'REP',
                          value: trip.repEarned,
                          color: AppColor.amber),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                GlassCard(
                  child: Column(
                    children: [
                      _StatRow(
                          label: 'Distanza',
                          value: '${trip.distanceKm.toStringAsFixed(1)} km'),
                      const Divider(height: 20, color: Color(0xFF1D2740)),
                      _StatRow(
                        label: 'Durata',
                        value: '${trip.durationSeconds ~/ 60} min',
                      ),
                      const Divider(height: 20, color: Color(0xFF1D2740)),
                      _StatRow(
                        label: 'Velocità media',
                        value:
                            '${trip.avgSpeedKmh?.toStringAsFixed(0) ?? '—'} km/h',
                      ),
                      const Divider(height: 20, color: Color(0xFF1D2740)),
                      _StatRow(
                        label: 'Velocità massima',
                        value:
                            '${trip.maxSpeedKmh?.toStringAsFixed(0) ?? '—'} km/h',
                      ),
                      if (trip.drivingScore != null) ...[
                        const Divider(height: 20, color: Color(0xFF1D2740)),
                        _StatRow(
                          label: 'Punteggio di guida',
                          value: '${trip.drivingScore}/100',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('Statistiche del trip', style: AppType.title),
                const SizedBox(height: AppSpace.sm),
                _MotionStatsGrid(trip: trip),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _RewardChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text('+$value',
              style: AppType.text(
                  color: color, fontWeight: FontWeight.w800, fontSize: 20)),
          const SizedBox(height: 2),
          Text(label,
              style: AppType.text(
                  color: AppColor.inkMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Stesse statistiche di TripSummaryScreen (report subito dopo la corsa),
/// lette qui dalle colonne persistite da complete_trip
/// (0030_persist_trip_motion_stats.sql) invece che da TripMotionStats
/// (effimero, esiste solo mentre il viaggio è in corso). '—' per ogni
/// campo singolarmente assente: sia sui viaggi completati prima di questa
/// migration (tutti null) sia quando l'evento non si è mai verificato in
/// un viaggio nuovo (es. mai una svolta -> turnsLeft/turnsRight comunque
/// valorizzati a 0 dal client, non null — '—' resta per i soli campi che
/// il client può davvero non calcolare, es. nessun dato di quota GPS).
class _MotionStatsGrid extends StatelessWidget {
  final Trip trip;
  const _MotionStatsGrid({required this.trip});

  @override
  Widget build(BuildContext context) {
    final stoppedSeconds = trip.stoppedSeconds;
    final peakG = trip.peakGForce;
    final maxAccel = trip.maxAccelerationMs2;
    final maxDecel = trip.maxDecelerationMs2;
    final elevationGain = trip.elevationGainM;
    final maxAltitude = trip.maxAltitudeM;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpace.sm,
      mainAxisSpacing: AppSpace.sm,
      childAspectRatio: 1.4,
      children: [
        TripStatCard(
            'Tempo da fermo',
            stoppedSeconds != null
                ? formatStoppedTime(Duration(seconds: stoppedSeconds))
                : '—',
            ''),
        TripStatCard('Soste totali', '${trip.totalStops ?? '—'}', ''),
        TripStatCard(
            'Tempo 0-100',
            trip.zeroToHundredSeconds != null
                ? trip.zeroToHundredSeconds!.toStringAsFixed(2)
                : '—',
            's'),
        TripStatCard('Frenate', '${trip.brakingEvents ?? '—'}', ''),
        TripStatCard('Svolte a sinistra', '${trip.turnsLeft ?? '—'}', ''),
        TripStatCard('Svolte a destra', '${trip.turnsRight ?? '—'}', ''),
        TripStatCard('Cambi di corsia', '${trip.laneChanges ?? '—'}', ''),
        TripStatCard('Picco forza G', peakG != null ? peakG.toStringAsFixed(2) : '—',
            'G',
            hint: peakG != null ? gForceHint(peakG) : null),
        TripStatCard(
            'Velocità max in curva',
            trip.maxCorneringSpeedKmh != null
                ? trip.maxCorneringSpeedKmh!.toStringAsFixed(0)
                : '—',
            'km/h'),
        TripStatCard(
            'Accelerazione max',
            maxAccel != null ? maxAccel.toStringAsFixed(1) : '—',
            'm/s²',
            hint: maxAccel != null ? accelHint(maxAccel) : null),
        TripStatCard(
            'Decelerazione max',
            maxDecel != null ? maxDecel.abs().toStringAsFixed(1) : '—',
            'm/s²',
            hint: maxDecel != null ? decelHint(maxDecel) : null),
        TripStatCard('Dislivello',
            elevationGain != null ? elevationGain.round().toString() : '—', 'm'),
        TripStatCard(
            'Altitudine max',
            maxAltitude != null ? maxAltitude.round().toString() : '—',
            'm'),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: AppType.text(color: AppColor.inkMuted)),
        Text(value,
            style: AppType.text(
                fontWeight: FontWeight.w700, color: AppColor.ink)),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE50C1120),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: AppColor.ink, size: 20),
        ),
      ),
    );
  }
}
