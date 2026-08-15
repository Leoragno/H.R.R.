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
    final presentation = presentationFor(notification);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: AppColor.surfaceHigh.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: presentation.color, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: presentation.color.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(presentation.icon, color: presentation.color, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(presentation.title(notification),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.text(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColor.ink)),
                    Text(presentation.body(notification),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.text(
                            fontSize: 12.5,
                            color: AppColor.inkMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
