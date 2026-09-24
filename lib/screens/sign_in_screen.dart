import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../onboarding/steps.dart';
import '../state/backend.dart';
import '../state/session.dart';
import '../theme/app_colors.dart';
import '../widgets/brand.dart';
import '../widgets/pressable.dart';
import '../widgets/primary_button.dart';
import 'plan_includes_screen.dart';
import 'plan_reveal_screen.dart';

/// After any sign-in: a plan generated before sign-up is saved the moment there's
/// an account, then the tabs' gate decides between Home and onboarding.
Future<void> finishSignIn(BuildContext context) async {
  if (draftPlan != null) await saveDraftProfile();
  if (context.mounted) context.go('/home');
}

const _heroHeight = 270.0;
const _overlap = 30.0;

/// The whole auth section on one screen: brand header, then a card with
/// "Create account | Sign in", the email form and — once they're set up —
/// Google and Apple underneath.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  // someone arriving from the questionnaire is new; from "Sign In" on welcome, not
  late bool _creating = draftPlan != null;
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

  // Google needs its client IDs in env.json; Apple an Apple Developer account.
  // In demo mode both are stand-ins, so they show.
  bool get _showGoogle => !backendEnabled || Session.googleConfigured;
  bool get _showApple =>
      !backendEnabled && defaultTargetPlatform == TargetPlatform.iOS;

  void _setMode(bool creating) => setState(() {
    _creating = creating;
    _error = null;
    _notice = null;
  });

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    try {
      if (!backendEnabled) {
        session.signInDemo();
      } else if (_creating) {
        final email = _email.text.trim();
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
        final error = await session.signInWithEmail(
          _email.text.trim(),
          _password.text,
        );
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

  Future<void> _google() async {
    if (!backendEnabled) {
      session.signInDemo();
      return finishSignIn(context);
    }
    setState(() => _error = null);
    final error = await session.signInWithGoogle();
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
    } else if (session.isSignedIn) {
      await finishSignIn(context);
    }
  }

  Future<void> _apple() async {
    session.signInDemo();
    await finishSignIn(context);
  }

  @override
  Widget build(BuildContext context) {
    final plan = draftPlan;
    final longEnough = _password.text.length >= 8;
    final top = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // white status bar over the gradient
      child: Scaffold(
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Hero(height: _heroHeight + top, topInset: top),
              Transform.translate(
                offset: const Offset(0, -_overlap),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    28,
                    24,
                    MediaQuery.paddingOf(context).bottom + 8,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Column(
                          key: ValueKey(_creating),
                          children: [
                            Text(
                              _creating
                                  ? 'Create your account'
                                  : 'Welcome back',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                height: 34 / 28,
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
                                fontSize: 15,
                                height: 21 / 15,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (plan != null && _creating) ...[
                        const SizedBox(height: 14),
                        Center(child: _PlanChip(calories: plan.calories)),
                      ],
                      const SizedBox(height: 22),
                      _ModeToggle(creating: _creating, onChanged: _setMode),
                      const SizedBox(height: 18),
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
                        _Requirement(
                          met: longEnough,
                          label: 'At least 8 characters',
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
                      const SizedBox(height: 22),
                      PrimaryButton(
                        label: _creating ? 'Create account' : 'Sign in',
                        loading: _busy,
                        onPressed: _valid ? _submit : null,
                      ),
                      if (_showGoogle || _showApple) ...[
                        const SizedBox(height: 24),
                        const _OrDivider(),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            if (_showGoogle)
                              Expanded(
                                child: _SocialButton(
                                  icon: const GoogleG(size: 18),
                                  label: 'Google',
                                  onTap: _google,
                                ),
                              ),
                            if (_showGoogle && _showApple)
                              const SizedBox(width: 12),
                            if (_showApple)
                              Expanded(
                                child: _SocialButton(
                                  icon: const Icon(
                                    Icons.apple,
                                    size: 22,
                                    color: AppColors.ink,
                                  ),
                                  label: 'Apple',
                                  onTap: _apple,
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 26),
                      const Text(
                        'By continuing you agree to our Terms of Service and Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 17 / 12,
                          color: AppColors.textFaint,
                        ),
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

/// Logo-gradient header: the mark on a white disc, the name, the tagline.
class _Hero extends StatelessWidget {
  const _Hero({required this.height, required this.topInset});

  final double height;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.brandLeaf,
                    AppColors.brandGreen,
                    AppColors.brandAzure,
                    AppColors.brandBlue,
                  ],
                  stops: [0, 0.3, 0.7, 1],
                ),
              ),
            ),
          ),
          // soft light blooms so the gradient doesn't read flat
          const Positioned(
            right: -60,
            top: -40,
            child: _Bloom(size: 220, opacity: 0.16),
          ),
          const Positioned(
            left: -70,
            bottom: -10,
            child: _Bloom(size: 180, opacity: 0.10),
          ),
          Positioned(
            left: 12,
            top: topInset + 4,
            child: IconButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/'),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          Positioned.fill(
            top: topInset,
            bottom: _overlap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const LogoMark(size: 56),
                ),
                const SizedBox(height: 14),
                const Text(
                  'NutriStep AI',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'SCAN  •  TRACK  •  LIVE BETTER',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bloom extends StatelessWidget {
  const _Bloom({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );
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

class _Requirement extends StatelessWidget {
  const _Requirement({required this.met, required this.label});

  final bool met;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            key: ValueKey(met),
            size: 16,
            color: met ? AppColors.brandGreen : AppColors.disabled,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: met ? AppColors.brandGreenDark : AppColors.textFaint,
          ),
        ),
      ],
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

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.border, thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or continue with',
            style: TextStyle(fontSize: 13, color: AppColors.textFaint),
          ),
        ),
        Expanded(child: Divider(color: AppColors.border, thickness: 1)),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
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
