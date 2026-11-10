import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';
import '../../../../core/widgets/car_glyph_icon.dart';
import '../../../../core/widgets/draggable_sheet_scaffold.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../data/car_catalog.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';

/// Onboarding "il tuo ride" (HEAT, handoff §4 · PASSO 2 DI 3): marca e
/// modello del veicolo principale, mostrata una volta dopo la
/// registrazione (gate nel router — vedi app_router.dart).
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
      builder: (ctx) => Dialog(
        backgroundColor: AppColor.surfaceHigh,
        shape: const ChamferBorder(cut: 16, bottomLeft: true),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('IL TUO MODELLO',
                  style: AppType.display(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColor.ink)),
              const SizedBox(height: 14),
              AuthTextField(placeholder: 'marca', controller: brandCtrl),
              const SizedBox(height: 8),
              AuthTextField(placeholder: 'modello', controller: modelCtrl),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('annulla',
                        style: AppType.text(
                            fontSize: 14, color: AppColor.inkMuted)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('salva',
                        style: AppType.text(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColor.ink)),
                  ),
                ],
              ),
            ],
          ),
        ),
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
      backgroundColor: AppColor.base,
      body: HeatBackground(
        glow: false,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AuthStepHeader(
                        step: 'PASSO 2 DI 3',
                        title: 'Il tuo\nride',
                        subtitle: "scegli l'auto che guidi di più.",
                      ),
                      const SizedBox(height: 22),
                      Center(child: _RidePreview(brand: _brand, model: _model)),
                      const SizedBox(height: 22),
                      _RideSelect(
                        label: 'MARCA',
                        value: _brand,
                        placeholder: 'scegli la marca',
                        onTap: isLoading ? null : _pickBrand,
                      ),
                      const SizedBox(height: 10),
                      _RideSelect(
                        label: 'MODELLO',
                        value: _model,
                        placeholder: _brand == null
                            ? 'prima la marca'
                            : 'scegli il modello',
                        onTap: _brand == null || isLoading ? null : _pickModel,
                      ),
                      Center(
                        child: TextButton(
                          onPressed: isLoading ? null : _pickCustom,
                          child: Text(
                            'non trovi il tuo modello?',
                            style: AppType.text(
                              fontSize: 13,
                              color: AppColor.inkMuted,
                            ).copyWith(decoration: TextDecoration.underline),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 12),
                      HeatButton(
                        label: isLoading ? 'UN ATTIMO…' : 'CONTINUA',
                        icon: null,
                        height: 58,
                        fontSize: 24,
                        onPressed: canContinue ? _continue : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Riquadro smussato con marca e modello scelti (al posto del render).
class _RidePreview extends StatelessWidget {
  const _RidePreview({required this.brand, required this.model});

  final String? brand;
  final String? model;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 170,
      decoration: const ShapeDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [Color(0xFF231F2E), AppColor.surface],
          stops: [0, .7],
        ),
        shape: ChamferBorder(cut: 22, bottomLeft: true),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(
            right: 14,
            bottom: 10,
            child: CarGlyphIcon(size: 70, color: Color(0x14F4F1FA)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text((brand ?? 'marca').toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.display(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        italic: false,
                        letterSpacing: 2,
                        color: AppColor.inkMuted)),
                Text((model ?? '—').toUpperCase(),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.display(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: .95,
                        color:
                            model == null ? AppColor.inkFaint : AppColor.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RideSelect extends StatelessWidget {
  const _RideSelect({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label,
            style: AppType.display(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                italic: false,
                letterSpacing: 2,
                color: AppColor.inkMuted)),
        const SizedBox(height: 6),
        HeatPressable(
          onTap: onTap,
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: const BoxDecoration(
              color: AppColor.surface,
              border: Border.fromBorderSide(BorderSide(color: AppColor.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value ?? placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.text(
                        fontSize: 15,
                        color:
                            value == null ? AppColor.inkFaint : AppColor.ink),
                  ),
                ),
                Icon(Icons.expand_more_rounded,
                    color:
                        onTap == null ? AppColor.inkFaint : AppColor.inkMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
