import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../onboarding/steps.dart';
import '../state/backend.dart';
import '../state/session.dart';
import '../theme/app_colors.dart';
import '../widgets/brand.dart';
import '../widgets/pressable.dart';
import 'plan_includes_screen.dart';
import 'plan_reveal_screen.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  /// Demo mode: every button signs straight in.
  Future<void> _demoSignIn(BuildContext context) async {
    session.signInDemo();
    await finishSignIn(context);
  }

  void _notReady(BuildContext context, String provider) => showDialog<void>(
    context: context,
    builder: (d) => AlertDialog.adaptive(
      title: const Text('Coming soon'),
      content: Text(
        '$provider sign-in is not set up yet. For now, continue with email.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(d).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );

  /// Apple needs an Apple Developer account and its provider in Supabase first.
  void _apple(BuildContext context) =>
      backendEnabled ? _notReady(context, 'Apple') : _demoSignIn(context);

  Future<void> _google(BuildContext context) async {
    if (!backendEnabled) return _demoSignIn(context);
    // needs the Google Cloud client IDs in env.json and the provider on in Supabase
    if (!Session.googleConfigured) return _notReady(context, 'Google');

    final error = await session.signInWithGoogle();
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    } else if (session.isSignedIn) {
      await finishSignIn(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // only show the plan chip to someone who just finished the questionnaire
    final plan = draftPlan;
    // Hidden against a real backend until Sign in with Apple is set up (needs an
    // Apple Developer account). App Store rule 4.8: once Google sign-in ships on
    // iOS, Apple sign-in has to ship with it.
    final showApple =
        defaultTargetPlatform == TargetPlatform.iOS && !backendEnabled;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 26, top: 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Pressable(
                  onTap: () =>
                      context.canPop() ? context.pop() : context.go('/'),
                  child: const Icon(
                    Icons.arrow_back,
                    size: 24,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const LogoMark(size: 76),
                    const SizedBox(height: 26),
                    Text(
                      plan != null ? 'Save your plan' : 'Welcome back',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(
                      width: 290,
                      child: Text(
                        'Sign in to keep your targets, steps and meal history on every device.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          height: 23 / 17,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (plan != null) ...[
                      const SizedBox(height: 26),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 18,
                              color: AppColors.brandGreen,
                            ),
                            const SizedBox(width: 8),
                            Text.rich(
                              TextSpan(
                                text: 'Your plan is ready — ',
                                children: [
                                  TextSpan(
                                    text:
                                        '${formatThousands(plan.calories)} cal / day',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showApple) ...[
                    _AuthButton(
                      dark: true,
                      icon: const Icon(
                        Icons.apple,
                        size: 22,
                        color: Colors.white,
                      ),
                      label: 'Continue with Apple',
                      onTap: () => _apple(context),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // shows once the Google client IDs are in env.json
                  if (!backendEnabled || Session.googleConfigured) ...[
                    _AuthButton(
                      icon: const GoogleG(),
                      label: 'Continue with Google',
                      onTap: () => _google(context),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _AuthButton(
                    icon: const Icon(
                      Icons.mail_outline,
                      size: 21,
                      color: AppColors.ink,
                    ),
                    label: 'Continue with Email',
                    onTap: () => backendEnabled
                        ? context.push('/sign-in/email')
                        : _demoSignIn(context),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'By continuing you agree to our Terms of Service and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 17 / 12,
                      color: AppColors.textFaint,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.dark = false,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: dark ? AppColors.ink : AppColors.card,
          borderRadius: BorderRadius.circular(15),
          border: dark ? null : Border.all(color: AppColors.borderStrong),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: dark ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// After any sign-in: a plan generated before sign-up is saved the moment there's
/// an account, then the tabs' gate decides between Home and onboarding.
Future<void> finishSignIn(BuildContext context) async {
  if (draftPlan != null) await saveDraftProfile();
  if (context.mounted) context.go('/home');
}
