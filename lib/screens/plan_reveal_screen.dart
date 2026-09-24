import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../onboarding/steps.dart';
import '../theme/app_colors.dart';
import '../theme/macros.dart';
import '../widgets/brand.dart';
import '../widgets/primary_button.dart';

// left / top within the 360pt-wide, 224pt-tall hero; size; rotation (deg); colour
const _confetti = <(double, double, double, double, Color)>[
  (50, 18, 11, 25, Color(0xFF3DBB2E)),
  (118, 12, 10, -15, Color(0xFF8FC7EE)),
  (224, 16, 10, 20, Color(0xFFF0A868)),
  (284, 22, 11, -25, Color(0xFF7BC98F)),
  (22, 54, 10, -20, Color(0xFF1F5BD8)),
  (78, 62, 9, 35, Color(0xFFF08A5D)),
  (250, 50, 10, 15, Color(0xFFF5B841)),
  (310, 66, 10, -30, Color(0xFFE86A92)),
  (6, 96, 11, 30, Color(0xFFF5A623)),
  (332, 108, 9, 20, Color(0xFF3DBB2E)),
  (38, 132, 10, -25, Color(0xFFE8C4A0)),
  (292, 130, 10, 25, Color(0xFF1F5BD8)),
  (14, 176, 10, 15, Color(0xFF7BC9C9)),
  (322, 182, 10, -20, Color(0xFF8FC7EE)),
  (56, 208, 11, -30, Color(0xFFE86A92)),
  (278, 202, 10, 25, Color(0xFFF5B841)),
];

class PlanRevealScreen extends StatelessWidget {
  const PlanRevealScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final plan = draftPlan;
    if (plan == null) {
      // nothing to reveal without a generated plan — send them back through the flow
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return const Scaffold();
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // the rationale will be model-written, so its length varies — scroll, don't squeeze
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 28),
                children: [
                  Center(
                    child: SizedBox(
                      width: 360,
                      height: 224,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          for (final (left, top, size, rotate, color)
                              in _confetti)
                            Positioned(
                              left: left,
                              top: top,
                              child: Transform.rotate(
                                angle: rotate * 3.14159 / 180,
                                child: Container(
                                  width: size,
                                  height: size,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          Container(
                            width: 140,
                            height: 140,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x14000000),
                                  blurRadius: 12,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const LogoMark(size: 88),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 26),
                    child: Text(
                      'Your daily calorie target',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 34),
                    child: Text(
                      "Based on your info, here's your personalized target to reach your goal.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 22 / 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    formatThousands(plan.calories),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 50,
                      height: 56 / 50,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Calories / day',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(26, 22, 26, 0),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        for (final macro in Macro.values)
                          Expanded(
                            child: Column(
                              children: [
                                Icon(macro.icon, size: 28, color: macro.color),
                                const SizedBox(height: 12),
                                Text(
                                  '${plan.grams(macro)}g',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  macro.label,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(26, 12, 26, 0),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.brandGreenTint,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: AppColors.brandGreenTintStrong,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.star,
                                size: 13,
                                color: AppColors.brandGreenDark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'How we got here',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          plan.rationale,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 20 / 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 34),
                    child: Text(
                      'You can change your targets any time from your profile.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 18 / 13,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // pinned: the CTA never depends on how much the model wrote
            Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              padding: EdgeInsets.fromLTRB(
                26,
                12,
                26,
                MediaQuery.paddingOf(context).bottom + 12,
              ),
              child: PrimaryButton(
                label: 'Continue',
                onPressed: () => context.push('/onboarding/plan-includes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String formatThousands(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
