import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/trip_provider.dart';

class TripDetailScreen extends ConsumerWidget {
  final String tripId;
  const TripDetailScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripByIdProvider(tripId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Dettaglio Viaggio')),
      body: tripAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.neonCyan)),
        error: (e, _) => Center(
          child: Text('Viaggio non trovato',
              style: TextStyle(color: AppColors.danger)),
        ),
        data: (trip) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '${trip.startedAt.day.toString().padLeft(2, '0')}/'
                '${trip.startedAt.month.toString().padLeft(2, '0')}/'
                '${trip.startedAt.year} · ${trip.startedAt.hour.toString().padLeft(2, '0')}:'
                '${trip.startedAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _RewardChip(
                        label: 'XP',
                        value: trip.xpEarned,
                        color: AppColors.neonPurple),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RewardChip(
                        label: 'REP',
                        value: trip.repEarned,
                        color: AppColors.neonAmber),
                  ),
                ],
              ),
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
                      value: '${trip.durationSeconds ~/ 60} min',
                    ),
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
              ),
            ],
          );
        },
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text('+$value',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 20)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
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
