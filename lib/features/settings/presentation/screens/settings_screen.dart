import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
        title: 'Impostazioni', icon: Icons.settings_rounded);
  }
}
