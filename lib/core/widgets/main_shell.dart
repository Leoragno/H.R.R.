import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/app_update/app_update_prompt.dart';
import '../../features/app_update/web_update_banner.dart';
import '../../features/music/presentation/widgets/music_drawer.dart';
import '../../features/rival/presentation/widgets/rival_overlay.dart';
import '../../features/social/presentation/widgets/presence_touch.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/heat_shapes.dart';
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
    (
      route: AppRoutes.home,
      icon: Icons.directions_car_outlined,
      active: Icons.directions_car_rounded,
      label: 'GUIDA'
    ),
    (
      route: AppRoutes.game,
      icon: Icons.hexagon_outlined,
      active: Icons.hexagon_rounded,
      label: 'GIOCA'
    ),
    (
      route: AppRoutes.carSpotting,
      icon: Icons.photo_camera_outlined,
      active: Icons.photo_camera_rounded,
      label: 'SPOTTING'
    ),
    (
      route: AppRoutes.leaderboard,
      icon: Icons.emoji_events_outlined,
      active: Icons.emoji_events_rounded,
      label: 'CLASSIFICA'
    ),
    (
      route: AppRoutes.statistics,
      icon: Icons.monitor_heart_outlined,
      active: Icons.monitor_heart_rounded,
      label: 'STATS'
    ),
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
      backgroundColor: AppColor.base,
      drawer: const MusicDrawer(),
      body: WebUpdateBanner(
        child: AppUpdatePrompt(
          child: PresenceTouch(
            child: RivalOverlay(child: NotificationToastOverlay(child: child)),
          ),
        ),
      ),
      bottomNavigationBar: _HeatNavBar(
        index: currentIndex,
        onTap: (i) => context.go(_tabs[i].route),
      ),
    );
  }
}

/// Bottom nav HEAT: 86px, tab attiva = riempimento d'accento inclinato con
/// glow; le altre sono icone/label spente.
class _HeatNavBar extends StatelessWidget {
  const _HeatNavBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(6, 8, 6, (bottom > 0 ? bottom : 24)),
      decoration: const BoxDecoration(
        color: Color(0xF70B0912),
        border: Border(top: BorderSide(color: AppColor.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < MainShell._tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              child: _NavItem(
                tab: MainShell._tabs[i],
                active: i == index,
                onTap: () => onTap(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.tab, required this.active, required this.onTap});

  final ({String route, IconData icon, IconData active, String label}) tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColor.onAccent : AppColor.inkFaint;
    return Semantics(
      button: true,
      selected: active,
      label: tab.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.base,
          height: 54,
          decoration: ShapeDecoration(
            shape: const SlantBorder.all(8),
            color: active ? AppColor.accent : Colors.transparent,
            shadows: active
                ? [
                    BoxShadow(
                      color: AppColor.accent.withValues(alpha: .5),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: active ? 1.08 : 1,
                duration: AppMotion.base,
                child:
                    Icon(active ? tab.active : tab.icon, size: 23, color: fg),
              ),
              const SizedBox(height: 3),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: AppType.display(
                  fontSize: 12,
                  letterSpacing: 1,
                  color: fg,
                  italic: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
