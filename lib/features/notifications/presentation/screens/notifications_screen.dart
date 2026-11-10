import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notifications_provider.dart';
import '../widgets/notification_presentation.dart';

/// NOTIFICHE (HEAT, handoff §23): raggruppate per giorno (OGGI / IERI /
/// data), riga con icona a parallelogramma, **etichetta** + frase, ora;
/// le non lette hanno bordo sinistro e rombo. Tocca per aprire la
/// schermata collegata (spot, missioni, territori…) e segnarla letta.
/// Legge `notifications` in realtime via [notificationsControllerProvider].
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsControllerProvider);
    final hasUnread = notifications.any((n) => !n.read);
    final now = DateTime.now();

    final children = <Widget>[];
    String? lastDay;
    for (final (i, n) in notifications.indexed) {
      final day = notificationDayLabel(n.createdAt, now);
      if (day != lastDay) {
        lastDay = day;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
          child: SectionLabel(day),
        ));
      }
      children.add(HeatEnter(
        index: i.clamp(0, 10),
        child: NotificationRow(
          notification: n,
          now: now,
          onTap: () {
            ref.read(notificationsControllerProvider.notifier).markRead(n.id);
            final route = presentationFor(n).route(n);
            if (route != null) context.push(route);
          },
        ),
      ));
    }

    return Scaffold(
      backgroundColor: AppColor.base,
      body: HeatBackground(
        glow: false,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 30),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go(AppRoutes.home),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: AppColor.ink),
                    ),
                    const Spacer(),
                    if (hasUnread)
                      TextButton(
                        onPressed: () => ref
                            .read(notificationsControllerProvider.notifier)
                            .markAllRead(),
                        child: Text(
                          'segna tutte lette',
                          style: AppType.text(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColor.inkMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, 6),
                child: ScreenTitle('Notifiche', fontSize: 48),
              ),
              if (notifications.isEmpty)
                const _Empty()
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String notificationDayLabel(DateTime at, DateTime now) {
  final a = DateTime(at.year, at.month, at.day);
  final b = DateTime(now.year, now.month, now.day);
  final days = b.difference(a).inDays;
  if (days <= 0) return 'Oggi';
  if (days == 1) return 'Ieri';
  return '${a.day.toString().padLeft(2, '0')}/${a.month.toString().padLeft(2, '0')}'
      '${a.year != b.year ? '/${a.year}' : ''}';
}

/// "12 MIN" / "3 H" oggi, altrimenti l'ora "22:40".
String notificationTimeLabel(DateTime at, DateTime now) {
  final d = now.difference(at);
  final sameDay =
      at.year == now.year && at.month == now.month && at.day == now.day;
  if (sameDay) {
    if (d.inMinutes < 1) return 'ADESSO';
    if (d.inMinutes < 60) return '${d.inMinutes} MIN';
    return '${d.inHours} H';
  }
  return '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
}

class NotificationRow extends StatelessWidget {
  const NotificationRow({
    super.key,
    required this.notification,
    required this.now,
    required this.onTap,
  });

  final AppNotification notification;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final p = presentationFor(n);
    final unread = !n.read;
    final mark = p.rival ? AppColor.danger : AppColor.ink;
    final body = p.body(n);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: HeatPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 11, 10, 11),
          decoration: BoxDecoration(
            color: !unread
                ? null
                : p.rival
                    ? AppColor.danger.withValues(alpha: .1)
                    : AppColor.surface,
            border: Border(
              left: BorderSide(
                width: 3,
                color: unread ? mark : const Color(0x00000000),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const ShapeDecoration(
                  color: AppColor.surface,
                  shape: SlantBorder(left: 7, right: 7),
                ),
                child: Icon(p.icon, size: 22, color: p.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: p.title(n),
                            style: AppType.text(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColor.ink,
                            ),
                          ),
                          if (body.isNotEmpty) TextSpan(text: ' $body'),
                        ],
                      ),
                      style: AppType.text(
                        fontSize: 14,
                        height: 1.4,
                        color: unread ? AppColor.ink : AppColor.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notificationTimeLabel(n.createdAt, now),
                      style: AppType.display(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        italic: false,
                        color: AppColor.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Transform.rotate(
                  angle: .785,
                  child: Container(
                    width: 8,
                    height: 8,
                    color: unread ? mark : const Color(0x00000000),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
      child: Column(
        children: [
          const Icon(Icons.notifications_none_rounded,
              size: 44, color: AppColor.inkFaint),
          const SizedBox(height: 14),
          Text(
            'nessuna notifica per ora.\n'
            'guida, spotta un\'auto o completa una missione.',
            textAlign: TextAlign.center,
            style: AppType.text(
                fontSize: 14, color: AppColor.inkMuted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
