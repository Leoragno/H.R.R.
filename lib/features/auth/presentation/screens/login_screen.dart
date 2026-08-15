import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/hrr_wordmark.dart';
import '../../../../core/widgets/neon_cta_button.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .signInWithEmail(_emailCtrl.text.trim(), _passwordCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (prev, next) {
      next.whenOrNull(
        error: (err, _) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(err)),
            backgroundColor: AppColor.danger,
          ),
        ),
      );
    });

    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColor.void_,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: HrrWordmark(fontSize: 34, showTagline: false),
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: 34),
                Text(
                  'Bentornato',
                  style: AppType.text(
                    fontWeight: FontWeight.w900,
                    fontSize: 36,
                    color: AppColor.ink,
                  ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.15, end: 0),
                const SizedBox(height: 12),
                Text(
                  'Accedi per continuare la tua corsa',
                  style: AppType.text(
                    fontSize: 17,
                    color: AppColor.inkMuted,
                  ),
                ),
                const SizedBox(height: 28),
                AuthTextField(
                  label: 'Email',
                  controller: _emailCtrl,
                  hint: 'nome@esempio.com',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Inserisci un\'email valida'
                      : null,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Password',
                  controller: _passwordCtrl,
                  hint: '••••••••',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscure,
                  onToggleObscure: () => setState(() => _obscure = !_obscure),
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Minimo 6 caratteri' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(
                      content:
                          Text('Il recupero password non è ancora disponibile'),
                    )),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColor.cyan,
                    ),
                    child: const Text('Password dimenticata?'),
                  ),
                ),
                const SizedBox(height: 10),
                NeonCtaButton(
                  label: isLoading ? '' : 'Accedi',
                  onPressed: isLoading ? null : _submit,
                  icon: isLoading ? null : null,
                ),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColor.cyan,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider(color: Color(0xFF232323))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('oppure',
                          style: AppType.text(
                              color: AppColor.inkMuted,
                              fontSize: 14)),
                    ),
                    const Expanded(child: Divider(color: Color(0xFF232323))),
                  ],
                ),
                const SizedBox(height: 20),
                _SocialButton(
                  icon: Icons.g_mobiledata_rounded,
                  label: 'Continua con Google',
                  onPressed: isLoading
                      ? null
                      : () => ref
                          .read(authControllerProvider.notifier)
                          .signInWithGoogle(),
                ),
                const SizedBox(height: 12),
                _SocialButton(
                  icon: Icons.apple_rounded,
                  label: 'Continua con Apple',
                  onPressed: isLoading
                      ? null
                      : () => ref
                          .read(authControllerProvider.notifier)
                          .signInWithApple(),
                ),
                const SizedBox(height: 28),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Non hai un account? ',
                          style: AppType.text(
                              fontSize: 16,
                              color: AppColor.inkMuted)),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.register),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColor.cyan,
                          padding: EdgeInsets.zero,
                        ),
                        child: Text('Registrati',
                            style: AppType.text(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _friendlyError(Object err) {
    final msg = err.toString();
    if (msg.contains('Invalid login credentials')) {
      return 'Email o password errati';
    }
    return 'Errore di accesso, riprova';
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _SocialButton(
      {required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: AppColor.ink),
      label: Text(label, style: AppType.text(fontSize: 15)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColor.ink,
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: const BorderSide(color: Color(0x33A0AAFF)),
        backgroundColor: const Color(0xE50C1120),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
