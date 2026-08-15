import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';
import '../providers/trip_provider.dart';
import '../widgets/route_preview_painter.dart';

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
                    ],
                  ),
                ),
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
