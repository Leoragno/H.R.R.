import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../domain/social_models.dart';
import '../social_providers.dart';
import '../widgets/social_widgets.dart';

/// Amici (HEAT): tutti gli altri piloti, con livello, pilota principale e
/// stato (IN GUIDA / ONLINE / visto N fa). L'app è chiusa: niente
/// richieste né "aggiungi". Schermata senza accento: è una lista.
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider);
    final driving = ref.watch(drivingNowProvider);
    final now = DateTime.now();
    final list = friends.valueOrNull ?? const <Friend>[];
    // In guida prima, poi online, poi gli altri (ordine server: livello).
    int rank(Friend f) {
      final s = friendStatus(f, driving: driving.contains(f.id), now: now);
      return s.live ? 0 : (s.label == 'ONLINE' ? 1 : 2);
    }

    final sorted = [...list]..sort((a, b) => rank(a).compareTo(rank(b)));

    return Scaffold(
      backgroundColor: AppColor.base,
      body: HeatBackground(
        glow: false,
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppColor.ink,
            onRefresh: () => ref.refresh(friendsProvider.future),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 30),
              children: [
                const BackRow(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Expanded(child: ScreenTitle('Amici', fontSize: 48)),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('${list.length}',
                            style: AppType.display(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppColor.inkMuted)),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 14, 18, 8),
                  child: SectionLabel('I tuoi amici'),
                ),
                if (friends.isLoading && list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                        child: CircularProgressIndicator(color: AppColor.ink)),
                  )
                else if (friends.hasError && list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: EmptyNote(
                        'amici non caricati. trascina per riprovare.'),
                  )
                else if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: EmptyNote('nessun amico ancora.'),
                  )
                else
                  for (final (i, f) in sorted.indexed)
                    HeatEnter(
                      index: i.clamp(0, 10),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                        child: FriendRow(
                          friend: f,
                          status: friendStatus(f,
                              driving: driving.contains(f.id), now: now),
                          onTap: () => context.push(AppRoutes.friendProfile
                              .replaceFirst(':profileId', f.id)),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FriendRow extends ConsumerWidget {
  const FriendRow({
    super.key,
    required this.friend,
    required this.status,
    required this.onTap,
  });

  final Friend friend;
  final FriendStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pilot = ref.watch(friendPilotProvider(friend.id)).main;
    return HeatPressable(
      onTap: onTap,
      child: Container(
        color: AppColor.surface,
        padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
        child: Row(
          children: [
            SizedBox(
              width: 51,
              height: 51,
              child: Stack(
                children: [
                  PilotFace(user: friend.user),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      child: Diamond(color: status.color, size: 9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('@${friend.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.text(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColor.ink)),
                  const SizedBox(height: 2),
                  Text(
                    'LV ${friend.user.level} · '
                    '${pilot?.name.toUpperCase() ?? 'PILOTA IN ARRIVO'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.text(fontSize: 12, color: AppColor.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(status.label,
                style: AppType.display(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    italic: false,
                    letterSpacing: 1,
                    color: status.color)),
          ],
        ),
      ),
    );
  }
}
