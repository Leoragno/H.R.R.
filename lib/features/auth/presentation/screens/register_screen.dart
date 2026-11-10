import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';

/// REGISTRAZIONE (HEAT, handoff §3) — passo 1 di 3: username ≥ 3, email,
/// password ≥ 6 ripetuta, accettazione termini; un'unica riga d'errore
/// rossa. Dopo, il router porta a "il tuo ride" e "scegli il pilota".
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _terms = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _validate() {
    final user = _usernameCtrl.text.trim();
    if (user.length < 3) return 'lo username ha almeno 3 caratteri.';
    if (user.length > 24) return 'lo username ha al massimo 24 caratteri.';
    if (!isValidEmail(_emailCtrl.text)) return 'inserisci un\'email valida.';
    if (_passwordCtrl.text.length < 6) {
      return 'la password ha almeno 6 caratteri.';
    }
    if (_confirmCtrl.text != _passwordCtrl.text) {
      return 'le password non coincidono.';
    }
    if (!_terms) return 'accetta termini e privacy per continuare.';
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    setState(() => _error = err);
    if (err != null) return;
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).signUpWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          username: _usernameCtrl.text.trim(),
        );
  }

  static String _friendlyError(Object err) {
    final msg = err.toString();
    if (msg.contains('duplicate key') ||
        msg.contains('unique') ||
        msg.contains('already registered')) {
      return 'username o email già in uso.';
    }
    return 'registrazione non riuscita. riprova.';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (prev, next) {
      next.whenOrNull(
        error: (err, _) => setState(() => _error = _friendlyError(err)),
      );
    });
    final loading = ref.watch(authControllerProvider).isLoading;

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
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => context.canPop()
                                ? context.pop()
                                : context.go(AppRoutes.login),
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: AppColor.ink),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const AuthStepHeader(
                          step: 'PASSO 1 DI 3',
                          title: 'Nuovo\npilota',
                          subtitle: 'il tuo nome di strada è quello che '
                              'vedranno i rivali in classifica.',
                        ),
                        const SizedBox(height: 24),
                        AuthTextField(
                          placeholder: 'username',
                          controller: _usernameCtrl,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newUsername],
                        ),
                        const SizedBox(height: 10),
                        AuthTextField(
                          placeholder: 'email',
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                        ),
                        const SizedBox(height: 10),
                        AuthTextField(
                          placeholder: 'password · minimo 6 caratteri',
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          onToggleObscure: () =>
                              setState(() => _obscure = !_obscure),
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                        ),
                        const SizedBox(height: 10),
                        AuthTextField(
                          placeholder: 'ripeti password',
                          controller: _confirmCtrl,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 14),
                        _TermsRow(
                          checked: _terms,
                          onChanged: (v) => setState(() => _terms = v),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          AuthErrorRow(_error!),
                        ],
                        const Spacer(),
                        const SizedBox(height: 20),
                        HeatButton(
                          label: loading ? 'UN ATTIMO…' : 'CREA ACCOUNT',
                          icon: null,
                          height: 58,
                          fontSize: 24,
                          onPressed: loading ? null : _submit,
                        ),
                      ],
                    ),
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

class _TermsRow extends StatelessWidget {
  const _TermsRow({required this.checked, required this.onChanged});

  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!checked),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.skewX(-.21),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: checked ? AppColor.ink : null,
                    border: Border.all(
                        color: checked ? AppColor.ink : AppColor.lineMuted,
                        width: 1.5),
                  ),
                  child: checked
                      ? const Icon(Icons.check_rounded,
                          size: 15, color: AppColor.base)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'accetto i '),
                    TextSpan(
                        text: 'termini di servizio',
                        style: AppType.text(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColor.ink)),
                    const TextSpan(text: ' e la '),
                    TextSpan(
                        text: 'privacy policy',
                        style: AppType.text(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColor.ink)),
                    const TextSpan(text: '.'),
                  ]),
                  style: AppType.text(
                      fontSize: 13, color: AppColor.inkMuted, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
