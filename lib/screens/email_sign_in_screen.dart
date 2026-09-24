import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../onboarding/steps.dart';
import '../state/session.dart';
import '../theme/app_colors.dart';
import '../widgets/pressable.dart';
import '../widgets/primary_button.dart';
import '../widgets/brand.dart';
import 'plan_reveal_screen.dart';
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

  void _setMode(bool creating) => setState(() {
    _creating = creating;
    _error = null;
    _notice = null;
  });

  @override
  Widget build(BuildContext context) {
    final plan = draftPlan;
    final longEnough = _password.text.length >= 8;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(26, 4, 26, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
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
                  const SizedBox(height: 22),
                  const Center(child: LogoMark(size: 64)),
                  const SizedBox(height: 18),
                  Text(
                    _creating ? 'Create your account' : 'Welcome back',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 30,
                      height: 36 / 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _creating
                        ? 'Save your plan and keep it on every device.'
                        : 'Sign in to pick up where you left off.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 22 / 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (plan != null && _creating) ...[
                    const SizedBox(height: 16),
                    Center(child: _PlanChip(calories: plan.calories)),
                  ],
                  const SizedBox(height: 24),
                  _ModeToggle(creating: _creating, onChanged: _setMode),
                  const SizedBox(height: 20),
                  _Field(
                    controller: _email,
                    hint: 'Email',
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _password,
                    hint: 'Password',
                    icon: Icons.lock_outline,
                    obscure: !_showPassword,
                    autofillHints: [
                      _creating
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _valid && !_busy ? _submit() : null,
                    trailing: IconButton(
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
                  if (_creating) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const SizedBox(width: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            longEnough
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            key: ValueKey(longEnough),
                            size: 16,
                            color: longEnough
                                ? AppColors.brandGreen
                                : AppColors.disabled,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'At least 8 characters',
                          style: TextStyle(
                            fontSize: 13,
                            color: longEnough
                                ? AppColors.brandGreenDark
                                : AppColors.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _Banner(
                      icon: Icons.error_outline,
                      text: _error!,
                      error: true,
                    ),
                  ],
                  if (_notice != null) ...[
                    const SizedBox(height: 14),
                    _Banner(
                      icon: Icons.mark_email_read_outlined,
                      text: _notice!,
                    ),
                  ],
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: _creating ? 'Create account' : 'Sign in',
                    loading: _busy,
                    onPressed: _valid ? _submit : null,
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(32, 0, 32, 12),
              child: Text(
                'By continuing you agree to our Terms of Service and Privacy Policy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 17 / 12,
                  color: AppColors.textFaint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Create account | Sign in", a segmented pill with a sliding white thumb.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.creating, required this.onChanged});

  final bool creating;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool value) => Expanded(
      child: Pressable(
        onTap: () => onChanged(value),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            // merged, not replaced — a bare TextStyle would drop the app's font
            style: DefaultTextStyle.of(context).style.merge(
              TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: creating == value ? AppColors.ink : AppColors.textFaint,
              ),
            ),
            child: Text(label),
          ),
        ),
      ),
    );

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: creating
                ? AlignmentDirectional.centerStart
                : AlignmentDirectional.centerEnd,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(children: [tab('Create account', true), tab('Sign in', false)]),
        ],
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({required this.calories});

  final int calories;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.brandGreenTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 16, color: AppColors.brandGreen),
          const SizedBox(width: 6),
          Text.rich(
            TextSpan(
              text: 'Your plan is ready — ',
              children: [
                TextSpan(
                  text: '${formatThousands(calories)} cal / day',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, this.error = false});

  final IconData icon;
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFFDECEA) : AppColors.brandGreenTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: error ? AppColors.error : AppColors.brandGreenDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 20 / 14,
                color: error ? AppColors.error : AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.autofillHints,
    this.textInputAction,
    this.trailing,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: c, width: w),
    );

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: !obscure,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 17, color: AppColors.ink),
      cursorColor: AppColors.brandGreen,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textFaint),
        filled: true,
        fillColor: AppColors.card,
        prefixIcon: Icon(icon, color: AppColors.textFaint),
        suffixIcon: trailing,
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
