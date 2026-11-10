import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/heat_shapes.dart';

/// Campo HEAT delle schermate di accesso: parallelogramma 54 px, fondo
/// pannello, bordo linea che diventa chiaro al focus. Niente errori sotto
/// il campo: la schermata mostra un'unica riga rossa ([AuthErrorRow]).
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.placeholder,
    required this.controller,
    this.obscureText = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.onChanged,
  });

  final String placeholder;
  final TextEditingController controller;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: ShapeDecoration(
        color: AppColor.surface,
        shape: SlantBorder(
          left: 10,
          right: 10,
          side:
              BorderSide(color: _focus.hasFocus ? AppColor.ink : AppColor.line),
        ),
      ),
      padding: const EdgeInsets.only(left: 20, right: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              onSubmitted: widget.onSubmitted,
              onChanged: widget.onChanged,
              autofillHints: widget.autofillHints,
              autocorrect: false,
              enableSuggestions: !widget.obscureText,
              cursorColor: AppColor.ink,
              style: AppType.text(fontSize: 15, color: AppColor.ink),
              decoration: InputDecoration(
                hintText: widget.placeholder,
                hintStyle: AppType.text(fontSize: 15, color: AppColor.inkFaint),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (widget.onToggleObscure != null)
            IconButton(
              onPressed: widget.onToggleObscure,
              tooltip: widget.obscureText ? 'mostra' : 'nascondi',
              icon: Icon(
                widget.obscureText
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 20,
                color: AppColor.inkFaint,
              ),
            ),
        ],
      ),
    );
  }
}

/// Riga d'errore unica sotto i campi (rosso, icona + frase).
class AuthErrorRow extends StatelessWidget {
  const AuthErrorRow(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.error_rounded, size: 16, color: AppColor.danger),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(message,
              style: AppType.text(fontSize: 13, color: AppColor.danger)),
        ),
      ],
    );
  }
}

/// Bottone secondario a parallelogramma (Google / Apple).
class AuthSocialButton extends StatelessWidget {
  const AuthSocialButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.surface,
      shape: const SlantBorder(
          left: 10, right: 10, side: BorderSide(color: AppColor.line)),
      child: InkWell(
        onTap: onPressed,
        customBorder: const SlantBorder(left: 10, right: 10),
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 8),
              Text(label,
                  style: AppType.text(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColor.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "PASSO N DI 3" + titolo su due righe + sottotitolo, comune a
/// registrazione e onboarding.
class AuthStepHeader extends StatelessWidget {
  const AuthStepHeader({
    super.key,
    required this.step,
    required this.title,
    this.subtitle,
  });

  final String step;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(step,
            style: AppType.display(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                italic: false,
                letterSpacing: 2.4,
                color: AppColor.inkMuted)),
        const SizedBox(height: 4),
        Text(title.toUpperCase(),
            style: AppType.display(
                fontSize: 54,
                fontWeight: FontWeight.w900,
                height: .85,
                color: AppColor.ink)),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(subtitle!,
              style: AppType.text(
                  fontSize: 14, color: AppColor.inkMuted, height: 1.45)),
        ],
      ],
    );
  }
}

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

bool isValidEmail(String v) => _emailRe.hasMatch(v.trim());
