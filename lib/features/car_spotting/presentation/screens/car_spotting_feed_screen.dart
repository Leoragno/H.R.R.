import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_screen.dart';

class CarSpottingFeedScreen extends StatelessWidget {
  const CarSpottingFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
        title: 'Car Spotting', icon: Icons.camera_alt_rounded);
  }
}
