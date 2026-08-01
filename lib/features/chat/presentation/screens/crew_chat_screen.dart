import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_screen.dart';

class CrewChatScreen extends StatelessWidget {
  const CrewChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
        title: 'Chat Crew', icon: Icons.chat_bubble_rounded);
  }
}
