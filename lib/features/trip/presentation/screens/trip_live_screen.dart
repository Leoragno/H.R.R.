import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/trip_live_provider.dart';

class TripLiveScreen extends ConsumerStatefulWidget {
  const TripLiveScreen({super.key});

  @override
  ConsumerState<TripLiveScreen> createState() => _TripLiveScreenState();
}

class _TripLiveScreenState extends ConsumerState<TripLiveScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tripLiveControllerProvider.notifier).startTrip();
    });
  }

  Future<void> _finish() async {
    final summary =
        await ref.read(tripLiveControllerProvider.notifier).finishTrip();
    if (!mounted || summary == null) return;
    context.pushReplacement(AppRoutes.tripSummary, extra: summary);
  }

  Future<void> _discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Annullare il viaggio?'),
        content: const Text(
            'Il viaggio verrà scartato, nessun XP/REP verrà assegnato.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continua')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Annulla viaggio',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(tripLiveControllerProvider.notifier).discardTrip();
      if (mounted) context.pop();
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tripLiveControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _discard,
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.danger),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fiber_manual_record,
                            size: 10, color: AppColors.danger),
                        const SizedBox(width: 6),
                        Text(
                          state.status == TripLiveStatus.tracking
                              ? 'LIVE'
                              : 'AVVIO...',
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (state.status == TripLiveStatus.error)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.gps_off_rounded,
                        size: 48, color: AppColors.danger.withOpacity(0.7)),
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage ?? 'Errore GPS',
                      style: const TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref
                          .read(tripLiveControllerProvider.notifier)
                          .startTrip(),
                      child: const Text('Riprova'),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.currentSpeedKmh.toStringAsFixed(0),
                        style: AppTheme.orbitron(
                          fontWeight: FontWeight.w900,
                          fontSize: 96,
                          color: AppColors.neonCyan,
                        ),
                      ).animate().fadeIn(),
                      const Text('km/h',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 16)),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _HudStat(
                              label: 'Distanza',
                              value:
                                  '${state.distanceKm.toStringAsFixed(1)} km'),
                          const SizedBox(width: 24),
                          _HudStat(
                              label: 'Tempo',
                              value: _formatDuration(state.elapsed)),
                          const SizedBox(width: 24),
                          _HudStat(
                              label: 'Vel. max',
                              value:
                                  '${state.maxSpeedKmh.toStringAsFixed(0)} km/h'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: SizedBox(
                height: 64,
                child: ElevatedButton.icon(
                  onPressed:
                      state.status == TripLiveStatus.tracking ? _finish : null,
                  icon: const Icon(Icons.flag_rounded),
                  label: const Text('FINE VIAGGIO',
                      style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonMagenta),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HudStat extends StatelessWidget {
  final String label;
  final String value;
  const _HudStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.orbitron(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}
