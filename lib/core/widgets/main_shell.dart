import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/music/presentation/widgets/music_drawer.dart';
import '../../features/rival/presentation/widgets/rival_overlay.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import 'notification_toast_overlay.dart';

/// Persistent shell hosting the bottom navigation bar for the primary tabs.
/// Profilo non è un tab: si apre dall'avatar in alto a destra nelle
/// singole tab (ProfileAvatarButton).
/// Wraps every ShellRoute destination so scroll position / state per tab
/// is preserved (GoRouter ShellRoute keeps each branch's Navigator alive).
class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    (route: AppRoutes.home, icon: Icons.map_rounded, label: 'Guida'),
    (route: AppRoutes.game, icon: Icons.hexagon_outlined, label: 'Gioca'),
    (
      route: AppRoutes.carSpotting,
      icon: Icons.camera_alt_rounded,
      label: 'Spotting'
    ),
    (
      route: AppRoutes.leaderboard,
      icon: Icons.emoji_events_rounded,
      label: 'Classifica'
    ),
    (route: AppRoutes.crew, icon: Icons.groups_rounded, label: 'Crew'),
  ];

  int _indexForLocation(String location) {
    final idx = _tabs.indexWhere((t) => location.startsWith(t.route));
    return idx == -1 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _indexForLocation(location);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const MusicDrawer(),
      body: RivalOverlay(child: NotificationToastOverlay(child: child)),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) => context.go(_tabs[i].route),
          items: [
            for (final t in _tabs)
              BottomNavigationBarItem(icon: Icon(t.icon), label: t.label),
          ],
        ),
      ),
    );
  }
}
