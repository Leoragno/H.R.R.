import 'package:flutter/material.dart';

/// Chiave logica (colonna `icon` di `missions`/`mission_templates`/
/// `achievements` in DB) -> IconData Flutter. Unica fonte per non
/// duplicare la mappa tra missions_screen.dart e achievements_screen.dart
/// (che divergevano già: solo una delle due aveva la chiave 'flag').
const hrrIconByKey = <String, IconData>{
  'target': Icons.track_changes_rounded,
  'route': Icons.route_rounded,
  'waves': Icons.waves_rounded,
  'explore': Icons.explore_rounded,
  'play_circle': Icons.play_circle_rounded,
  'flag_circle': Icons.flag_circle_rounded,
  'flag': Icons.flag_rounded,
  'groups': Icons.groups_rounded,
  'military_tech': Icons.military_tech_rounded,
  'workspace_premium': Icons.workspace_premium_rounded,
  'moon': Icons.nightlight_round,
  'mountain': Icons.terrain_rounded,
  'search': Icons.search_rounded,
  'trophy': Icons.emoji_events_rounded,
  'collections': Icons.collections_rounded,
  'bolt': Icons.bolt_rounded,
  'speed': Icons.speed_rounded,
  'hexagon': Icons.hexagon_rounded,
  'camera': Icons.photo_camera_rounded,
};
