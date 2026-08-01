import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
        title: 'Notifiche', icon: Icons.notifications_rounded);
  }
}
