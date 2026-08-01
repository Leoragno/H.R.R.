import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/trip_live_provider.dart';
import '../widgets/route_preview_painter.dart';

class TripSummaryScreen extends ConsumerWidget {
  final TripSummary summary;
  const TripSummaryScreen({super.key, required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = summary.trip;
    final earnedNothing = trip.xpEarned == 0 && trip.repEarned == 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          children: [
            Center(
              child: ShaderMask(
                shaderCallback: (b) =>
                    const LinearGradient(colors: AppColors.gradientPrimary)
                        .createShader(b),
                child: Text(
                  earnedNothing ? 'VIAGGIO REGISTRATO' : 'DRIVE COMPLETED',
                  style: AppTheme.orbitron(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: Colors.white),
                ),
              ),
            ).animate().fadeIn().slideY(begin: -0.2, end: 0),
            const SizedBox(height: 24),
            if (summary.routePoints.length >= 2)
              SizedBox(
                height: 160,
                child: RoutePreview(points: summary.routePoints),
              ).animate().fadeIn(delay: 150.ms),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _RewardCard(
                    label: 'XP',
                    value: trip.xpEarned,
                    colors: AppColors.gradientXp,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _RewardCard(
                    label: 'REP',
                    value: trip.repEarned,
                    colors: AppColors.gradientRep,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.15, end: 0),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _StatRow(
                      label: 'Distanza',
                      value: '${trip.distanceKm.toStringAsFixed(1)} km'),
                  const Divider(height: 20),
                  _StatRow(
                      label: 'Durata',
                      value: _formatDuration(trip.durationSeconds)),
                  const Divider(height: 20),
                  _StatRow(
                    label: 'Velocità media',
                    value:
                        '${trip.avgSpeedKmh?.toStringAsFixed(0) ?? '—'} km/h',
                  ),
                  const Divider(height: 20),
                  _StatRow(
                    label: 'Velocità massima',
                    value:
                        '${trip.maxSpeedKmh?.toStringAsFixed(0) ?? '—'} km/h',
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 350.ms),
            if (earnedNothing) ...[
              const SizedBox(height: 16),
              const Text(
                'Nessun premio assegnato per questo viaggio (velocità media o '
                'distanza fuori dai limiti previsti).',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  ref.invalidate(myProfileProvider);
                  context.go(AppRoutes.home);
                },
                child: const Text('CONTINUA'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}min';
    return '$m min';
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
          Text(
            '+$value',
            style: AppTheme.orbitron(
                fontWeight: FontWeight.w900, fontSize: 32, color: Colors.black),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
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
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
