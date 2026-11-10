import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/heat/heat_widgets.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';

/// ACCESSO (HEAT, handoff §2): "bentornato / IN STRADA", email e password
/// con un'unica riga d'errore, ACCEDI (unico accento), Google / Apple e
/// il link alla registrazione.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text;
    final err = !isValidEmail(email)
        ? 'inserisci un\'email valida.'
        : pass.length < 6
            ? 'la password ha almeno 6 caratteri.'
            : null;
    setState(() => _error = err);
    if (err != null) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(authControllerProvider.notifier)
        .signInWithEmail(email, pass);
  }

  static String _friendlyError(Object err) {
    final msg = err.toString();
    if (msg.contains('Invalid login credentials')) {
      return 'email o password errati.';
    }
    if (msg.contains('Email not confirmed')) {
      return 'conferma prima l\'email: controlla la posta.';
    }
    if (msg.toLowerCase().contains('cancel')) return 'accesso annullato.';
    return 'accesso non riuscito. riprova.';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (prev, next) {
      next.whenOrNull(
        error: (err, _) => setState(() => _error = _friendlyError(err)),
      );
    });

    final loading = ref.watch(authControllerProvider).isLoading;
    final auth = ref.read(authControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColor.base,
      body: HeatBackground(
        glow: false,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 40, 22, 30),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const HeatEnter(
                    index: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GraffitiText('bentornato',
                            fontSize: 34, color: AppColor.ink, angle: -.07),
                        SizedBox(height: 2),
                        ScreenTitle('In strada', fontSize: 58),
                      ],
                    ),
                  ),
                  const SizedBox(height: 52),
                  AuthTextField(
                    placeholder: 'email',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                  ),
                  const SizedBox(height: 10),
                  AuthTextField(
                    placeholder: 'password',
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    onToggleObscure: () => setState(() => _obscure = !_obscure),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    autofillHints: const [AutofillHints.password],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    AuthErrorRow(_error!),
                  ],
                  const SizedBox(height: 14),
                  HeatButton(
                    label: loading ? 'ACCESSO…' : 'ACCEDI',
                    height: 58,
                    fontSize: 24,
                    onPressed: loading ? null : _submit,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                          child: Divider(color: AppColor.line, height: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('oppure',
                            style: AppType.text(
                                fontSize: 12, color: AppColor.inkFaint)),
                      ),
                      const Expanded(
                          child: Divider(color: AppColor.line, height: 1)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: AuthSocialButton(
                          icon: Text('G',
                              style: AppType.display(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  italic: false,
                                  color: AppColor.ink)),
                          label: 'Google',
                          onPressed: loading ? null : auth.signInWithGoogle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AuthSocialButton(
                          icon: const Icon(Icons.apple_rounded,
                              size: 20, color: AppColor.ink),
                          label: 'Apple',
                          onPressed: loading ? null : auth.signInWithApple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('nuovo pilota? ',
                            style: AppType.text(
                                fontSize: 14, color: AppColor.inkMuted)),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => context.push(AppRoutes.register),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('crea un account',
                                style: AppType.text(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColor.ink)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
