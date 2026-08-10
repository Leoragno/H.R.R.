import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/hrr_wordmark.dart';
import '../../../../core/widgets/neon_cta_button.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _termsAccepted = false;
  bool _termsError = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState!.validate();
    setState(() => _termsError = !_termsAccepted);
    if (!formValid || !_termsAccepted) return;

    await ref.read(authControllerProvider.notifier).signUpWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          username: _usernameCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (prev, next) {
      next.whenOrNull(
        error: (err, _) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(err)),
            backgroundColor: AppColors.danger,
          ),
        ),
      );
    });

    final isLoading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.guidaBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary, size: 18),
                    ),
                    const SizedBox(width: 4),
                    const HrrWordmark(fontSize: 30, showTagline: false),
                  ],
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: 28),
                Text(
                  'Crea il tuo account',
                  style: AppTheme.archivo(
                    fontWeight: FontWeight.w900,
                    fontSize: 34,
                    color: AppColors.textPrimary,
                  ),
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.15, end: 0),
                const SizedBox(height: 12),
                Text(
                  'Unisciti alla community e scala la classifica',
                  style: AppTheme.archivo(
                    fontSize: 17,
                    color: AppColors.guidaTextSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                AuthTextField(
                  label: 'Username',
                  controller: _usernameCtrl,
                  hint: 'il_tuo_nome',
                  icon: Icons.person_outline_rounded,
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Minimo 3 caratteri'
                      : null,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Email',
                  controller: _emailCtrl,
                  hint: 'nome@esempio.com',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Email non valida'
                      : null,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Password',
                  controller: _passwordCtrl,
                  hint: 'Almeno 6 caratteri',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  onToggleObscure: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Minimo 6 caratteri' : null,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Conferma password',
                  controller: _confirmCtrl,
                  hint: 'Ripeti la password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscureConfirm,
                  onToggleObscure: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  validator: (v) => v != _passwordCtrl.text
                      ? 'Le password non coincidono'
                      : null,
                ),
                const SizedBox(height: 18),
                _TermsCheckbox(
                  checked: _termsAccepted,
                  hasError: _termsError,
                  onChanged: (v) => setState(() {
                    _termsAccepted = v;
                    if (v) _termsError = false;
                  }),
                ),
                if (_termsError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      'Devi accettare i termini per continuare',
                      style: AppTheme.archivo(
                          fontSize: 13, color: AppColors.danger),
                    ),
                  ),
                const SizedBox(height: 22),
                NeonCtaButton(
                  label: 'Crea account',
                  onPressed: isLoading ? null : _submit,
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
                          color: AppColors.guidaCyan,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      Text('Hai già un account? ',
                          style: AppTheme.archivo(
                              fontSize: 16,
                              color: AppColors.guidaTextSecondary)),
                      TextButton(
                        onPressed: () => context.pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.guidaCyan,
                          padding: EdgeInsets.zero,
                        ),
                        child: Text('Accedi',
                            style: AppTheme.archivo(
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
    if (msg.contains('duplicate key') || msg.contains('unique')) {
      return 'Username o email già in uso';
    }
    return 'Registrazione non riuscita, riprova';
  }
}

class _TermsCheckbox extends StatelessWidget {
  final bool checked;
  final bool hasError;
  final ValueChanged<bool> onChanged;

  const _TermsCheckbox({
    required this.checked,
    required this.hasError,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? AppColors.danger
        : (checked ? AppColors.guidaCyan : const Color(0xFF3A3A3A));

    return InkWell(
      onTap: () => onChanged(!checked),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: checked ? AppColors.guidaCyan : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: checked
                ? const Icon(Icons.check_rounded,
                    size: 18, color: AppColors.guidaOnAccent)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: AppTheme.archivo(
                    fontSize: 14, color: const Color(0xFFC2D2E6), height: 1.45),
                children: [
                  const TextSpan(text: 'Accetto i '),
                  TextSpan(
                    text: 'Termini di servizio',
                    style: AppTheme.archivo(
                      fontSize: 14,
                      color: AppColors.guidaCyan,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: ' e la '),
                  TextSpan(
                    text: 'Privacy policy',
                    style: AppTheme.archivo(
                      fontSize: 14,
                      color: AppColors.guidaCyan,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
