import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/draggable_sheet_scaffold.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/data/car_catalog.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../rival/domain/entities/mascot.dart';
import '../../../rival/presentation/widgets/mascot_avatar.dart';

const _countries = [
  ('IT', '🇮🇹 Italia'),
  ('DE', '🇩🇪 Germania'),
  ('US', '🇺🇸 Stati Uniti'),
  ('BR', '🇧🇷 Brasile'),
  ('FR', '🇫🇷 Francia'),
  ('ES', '🇪🇸 Spagna'),
  ('GB', '🇬🇧 Regno Unito'),
];

const _accentColors = [
  ('Corallo', '#ff2d55', Color(0xFFFF2D55)),
  ('Turchese', '#35e0ff', Color(0xFF35E0FF)),
  ('Giallo', '#ffc93c', Color(0xFFFFC93C)),
  ('Viola', '#c23dff', Color(0xFFC23DFF)),
  ('Blu', '#2f6bff', Color(0xFF2F6BFF)),
];

/// Impostazioni: profilo, veicolo, paese, colore accento, account.
/// Costruita da zero (prima era un placeholder) secondo Guida.dc.html
/// righe 671-718. Il colore accento viene solo salvato per ora — non
/// ricolora ancora l'intera UI (fuori scope, richiederebbe ricablare
/// ogni schermata a un accento dinamico).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _editUsername(BuildContext context, WidgetRef ref, String userId,
      String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1522),
        title: Text('Username',
            style: AppType.text(
                fontWeight: FontWeight.w800, color: AppColor.ink)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: AppColor.ink),
          decoration: const InputDecoration(hintText: 'Minimo 3 caratteri'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Salva')),
        ],
      ),
    );
    if (result != null && result.length >= 3 && result != current) {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfileSettings(userId: userId, username: result);
    }
  }

  Future<void> _editVehicle(BuildContext context, WidgetRef ref, String userId,
      AppUser profile) async {
    final brand = await DraggableSheetScaffold.show<String>(
      context,
      title: 'Marca',
      builder: (ctx) => SheetOptionPicker<String>(
        selected: profile.vehicleBrand,
        options: [
          for (final b in carCatalog.keys) SheetOption(value: b, label: b),
        ],
        onSelect: (_) {},
      ),
    );
    if (brand == null || !context.mounted) return;
    final model = await DraggableSheetScaffold.show<String>(
      context,
      title: 'Modello',
      builder: (ctx) => SheetOptionPicker<String>(
        selected: null,
        options: [
          for (final m in carCatalog[brand] ?? const <String>[])
            SheetOption(value: m, label: m),
        ],
        onSelect: (_) {},
      ),
    );
    if (model == null) return;
    await ref.read(authControllerProvider.notifier).updateVehicle(
          userId: userId,
          brand: brand,
          model: model,
        );
  }

  Future<void> _editCountry(
      BuildContext context, WidgetRef ref, String userId) async {
    final selected = await DraggableSheetScaffold.show<String>(
      context,
      title: 'Paese',
      builder: (ctx) => SheetOptionPicker<String>(
        selected: null,
        options: [
          for (final c in _countries) SheetOption(value: c.$1, label: c.$2),
        ],
        onSelect: (_) {},
      ),
    );
    if (selected != null) {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfileSettings(userId: userId, country: selected);
    }
  }

  Future<void> _editAccentColor(
      BuildContext context, WidgetRef ref, String userId) async {
    final selected = await DraggableSheetScaffold.show<String>(
      context,
      title: 'Colore accento',
      builder: (ctx) => SheetOptionPicker<String>(
        selected: null,
        options: [
          for (final c in _accentColors)
            SheetOption(value: c.$2, label: c.$1, swatch: c.$3),
        ],
        onSelect: (_) {},
      ),
    );
    if (selected != null) {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfileSettings(userId: userId, accentColor: selected);
    }
  }

  Future<void> _editMascot(BuildContext context, WidgetRef ref, String userId,
      String? currentMascotId) async {
    final selected = await DraggableSheetScaffold.show<String>(
      context,
      title: 'Mascotte',
      builder: (ctx) => SheetOptionPicker<String>(
        selected: currentMascotId,
        options: [
          for (final m in kMascotCatalog)
            SheetOption(
              value: m.id,
              label: m.name,
              leading: MascotAvatar(mascot: m, size: 36),
            ),
        ],
        onSelect: (_) {},
      ),
    );
    if (selected != null) {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfileSettings(userId: userId, mascotId: selected);
    }
  }

  Future<void> _changeAvatar(
      BuildContext context, WidgetRef ref, String userId) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF0E1522),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: AppColor.ink),
              title: Text('Scatta una foto',
                  style: AppType.text(color: AppColor.ink)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColor.ink),
              title: Text('Scegli dalla galleria',
                  style: AppType.text(color: AppColor.ink)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return;

    final Uint8List bytes = await picked.readAsBytes();
    final extension = picked.path.contains('.')
        ? '.${picked.path.split('.').last}'
        : '.jpg';
    if (!context.mounted) return;

    await ref.read(authControllerProvider.notifier).updateAvatar(
          userId: userId,
          photoBytes: bytes,
          photoExtension: extension,
        );

    if (!context.mounted) return;
    final result = ref.read(authControllerProvider);
    if (result.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossibile aggiornare la foto profilo: '
              '${result.error}'),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColor.void_,
      body: SafeArea(
        child: profile == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColor.cyan))
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                children: [
                  Row(
                    children: [
                      _RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => context.pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Impostazioni',
                    style: AppType.text(
                      fontWeight: FontWeight.w900,
                      fontSize: 42,
                      color: AppColor.ink,
                    ),
                  ),
                  const SizedBox(height: 26),
                  _ProfileCard(
                    profile: profile,
                    isUploadingAvatar: isLoading,
                    onTapAvatar: isLoading
                        ? null
                        : () => _changeAvatar(context, ref, profile.id),
                  ),
                  const SizedBox(height: 22),
                  _GroupCard(
                    children: [
                      _SettingsRow(
                        iconBg: const Color(0xFF1E5BD6),
                        icon: Icons.person_rounded,
                        label: 'Username',
                        value: '@${profile.username}',
                        onTap: isLoading
                            ? null
                            : () => _editUsername(
                                context, ref, profile.id, profile.username),
                      ),
                      _SettingsRow(
                        iconBg: const Color(0xFF6B21A8),
                        iconColor: const Color(0xFFE879F9),
                        icon: Icons.directions_car_rounded,
                        label: 'Veicoli',
                        value: profile.vehicleBrand == null
                            ? 'Nessuno'
                            : '${profile.vehicleBrand} ${profile.vehicleModel ?? ''}'
                                .trim(),
                        onTap: isLoading
                            ? null
                            : () =>
                                _editVehicle(context, ref, profile.id, profile),
                      ),
                      _SettingsRow(
                        iconBg: const Color(0xFF7C4A10),
                        iconColor: const Color(0xFFF59E0B),
                        icon: Icons.public_rounded,
                        label: 'Paese',
                        value: _countries
                            .firstWhere(
                              (c) => c.$1 == profile.country,
                              orElse: () => ('', 'Non impostato'),
                            )
                            .$2,
                        onTap: isLoading
                            ? null
                            : () => _editCountry(context, ref, profile.id),
                      ),
                      _SettingsRow(
                        iconBg: const Color(0xFF6B2A24),
                        iconColor: const Color(0xFFF87171),
                        icon: Icons.palette_rounded,
                        label: 'Colore',
                        value: _accentColors
                            .firstWhere(
                              (c) => c.$2 == profile.accentColor,
                              orElse: () => _accentColors.first,
                            )
                            .$1,
                        swatch: _accentColors
                            .firstWhere(
                              (c) => c.$2 == profile.accentColor,
                              orElse: () => _accentColors.first,
                            )
                            .$3,
                        onTap: isLoading
                            ? null
                            : () => _editAccentColor(context, ref, profile.id),
                      ),
                      _SettingsRow(
                        iconBg: const Color(0xFF123B2E),
                        iconColor: const Color(0xFF4ADE80),
                        icon: Icons.face_retouching_natural_rounded,
                        label: 'Mascotte',
                        value: kMascotCatalog
                            .firstWhere((m) => m.id == profile.mascotId,
                                orElse: () => kMascotCatalog.first)
                            .name,
                        swatch: kMascotCatalog
                            .firstWhere((m) => m.id == profile.mascotId,
                                orElse: () => kMascotCatalog.first)
                            .accentColor,
                        onTap: isLoading
                            ? null
                            : () => _editMascot(
                                context, ref, profile.id, profile.mascotId),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _GroupCard(
                    children: [
                      _SettingsRow(
                        iconBg: const Color(0xFF14431F),
                        iconColor: const Color(0xFF4ADE80),
                        icon: Icons.verified_user_rounded,
                        label: 'Account',
                        value: 'Connesso',
                        showChevron: false,
                      ),
                      _SettingsRow(
                        iconBg: const Color(0xFF5A1E1E),
                        iconColor: const Color(0xFFF87171),
                        icon: Icons.logout_rounded,
                        label: 'Esci',
                        value: '',
                        onTap: isLoading
                            ? null
                            : () => ref
                                .read(authControllerProvider.notifier)
                                .signOut(),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final AppUser profile;
  final bool isUploadingAvatar;
  final VoidCallback? onTapAvatar;
  const _ProfileCard({
    required this.profile,
    this.isUploadingAvatar = false,
    this.onTapAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accentColors
        .firstWhere(
          (c) => c.$2 == profile.accentColor,
          orElse: () => _accentColors.first,
        )
        .$3;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xDB141B30), Color(0xEB0A0E18)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1AA0C8FF)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTapAvatar,
            child: Stack(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: profile.avatarUrl != null
                      ? ClipOval(
                          child: Image.network(profile.avatarUrl!,
                              fit: BoxFit.cover))
                      : Icon(Icons.person_rounded, color: accent, size: 44),
                ),
                if (isUploadingAvatar)
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: Color(0x99000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: AppColor.cyan),
                      ),
                    ),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF1C1C1C), width: 3),
                    ),
                    child: const Icon(Icons.photo_camera_rounded,
                        size: 14, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@${profile.username}',
                    style: AppType.text(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: AppColor.ink)),
                const SizedBox(height: 4),
                Text('Tocca la foto per cambiarla',
                    style: AppType.text(
                        fontSize: 15, color: AppColor.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final List<Widget> children;
  const _GroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xDB141B30), Color(0xEB0A0E18)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1AA0C8FF)),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final Color iconBg;
  final Color iconColor;
  final IconData icon;
  final String label;
  final String value;
  final Color? swatch;
  final bool showChevron;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.iconBg,
    this.iconColor = Colors.white,
    required this.icon,
    required this.label,
    required this.value,
    this.swatch,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: AppType.text(
                      fontWeight: FontWeight.w600,
                      fontSize: 19,
                      color: AppColor.ink)),
            ),
            if (swatch != null) ...[
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: swatch,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 10),
            ],
            if (value.isNotEmpty)
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.text(
                      fontSize: 15, color: AppColor.inkMuted),
                ),
              ),
            if (showChevron && onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColor.inkMuted),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF0131A2D),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: AppColor.ink, size: 22),
        ),
      ),
    );
  }
}
