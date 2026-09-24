import 'package:flutter/material.dart';

import '../state/session.dart';
import '../theme/app_colors.dart';
import '../theme/macros.dart';
import 'meal_image.dart';
import 'pressable.dart';
import 'primary_button.dart';

const _flame = Color(0xFFF4685C);

String _streakLine(int streak) => streak == 0
    ? 'Log one meal today and the fire starts burning.'
    : streak < 3
    ? 'The first days are the hardest. You are past them.'
    : streak < 7
    ? 'Momentum is real. Do not let it cool off.'
    : 'A week strong. This is who you are now.';

Future<void> _sheet(
  BuildContext context,
  Widget Function(BuildContext) builder,
) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true, // over the tab bar, not under it
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
        26,
        12,
        26,
        MediaQuery.paddingOf(context).bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E2E7),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          builder(context),
        ],
      ),
    ),
  );
}

Future<void> showStreakSheet(BuildContext context, int streak) {
  return _sheet(
    context,
    (context) => Column(
      children: [
        const SizedBox(height: 24),
        Container(
          width: 86,
          height: 86,
          decoration: const BoxDecoration(
            color: Color(0xFFFDECEA),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.local_fire_department,
            size: 46,
            color: _flame,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '$streak',
          style: const TextStyle(
            fontSize: 46,
            height: 52 / 46,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          streak == 1 ? 'day streak' : 'days streak',
          style: const TextStyle(fontSize: 16, color: AppColors.textMuted),
        ),
        const SizedBox(height: 14),
        Text(
          _streakLine(streak),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            height: 22 / 16,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 26),
        PrimaryButton(
          label: "Let's go",
          height: 54,
          radius: 27,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}

/// A logged meal: photo, numbers, and the way out if the AI got it wrong.
Future<void> showMealSheet(BuildContext context, Meal meal) {
  return _sheet(
    context,
    (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: MealImage(
            src: meal.image,
            height: 190,
            width: double.infinity,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          meal.name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(
              Icons.local_fire_department,
              size: 20,
              color: AppColors.brandGreen,
            ),
            const SizedBox(width: 4),
            Text(
              '${meal.calories} kcal',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (final macro in Macro.values) ...[
              if (macro != Macro.protein) const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(macro.icon, size: 20, color: macro.color),
                      const SizedBox(height: 8),
                      Text(
                        '${meal.grams(macro)}g',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        macro.label,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 22),
        Pressable(
          onTap: () {
            final messenger = ScaffoldMessenger.of(context);
            Navigator.of(context).pop();
            session.deleteMeal(meal.id).catchError((Object _) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text("Couldn't delete that meal. Try again."),
                ),
              );
            });
          },
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.borderStrong),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                SizedBox(width: 8),
                Text(
                  'Delete meal',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
