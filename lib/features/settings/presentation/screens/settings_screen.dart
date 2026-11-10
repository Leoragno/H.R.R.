import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/accent_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';
import '../../../../core/widgets/draggable_sheet_scaffold.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/data/car_catalog.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/presentation/widgets/whats_new_overlay.dart';
import '../../../missions/domain/entities/drive_pass.dart';
import '../../../missions/presentation/providers/economy_providers.dart';
import '../../../radar/presentation/providers/radar_provider.dart';
import '../../../rival/domain/entities/mascot.dart';
import '../../../rival/presentation/widgets/mascot_avatar.dart';

const _countries = [
  ('IT', 'Italia'),
  ('DE', 'Germania'),
  ('US', 'Stati Uniti'),
  ('BR', 'Brasile'),
  ('FR', 'Francia'),
  ('ES', 'Spagna'),
  ('GB', 'Regno Unito'),
];

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// IMPOSTAZIONI (HEAT, handoff §23): PROFILO (foto, username in linea,
/// veicolo, paese, colore accento, mascotte), GUIDA (notte automatica,
/// radar velox), ACCOUNT (connesso, esci).
///
/// Il colore accento è quello vero dell'app: [accentProvider] lo applica
/// subito (la radice si ricostruisce) e lo salva in locale; si copia anche
/// in `profiles.accent_color`. I colori bloccati arrivano con il pass di
/// guida (fase economia XP).
///
/// AIUTO › rivedi le novità (overlay della Home).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _editingUser = false;
  final _userCtrl = TextEditingController();

  @override
  void dispose() {
    _userCtrl.dispose();
    super.dispose();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _saveUsername(AppUser profile) async {
    final v = _userCtrl.text.trim();
    if (v.length < 3) {
      _snack('lo username deve avere almeno 3 caratteri.');
      return;
    }
    setState(() => _editingUser = false);
    if (v == profile.username) return;
    await ref
        .read(authControllerProvider.notifier)
        .updateProfileSettings(userId: profile.id, username: v);
    if (!mounted) return;
    if (ref.read(authControllerProvider).hasError) {
      _snack('username non salvato. forse è già preso.');
    }
  }

  Future<void> _editVehicle(AppUser profile) async {
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
    if (brand == null || !mounted) return;
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
          userId: profile.id,
          brand: brand,
          model: model,
        );
  }

  Future<void> _editCountry(AppUser profile) async {
    final selected = await DraggableSheetScaffold.show<String>(
      context,
      title: 'Paese',
      builder: (ctx) => SheetOptionPicker<String>(
        selected: profile.country,
        options: [
          for (final c in _countries) SheetOption(value: c.$1, label: c.$2),
        ],
        onSelect: (_) {},
      ),
    );
    if (selected != null) {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfileSettings(userId: profile.id, country: selected);
    }
  }

  Future<void> _editMascot(AppUser profile) async {
    final selected = await DraggableSheetScaffold.show<String>(
      context,
      title: 'Mascotte',
      builder: (ctx) => SheetOptionPicker<String>(
        selected: profile.mascotId,
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
          .updateProfileSettings(userId: profile.id, mascotId: selected);
    }
  }

  Future<void> _pickAccent(AppUser profile, HeatAccent a) async {
    if (_accentLocked(a, ref.read(unlocksProvider).valueOrNull)) {
      _snack('${a.label.toLowerCase()} si sblocca con il pass di guida.');
      return;
    }
    if (a == ref.read(accentProvider)) return;
    final auth = ref.read(authControllerProvider.notifier);
    // Prima il profilo: dopo select() l'intera app si ricostruisce.
    await auth.updateProfileSettings(
        userId: profile.id, accentColor: _hex(a.color));
    await ref.read(accentProvider.notifier).select(a);
  }

  Future<void> _changeAvatar(AppUser profile) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColor.surfaceHigh,
      shape: const RoundedRectangleBorder(),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (icon, label, src) in [
              (
                Icons.photo_camera_rounded,
                'scatta una foto',
                ImageSource.camera
              ),
              (
                Icons.photo_library_rounded,
                'scegli dalla galleria',
                ImageSource.gallery
              ),
            ])
              ListTile(
                leading: Icon(icon, color: AppColor.inkMuted),
                title: Text(label,
                    style: AppType.text(fontSize: 15, color: AppColor.ink)),
                onTap: () => Navigator.pop(ctx, src),
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
    final extension =
        picked.path.contains('.') ? '.${picked.path.split('.').last}' : '.jpg';
    if (!mounted) return;

    await ref.read(authControllerProvider.notifier).updateAvatar(
          userId: profile.id,
          photoBytes: bytes,
          photoExtension: extension,
        );
    if (!mounted) return;
    if (ref.read(authControllerProvider).hasError) {
      _snack('foto non aggiornata. riprova.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final busy = ref.watch(authControllerProvider).isLoading;
    final accent = ref.watch(accentProvider);
    final radarOn = ref.watch(radarModeControllerProvider);

    return Scaffold(
      backgroundColor: AppColor.base,
      body: HeatBackground(
        glow: false,
        child: SafeArea(
          bottom: false,
          child: profile == null
              ? const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColor.inkMuted),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 30),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go(AppRoutes.profile),
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: AppColor.ink),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      child: ScreenTitle('Impostazioni', fontSize: 44),
                    ),
                    const _Group('Profilo'),
                    _ProfileTile(
                      profile: profile,
                      busy: busy,
                      onTap: busy ? null : () => _changeAvatar(profile),
                    ),
                    const SizedBox(height: 2),
                    _Rows(children: [
                      _usernameRow(profile, busy),
                      _Row(
                        icon: Icons.directions_car_rounded,
                        label: 'Veicoli',
                        value: profile.vehicleBrand == null
                            ? 'nessuno'
                            : (profile.vehicleModel ?? profile.vehicleBrand!),
                        onTap: busy ? null : () => _editVehicle(profile),
                      ),
                      _Row(
                        icon: Icons.flag_rounded,
                        label: 'Paese',
                        value: _countries
                            .firstWhere((c) => c.$1 == profile.country,
                                orElse: () => ('', 'non impostato'))
                            .$2,
                        onTap: busy ? null : () => _editCountry(profile),
                      ),
                      _Row(
                        icon: Icons.palette_rounded,
                        label: 'Colore accento',
                        trailing: _AccentSwatches(
                          selected: accent,
                          unlocks: ref.watch(unlocksProvider).valueOrNull,
                          onPick: busy ? null : (a) => _pickAccent(profile, a),
                        ),
                      ),
                      _mascotRow(profile, busy),
                    ]),
                    const _Group('Guida'),
                    _Rows(children: [
                      const _Row(
                        icon: Icons.dark_mode_rounded,
                        label: 'Modalità notte',
                        sub: 'automatica dalle 22 alle 6 · HEAT e XP in più',
                      ),
                      _Row(
                        icon: Icons.radar_rounded,
                        label: 'Rilevamento velox e pattuglie',
                        sub: 'dati OSM, Waze e community',
                        trailing: _SkewToggle(on: radarOn),
                        onTap: () => ref
                            .read(radarModeControllerProvider.notifier)
                            .toggle(),
                      ),
                    ]),
                    const _Group('Aiuto'),
                    _Rows(children: [
                      _Row(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Rivedi le novità',
                        sub: 'il tour di HRR 2.0 in 7 schermate',
                        onTap: () => showWhatsNew(context),
                      ),
                    ]),
                    const _Group('Account'),
                    _Rows(children: [
                      const _Row(
                        icon: Icons.verified_user_rounded,
                        iconColor: AppColor.success,
                        label: 'Connesso',
                      ),
                      _Row(
                        icon: Icons.logout_rounded,
                        iconColor: AppColor.danger,
                        label: 'Esci',
                        labelColor: AppColor.danger,
                        onTap: busy
                            ? null
                            : () => ref
                                .read(authControllerProvider.notifier)
                                .signOut(),
                      ),
                    ]),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _usernameRow(AppUser profile, bool busy) {
    if (!_editingUser) {
      return _Row(
        icon: Icons.person_rounded,
        label: 'Username',
        value: profile.username,
        valueIcon: Icons.edit_rounded,
        onTap: busy
            ? null
            : () => setState(() {
                  _userCtrl.text = profile.username;
                  _editingUser = true;
                }),
      );
    }
    // In modifica il campo prende il posto dell'etichetta: così entra
    // anche sui telefoni stretti.
    return Container(
      height: 54,
      padding: const EdgeInsets.only(left: 16, right: 9),
      color: AppColor.surface,
      child: Row(
        children: [
          const Icon(Icons.person_rounded, size: 20, color: AppColor.inkMuted),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _userCtrl,
                autofocus: true,
                maxLength: 24,
                onSubmitted: (_) => _saveUsername(profile),
                style: AppType.text(fontSize: 14, color: AppColor.ink),
                cursorColor: AppColor.ink,
                decoration: const InputDecoration(
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: AppColor.base,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColor.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColor.ink),
                  ),
                ),
              ),
            ),
          ),
          _TextAction('salva', AppColor.ink, () => _saveUsername(profile)),
          _TextAction('annulla', AppColor.inkMuted,
              () => setState(() => _editingUser = false)),
        ],
      ),
    );
  }

  Widget _mascotRow(AppUser profile, bool busy) {
    final m = kMascotCatalog.firstWhere((m) => m.id == profile.mascotId,
        orElse: () => kMascotCatalog.first);
    return _Row(
      icon: Icons.sports_motorsports_rounded,
      label: 'Mascotte',
      value: m.name,
      valueColor: m.accentColor,
      onTap: busy ? null : () => _editMascot(profile),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
        child: SectionLabel(text),
      );
}

