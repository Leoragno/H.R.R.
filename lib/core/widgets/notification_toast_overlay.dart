import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/domain/entities/app_notification.dart';
import '../../features/notifications/presentation/providers/notifications_provider.dart';
import '../../features/notifications/presentation/widgets/notification_presentation.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/heat_shapes.dart';
import 'heat/heat_widgets.dart';

/// Toast "un po' simpatico" per una nuova notifica arrivata mentre l'app
/// era già aperta, sopra qualunque tab (vedi MainShell) — non è uno stato
/// persistente: [NotificationToastController] emette un impulso, qui
/// decidiamo per quanto resta visibile, indipendentemente da eventuali
/// altre notifiche arrivate nel frattempo.
class NotificationToastOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const NotificationToastOverlay({super.key, required this.child});

  @override
  ConsumerState<NotificationToastOverlay> createState() =>
      _NotificationToastOverlayState();
}

class _NotificationToastOverlayState
    extends ConsumerState<NotificationToastOverlay> {
  AppNotification? _visible;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onArrival(AppNotification notification) {
    _hideTimer?.cancel();
    setState(() => _visible = notification);
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _visible = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppNotification?>(notificationToastControllerProvider,
        (previous, next) {
      if (next != null) _onArrival(next);
    });

    final visible = _visible;
    return Stack(
      children: [
        widget.child,
        if (visible != null)
          Positioned(
            left: AppSpace.md,
            right: AppSpace.md,
            bottom: 90, // sopra la bottom nav su ogni tab
            child: SafeArea(
              top: false,
              child: _ToastCard(
                notification: visible,
                onTap: () {
                  setState(() => _visible = null);
                  context.push(AppRoutes.notifications);
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _ToastCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  const _ToastCard({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = presentationFor(notification);
    final body = p.body(notification);
    return HeatPanel(
      onTap: onTap,
      shape: ChamferBorder(
        cut: 14,
        bottomLeft: true,
        side: BorderSide(
            color: p.rival ? AppColor.danger : AppColor.line, width: 1.2),
      ),
      color: AppColor.surfaceHigh,
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const ShapeDecoration(
              color: AppColor.surface,
              shape: SlantBorder(left: 6, right: 6),
            ),
            child: Icon(p.icon, color: p.color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: p.title(notification),
                  style: AppType.text(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColor.ink),
                ),
                if (body.isNotEmpty) TextSpan(text: ' $body'),
              ]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.text(
                  fontSize: 13.5, height: 1.35, color: AppColor.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
