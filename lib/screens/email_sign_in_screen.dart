import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../state/session.dart';
import '../theme/app_colors.dart';
import '../widgets/pressable.dart';
import '../widgets/primary_button.dart';
import 'sign_in_screen.dart';

/// Email + password, one screen for both "create account" and "sign in".
class EmailSignInScreen extends StatefulWidget {
  const EmailSignInScreen({super.key});

  @override
  State<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends State<EmailSignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = true;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _valid =>
      _email.text.trim().contains('@') && _password.text.length >= 8;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    final email = _email.text.trim();
    try {
      if (_creating) {
        final outcome = await session.signUpWithEmail(email, _password.text);
        if (outcome == SignUpOutcome.confirmEmail) {
          setState(() {
            _creating = false;
            _notice =
                'We sent a link to $email. Tap it to confirm, then sign in here.';
          });
          return;
        }
      } else {
        final error = await session.signInWithEmail(email, _password.text);
        if (error != null) {
          setState(() => _error = error);
          return;
        }
      }
      if (mounted) await finishSignIn(context);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      debugPrint('Email auth failed: $e');
      setState(
        () => _error =
            'Something went wrong. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(26, 4, 26, 24),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Pressable(
                onTap: () => context.pop(),
                child: const Icon(
                  Icons.arrow_back,
                  size: 24,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              _creating ? 'Create your account' : 'Welcome back',
              style: const TextStyle(
                fontSize: 32,
                height: 38 / 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _creating
                  ? 'Save your plan and keep it on every device.'
                  : 'Sign in with your email.',
              style: const TextStyle(
                fontSize: 17,
                height: 23 / 17,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 30),
            _Field(
              controller: _email,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _password,
              label: 'Password',
              obscure: !_showPassword,
              autofillHints: [
                _creating ? AutofillHints.newPassword : AutofillHints.password,
              ],
              helper: _creating ? 'At least 8 characters' : null,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _valid && !_busy ? _submit() : null,
              trailing: IconButton(
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textFaint,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: const TextStyle(fontSize: 14, color: AppColors.error),
              ),
            ],
            if (_notice != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.brandGreenTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.mark_email_read_outlined,
                      color: AppColors.brandGreenDark,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _notice!,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 26),
            PrimaryButton(
              label: _creating ? 'Create account' : 'Sign in',
              loading: _busy,
              onPressed: _valid ? _submit : null,
            ),
            const SizedBox(height: 16),
            Center(
              child: Pressable(
                onTap: () => setState(() {
                  _creating = !_creating;
                  _error = null;
                }),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text.rich(
                    TextSpan(
                      text: _creating
                          ? 'Already have an account? '
                          : 'New to NutriStep? ',
                      children: [
                        TextSpan(
                          text: _creating ? 'Sign in' : 'Create one',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandGreen,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscure = false,
    this.autofillHints,
    this.helper,
    this.trailing,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscure;
  final Iterable<String>? autofillHints;
  final String? helper;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: !obscure,
      autofillHints: autofillHints,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 17, color: AppColors.ink),
      cursorColor: AppColors.brandGreen,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        filled: true,
        fillColor: AppColors.card,
        suffixIcon: trailing,
        labelStyle: const TextStyle(color: AppColors.textFaint),
        floatingLabelStyle: const TextStyle(color: AppColors.brandGreen),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        enabledBorder: border(AppColors.borderStrong),
        focusedBorder: border(AppColors.brandGreen, 2),
      ),
    );
  }
}
