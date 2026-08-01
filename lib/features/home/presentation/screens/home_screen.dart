import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Home / HUD Pilota — punto di ingresso principale del loop di gioco.
/// Mostra livello, XP, auto attiva e il CTA "Start Drive" verso trip_live.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: userAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.neonCyan)),
          error: (e, _) => Center(
            child: Text('Errore caricamento profilo',
                style: TextStyle(color: AppColors.danger)),
          ),
          data: (user) {
            if (user == null) {
              return const Center(child: Text('Sessione scaduta'));
            }
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                                  colors: AppColors.gradientPrimary)
                              .createShader(b),
                          child: Text(
                            'HRR',
                            style: AppTheme.orbitron(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.notifications_none_rounded),
                          onPressed: () =>
                              context.push(AppRoutes.notifications),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined),
                          onPressed: () => context.push(AppRoutes.settings),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  sliver: SliverToBoxAdapter(
                    child: _PilotCard(
                      displayName: user.displayName,
                      level: user.level,
                      xp: user.xp,
                      title: user.title,
                    ).animate().fadeIn().slideY(begin: 0.1, end: 0),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  sliver: SliverToBoxAdapter(
                    child:
                        const _CarPhotoCard().animate().fadeIn(delay: 100.ms),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: SizedBox(
                      height: 64,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push(AppRoutes.tripLive),
                        icon: const Icon(Icons.play_arrow_rounded, size: 28),
                        label: const Text('START DRIVE',
                            style: TextStyle(fontSize: 18)),
                      ),
                    ).animate().fadeIn(delay: 150.ms),
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PilotCard extends StatelessWidget {
  final String displayName;
  final int level;
  final int xp;
  final String title;

  const _PilotCard({
    required this.displayName,
    required this.level,
    required this.xp,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    // XP needed for next level, matching formula in ARCHITECTURE.md
    final currentLevelBaseXp = ((level - 1) * (level - 1)) * 100;
    final nextLevelXp = (level * level) * 100;
    final progress =
        ((xp - currentLevelBaseXp) / (nextLevelXp - currentLevelBaseXp))
            .clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.surfaceElevated,
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 24, color: AppColors.neonCyan),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: AppColors.gradientPrimary),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'LV $level',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(title,
                    style: const TextStyle(
                        color: AppColors.neonAmber, fontSize: 12)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceElevated,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.neonCyan),
                  ),
                ),
                const SizedBox(height: 4),
                Text('$xp XP', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Slot foto libero in Home: l'utente carica (o sostituisce) la foto della
/// propria auto da mostrare qui. Nessun collegamento a un'entità auto —
/// è solo un'immagine persistita localmente sul device.
class _CarPhotoCard extends StatefulWidget {
  const _CarPhotoCard();

  @override
  State<_CarPhotoCard> createState() => _CarPhotoCardState();
}

class _CarPhotoCardState extends State<_CarPhotoCard> {
  static const _prefsKey = 'home_car_photo_path';

  File? _photo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPhoto();
  }

  Future<void> _loadSavedPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_prefsKey);
    if (path != null && await File(path).exists()) {
      setState(() => _photo = File(path));
    }
    setState(() => _loading = false);
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    final docsDir = await getApplicationDocumentsDirectory();
    final savedPath =
        '${docsDir.path}/home_car_photo${_extensionOf(picked.path)}';
    final saved = await File(picked.path).copy(savedPath);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, saved.path);

    setState(() => _photo = saved);
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    return dot == -1 ? '.jpg' : path.substring(dot);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _loading ? null : _pickPhoto,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          color: AppColors.surfaceElevated,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_photo != null)
              Image.file(_photo!, fit: BoxFit.cover)
            else
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_a_photo_rounded,
                        size: 32, color: AppColors.textDisabled),
                    SizedBox(height: 8),
                    Text('Aggiungi la foto della tua auto',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            if (_photo != null)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
