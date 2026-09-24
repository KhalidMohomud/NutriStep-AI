import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../onboarding/steps.dart';
import '../theme/app_colors.dart';
import '../widgets/brand.dart';
import '../widgets/pressable.dart';
import '../widgets/primary_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 22),
            const Wordmark(fontSize: 32, markSize: 46),
            const SizedBox(height: 13),
            // the mockup gives way on short screens; the copy and CTA never do
            Expanded(child: Image.asset(phoneMockup, fit: BoxFit.contain)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                children: [
                  const SizedBox(height: 14),
                  const SizedBox(
                    width: 265,
                    child: Text(
                      'Calorie tracking made easy',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        height: 37 / 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(
                    width: 300,
                    child: Text(
                      'Scan meals, count your steps and build healthy habits with AI.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 21 / 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 17),
                  PrimaryButton(
                    label: 'Get Started',
                    height: 48,
                    radius: 24,
                    trailing: const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () {
                      resetAnswers();
                      context.push('/onboarding/${steps.first.key}');
                    },
                  ),
                  const SizedBox(height: 13),
                  Pressable(
                    onTap: () => context.push('/sign-in'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text.rich(
                        TextSpan(
                          text: 'Already have an account? ',
                          children: [
                            TextSpan(
                              text: 'Sign In',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandGreen,
                              ),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 15,
                          letterSpacing: -0.5,
                          color: Color(0xFF262626),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
