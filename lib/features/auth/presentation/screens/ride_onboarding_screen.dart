import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/car_glyph_icon.dart';
import '../../../../core/widgets/draggable_sheet_scaffold.dart';
import '../../../../core/widgets/neon_cta_button.dart';
import '../data/car_catalog.dart';
import '../providers/auth_provider.dart';

/// Onboarding "il tuo ride": scelta di marca/modello del veicolo
/// principale, mostrata una volta dopo la registrazione (gate nel
/// router — vedi app_router.dart). Vedi Guida.dc.html righe 51-99.
class RideOnboardingScreen extends ConsumerStatefulWidget {
  const RideOnboardingScreen({super.key});

  @override
  ConsumerState<RideOnboardingScreen> createState() =>
      _RideOnboardingScreenState();
}

class _RideOnboardingScreenState extends ConsumerState<RideOnboardingScreen> {
  String? _brand;
  String? _model;

  Future<void> _pickBrand() async {
    final selected = await DraggableSheetScaffold.show<String>(
      context,
      title: 'Marca',
      builder: (ctx) => SheetOptionPicker<String>(
        selected: _brand,
        options: [
          for (final b in carCatalog.keys) SheetOption(value: b, label: b),
        ],
        onSelect: (v) {},
      ),
    );
    if (selected != null) {
      setState(() {
        _brand = selected;
        _model = null;
      });
    }
  }

  Future<void> _pickModel() async {
    final brand = _brand;
    if (brand == null) return;
    final selected = await DraggableSheetScaffold.show<String>(
      context,
      title: 'Modello',
      builder: (ctx) => SheetOptionPicker<String>(
        selected: _model,
        options: [
          for (final m in carCatalog[brand] ?? const <String>[])
            SheetOption(value: m, label: m),
        ],
        onSelect: (v) {},
      ),
    );
    if (selected != null) setState(() => _model = selected);
  }

  Future<void> _pickCustom() async {
    final brandCtrl = TextEditingController(text: _brand ?? '');
    final modelCtrl = TextEditingController(text: _model ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1522),
        title: Text('Il tuo modello',
            style: AppType.text(
                fontWeight: FontWeight.w800, color: AppColor.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: brandCtrl,
              style: const TextStyle(color: AppColor.ink),
              decoration: const InputDecoration(labelText: 'Marca'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: modelCtrl,
              style: const TextStyle(color: AppColor.ink),
              decoration: const InputDecoration(labelText: 'Modello'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salva')),
        ],
      ),
    );
    if (result == true &&
        brandCtrl.text.trim().isNotEmpty &&
        modelCtrl.text.trim().isNotEmpty) {
      setState(() {
        _brand = brandCtrl.text.trim();
        _model = modelCtrl.text.trim();
      });
    }
  }

  Future<void> _continue() async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    final brand = _brand;
    final model = _model;
    if (userId == null || brand == null || model == null) return;
    await ref.read(authControllerProvider.notifier).updateVehicle(
          userId: userId,
          brand: brand,
          model: model,
        );
    // Il router osserva myProfileProvider (stream realtime sulla riga
    // profiles): appena vehicle_brand è valorizzato, il redirect ci porta
    // via da qui automaticamente — nessuna navigazione esplicita.
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;
    final canContinue = _brand != null && _model != null && !isLoading;

    return Scaffold(
      backgroundColor: AppColor.void_,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Scegli il tuo ride principale',
                textAlign: TextAlign.center,
                style: AppType.text(
                  fontWeight: FontWeight.w900,
                  fontSize: 30,
                  color: AppColor.ink,
                ),
              ).animate().fadeIn().slideY(begin: 0.1, end: 0),
              const SizedBox(height: 12),
              Text(
                "Scegli l'auto che guidi di più",
                textAlign: TextAlign.center,
                style: AppType.text(
                  fontSize: 16,
                  color: AppColor.inkMuted,
                ),
              ),
              const Spacer(),
              Center(
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColor.cyan, width: 6),
                  ),
                  child: const Center(
                    child: CarGlyphIcon(size: 130, color: Color(0xFF1D5C58)),
                  ),
                ),
              ),
              const Spacer(),
              _RideSelectButton(
                label: _brand ?? 'Marca',
                filled: _brand != null,
                onTap: _pickBrand,
              ),
              const SizedBox(height: 14),
              _RideSelectButton(
                label: _model ?? 'Modello',
                filled: _model != null,
                onTap: _brand == null ? null : _pickModel,
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: _pickCustom,
                  style: TextButton.styleFrom(
                      foregroundColor: AppColor.inkMuted),
                  child: const Text(
                    'non trovi il tuo modello?',
                    style: TextStyle(decoration: TextDecoration.underline),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              NeonCtaButton(
                label: 'Continua',
                onPressed: canContinue ? _continue : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RideSelectButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _RideSelectButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColor.cyan, width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppType.text(
                  fontWeight: FontWeight.w600,
                  fontSize: 19,
                  color: filled
                      ? const Color(0xFF111111)
                      : const Color(0xFF68788F),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF68788F)),
            ],
          ),
        ),
      ),
    );
  }
}
