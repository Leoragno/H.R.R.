import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notifications_provider.dart';
import '../widgets/notification_presentation.dart';

/// Feed notifiche — legge `notifications` (già popolata da più trigger
/// server: missioni, achievement, rating) in realtime via
/// [notificationsControllerProvider]. Prima di questa schermata quella
/// tabella non veniva mai letta da nessuno screen.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsControllerProvider);
    final hasUnread = notifications.any((n) => !n.read);

    return Scaffold(
      backgroundColor: AppColors.guidaBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Notifiche',
                      style: AppTheme.archivo(
                          fontWeight: FontWeight.w900,
                          fontSize: 32,
                          color: AppColors.textPrimary)),
                  TextButton(
                    onPressed: hasUnread
                        ? () => ref
                            .read(notificationsControllerProvider.notifier)
                            .markAllRead()
                        : null,
                    child: Text('Segna tutte come lette',
                        style: AppTheme.archivo(
                            fontSize: 13,
                            color: hasUnread
                                ? AppColors.guidaCyan
                                : AppColors.guidaTextSecondary)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: notifications.isEmpty
                  ? const _EmptyNotifications()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _NotificationTile(
                        notification: notifications[i],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presentation = presentationFor(notification);
    final unread = !notification.read;

    return Material(
      color: unread
          ? presentation.color.withValues(alpha: 0.08)
          : const Color(0xE50A0E1A),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => ref
            .read(notificationsControllerProvider.notifier)
            .markRead(notification.id),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: unread
                  ? presentation.color.withValues(alpha: 0.5)
                  : const Color(0x29A0C8FF),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: presentation.color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(presentation.icon,
                    color: presentation.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(presentation.title(notification),
                        style: AppTheme.archivo(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Text(presentation.body(notification),
                        style: AppTheme.archivo(
                            fontSize: 13, color: AppColors.guidaTextSecondary)),
                    const SizedBox(height: 6),
                    Text(_relativeTime(notification.createdAt),
                        style: AppTheme.archivo(
                            fontSize: 11, color: AppColors.guidaTextSecondary)),
                  ],
                ),
              ),
              if (unread)
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(left: 6, top: 4),
                  decoration: BoxDecoration(
                    color: presentation.color,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _relativeTime(DateTime at) {
  final diff = DateTime.now().difference(at);
  if (diff.inMinutes < 1) return 'Adesso';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min fa';
  if (diff.inHours < 24) return '${diff.inHours} h fa';
  if (diff.inDays < 7) return '${diff.inDays} g fa';
  return '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')}/${at.year}';
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_off_rounded,
                size: 48, color: AppColors.textDisabled),
            const SizedBox(height: 16),
            Text(
              'Nessuna notifica... per ora! 👀\n'
              'Vai a guidare, avvista un\'auto o completa una missione:\n'
              'qui si anima in fretta.',
              textAlign: TextAlign.center,
              style: AppTheme.archivo(
                  color: AppColors.guidaTextSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
