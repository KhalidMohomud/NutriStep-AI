import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../onboarding/steps.dart';
import '../state/session.dart';
import '../theme/app_colors.dart';
import '../widgets/onboarding.dart';
import '../widgets/primary_button.dart';

const _features = <(IconData, String, String)>[
  (
    Icons.track_changes,
    'Calorie Tracking',
    'Track effortlessly and stay on target',
  ),
  (
    Icons.center_focus_strong_outlined,
    'AI Food Scanner',
    'Snap a meal, get instant nutrition',
  ),
  (
    Icons.pie_chart_outline,
    'Macro Breakdown',
    'Protein, carbs and fat for every meal',
  ),
  (
    Icons.directions_walk,
    'Step Tracking',
    'Your daily steps next to your meals',
  ),
  (
    Icons.bar_chart,
    'Progress Tracking',
    'See your progress and stay motivated',
  ),
];

/// Saves the questionnaire answers plus the plan generated from them.
Future<void> saveDraftProfile() async {
  final input = answersAsInput();
  final plan = draftPlan;
  if (input == null || plan == null) return;
  await session.saveProfile(
    Profile(
      input: input,
      plan: plan,
      timezone: DateTime.now().timeZoneName,
      // someone redoing onboarding keeps their original join date
      memberSince: session.profile?.memberSince ?? DateTime.now(),
    ),
  );
}

class PlanIncludesScreen extends StatefulWidget {
  const PlanIncludesScreen({super.key});

  @override
  State<PlanIncludesScreen> createState() => _PlanIncludesScreenState();
}

class _PlanIncludesScreenState extends State<PlanIncludesScreen> {
  bool _saving = false;
  bool _failed = false;

  // someone who redid onboarding is already signed in — no reason to ask again
  Future<void> _continue() async {
    if (!session.isSignedIn) {
      context.push('/sign-in');
      return;
    }
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await saveDraftProfile();
      if (mounted) context.go('/home');
    } catch (e) {
      debugPrint('Profile save failed: $e');
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = (answers['targetWeightKg'] as double?)?.toStringAsFixed(1);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const OnboardingTopBar(progress: 1),
            ScreenTitle(
              title: "Here's what your plan includes",
              subtitle: 'Your personalized plan to help you reach $target kg.',
              subtitleWidth: 240,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(26, 30, 26, 16),
                children: [
                  for (final (icon, title, subtitle) in _features) ...[
                    Container(
                      height: 70,
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: Icon(icon, size: 26, color: AppColors.ink),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
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
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            if (_failed)
              const Padding(
                padding: EdgeInsets.fromLTRB(26, 0, 26, 4),
                child: Text(
                  "We couldn't save your plan. Please try again.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 8, 26, 16),
              child: PrimaryButton(
                label: 'Continue',
                loading: _saving,
                onPressed: _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