class _Rows extends StatelessWidget {
  const _Rows({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, c) in children.indexed) ...[
              if (i > 0) const SizedBox(height: 2),
              c,
            ],
          ],
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    this.iconColor = AppColor.inkMuted,
    this.labelColor = AppColor.ink,
    this.sub,
    this.value,
    this.valueColor,
    this.valueIcon,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;
  final String? sub;
  final String? value;
  final Color? valueColor;
  final IconData? valueIcon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      constraints: BoxConstraints(minHeight: sub == null ? 54 : 60),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColor.surface,
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.text(fontSize: 15, color: labelColor)),
                if (sub != null)
                  Text(sub!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppType.text(fontSize: 12, color: AppColor.inkMuted)),
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.text(
                  fontSize: 14,
                  fontWeight:
                      valueColor != null ? FontWeight.w700 : FontWeight.w400,
                  color: valueColor ?? AppColor.inkMuted,
                ),
              ),
            ),
          ],
          if (valueIcon != null) ...[
            const SizedBox(width: 4),
            Icon(valueIcon, size: 18, color: AppColor.inkMuted),
          ] else if (onTap != null && trailing == null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColor.inkFaint),
          ],
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
    return onTap == null ? row : HeatPressable(onTap: onTap, child: row);
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction(this.label, this.color, this.onTap);
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
          child: Text(label,
              style: AppType.text(
                  fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ),
      );
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.profile,
    required this.busy,
    required this.onTap,
  });

  final AppUser profile;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mascot = kMascotCatalog.firstWhere((m) => m.id == profile.mascotId,
        orElse: () => kMascotCatalog.first);
    final url = profile.avatarUrl;
    final face = url != null
        ? Image.network(url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Image.asset('assets/faces/${mascot.id}.png', fit: BoxFit.cover))
        : Image.asset('assets/faces/${mascot.id}.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.person_rounded, color: AppColor.inkFaint));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: HeatPanel(
        onTap: onTap,
        shape: const SlantBorder.all(0),
        color: AppColor.surface,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipPath(
              clipper: const ShapeBorderClipper(
                  shape: SlantBorder(left: 10, right: 10)),
              child: Container(
                width: 64,
                height: 64,
                color: mascot.accentColor.withValues(alpha: .15),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    face,
                    if (busy)
                      const ColoredBox(
                        color: Color(0x99000000),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: AppColor.ink),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('@${profile.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.text(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColor.ink)),
                  const SizedBox(height: 2),
                  Text('tocca la foto per cambiarla',
                      style:
                          AppType.text(fontSize: 13, color: AppColor.inkMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// I sette accenti come piccoli parallelogrammi: quello attivo ha il
/// bordo chiaro, i bloccati sono spenti con il lucchetto.
bool _accentLocked(HeatAccent a, Unlocks? unlocks) =>
    a.locked && !(unlocks?.accent(a.name) ?? false);

class _AccentSwatches extends StatelessWidget {
  const _AccentSwatches({
    required this.selected,
    required this.unlocks,
    required this.onPick,
  });

  final HeatAccent selected;

  /// Sblocchi del pass di guida (null = non ancora caricati).
  final Unlocks? unlocks;
  final ValueChanged<HeatAccent>? onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final a in HeatAccent.values)
          Semantics(
            button: true,
            selected: a == selected,
            label: a.label,
            child: GestureDetector(
              key: ValueKey('accent_${a.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: onPick == null ? null : () => onPick!(a),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: Opacity(
                  opacity: _accentLocked(a, unlocks) ? .35 : 1,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.skewX(-.21),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: a.color,
                        border: Border.all(
                          width: 2,
                          color: a == selected
                              ? AppColor.ink
                              : const Color(0x00000000),
                        ),
                      ),
                      child: _accentLocked(a, unlocks)
                          ? const Icon(Icons.lock_rounded,
                              size: 12, color: AppColor.onAccent)
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Interruttore inclinato HEAT; acceso = accento (unico della schermata).
class _SkewToggle extends StatelessWidget {
  const _SkewToggle({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.skewX(-.21),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 44,
        height: 24,
        color: on ? AppColor.accent : AppColor.line,
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        padding: const EdgeInsets.all(2),
        child: Container(width: 20, height: 20, color: AppColor.ink),
      ),
    );
  }
}
