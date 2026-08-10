import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/presentation/providers/notifications_provider.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';

/// Campanella con pallino "non lette", da affiancare a [ProfileAvatarButton]
/// nell'header delle tab principali — unico punto d'accesso a
/// /notifications, che prima di questa feature non era raggiungibile da
/// nessuna parte dell'app.
class NotificationBellButton extends ConsumerWidget {
  final double size;
  const NotificationBellButton({super.key, this.size = 46});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsCountProvider);

    return GestureDetector(
      onTap: () => context.push(AppRoutes.notifications),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: const Color(0xE50C1120),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x33A0AAFF)),
              ),
              child: Icon(
                unread > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color: unread > 0
                    ? AppColors.guidaCyan
                    : AppColors.guidaTextSecondary,
                size: size * 0.5,
              ),
            ),
            if (unread > 0)
              Positioned(
                top: -1,
                right: -1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.guidaBg, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
