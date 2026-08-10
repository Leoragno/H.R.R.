import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_screen.dart';

/// Il contenuto "Guida" che viveva qui è stato spostato nel tab Home
/// (vedi home_screen.dart) su richiesta — questa rotta resta come
/// placeholder, non più raggiungibile dalla bottom nav.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(title: 'Mappa', icon: Icons.map_rounded);
  }
}
