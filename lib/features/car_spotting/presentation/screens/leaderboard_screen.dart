import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/car_spotting_provider.dart';
import '../widgets/empty_spot_state.dart';
import '../widgets/podium_card.dart';

/// TOP AUTO DELLA COMMUNITY — nessuna soglia minima di voti, ordinata
/// solo per media stelle (vedi topRatedSpotsProvider).
class CarSpottingLeaderboardScreen extends ConsumerWidget {
  const CarSpottingLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topRated = ref.watch(topRatedSpotsProvider);

    return Scaffold(
      backgroundColor: AppColor.base,
      appBar: AppBar(
        backgroundColor: AppColor.base,
        elevation: 0,
        title: Text('TOP AUTO DELLA COMMUNITY',
            style: AppType.display(fontSize: 16, letterSpacing: 0.5)),
      ),
      body: topRated.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColor.cyan)),
        error: (err, st) => Center(
            child: Text('Errore: $err',
                style: AppType.text(color: AppColor.inkMuted))),
        data: (spots) {
          if (spots.isEmpty) {
            return const EmptySpotState(
              icon: Icons.emoji_events_rounded,
              message:
                  'Nessuna auto valutata ancora.\nVota uno spot per far partire la classifica!',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: spots.length,
            itemBuilder: (context, i) => PodiumCard(
              rank: i + 1,
              spot: spots[i],
              onTap: () => context.push(
                  AppRoutes.spotDetail.replaceFirst(':spotId', spots[i].id)),
            ),
          );
        },
      ),
    );
  }
}
