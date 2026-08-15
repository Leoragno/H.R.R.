import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Bottom sheet ricorrente nel design "Guida": handle di trascinamento,
/// header opzionale con titolo + chiusura, sfondo scuro a gradiente con
/// angoli superiori arrotondati. Lo slide-up/scrim li fornisce già
/// `showModalBottomSheet` (isScrollControlled + backgroundColor
/// trasparente), qui costruiamo solo il contenuto visivo.
class DraggableSheetScaffold extends StatelessWidget {
  final String? title;
  final Widget child;
  final bool showCloseButton;

  const DraggableSheetScaffold({
    super.key,
    this.title,
    required this.child,
    this.showCloseButton = true,
  });

  /// Apre il contenuto come modal bottom sheet con lo stile del design.
  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    required WidgetBuilder builder,
    bool showCloseButton = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableSheetScaffold(
        title: title,
        showCloseButton: showCloseButton,
        child: builder(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColor.surfaceHigh.withValues(alpha: 0.96),
              AppColor.void_.withValues(alpha: 0.98),
            ],
          ),
          border: const Border(
            top: BorderSide(color: AppColor.line, width: 1),
            left: BorderSide(color: AppColor.line, width: 1),
            right: BorderSide(color: AppColor.line, width: 1),
          ),
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 96,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColor.line,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              if (title != null) ...[
                const SizedBox(height: AppSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: AppType.text(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          color: AppColor.ink,
                        ),
                      ),
                    ),
                    if (showCloseButton)
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded,
                            color: AppColor.inkMuted),
                      ),
                  ],
                ),
              ] else
                const SizedBox(height: AppSpace.md),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class SheetOption<T> {
  final T value;
  final String label;
  final Color? swatch;
  final String? emoji;
  final Widget? leading;

  const SheetOption({
    required this.value,
    required this.label,
    this.swatch,
    this.emoji,
    this.leading,
  });
}

/// Picker generico a lista con segno di spunta sull'opzione selezionata —
/// il pattern "setSheet" del design, riusato da onboarding veicolo,
/// impostazioni e filtro metrica in classifica.
class SheetOptionPicker<T> extends StatelessWidget {
  final List<SheetOption<T>> options;
  final T? selected;
  final ValueChanged<T> onSelect;

  const SheetOptionPicker({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: options.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpace.sm),
      itemBuilder: (context, i) {
        final opt = options[i];
        final isSelected = opt.value == selected;
        return Material(
          color: isSelected
              ? AppColor.surfaceHigh.withValues(alpha: 0.94)
              : AppColor.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: () {
              onSelect(opt.value);
              Navigator.of(context).pop(opt.value);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.md, vertical: AppSpace.md),
              child: Row(
                children: [
                  if (opt.leading != null) ...[
                    opt.leading!,
                    const SizedBox(width: 14),
                  ] else if (opt.swatch != null) ...[
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: opt.swatch,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 14),
                  ] else if (opt.emoji != null) ...[
                    Text(opt.emoji!, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Text(
                      opt.label,
                      style: AppType.text(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: AppColor.ink,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_rounded, color: AppColor.cyan),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
