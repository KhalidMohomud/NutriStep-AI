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
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: 'Edit',
                height: 52,
                onPressed: () {
                  final root = Navigator.of(
                    context,
                    rootNavigator: true,
                  ).context;
                  Navigator.of(context).pop();
                  showEditMealSheet(root, meal);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Pressable(
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
                      Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.error,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Delete',
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
            ),
          ],
        ),
      ],
    ),
  );
}

const _portions = <(String, double)>[
  ('½', 0.5),
  ('¾', 0.75),
  ('1×', 1),
  ('1½', 1.5),
  ('2×', 2),
];

/// The way out when the AI got it wrong: pick how much of it you ate, then
/// fine-tune any number. Saved as `user_corrected`.
Future<void> showEditMealSheet(BuildContext context, Meal original) {
  final name = TextEditingController(text: original.name);
  var factor = 1.0;
  var meal = original;

  return _sheet(
    context,
    (sheet) => StatefulBuilder(
      builder: (sheet, set) {
        Widget stepper(
          String label,
          int value,
          String unit,
          int step,
          Color color,
          void Function(int) onChange,
        ) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: value - step < 0
                      ? null
                      : () => onChange(value - step),
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: AppColors.textFaint,
                  ),
                ),
                SizedBox(
                  width: 74,
                  child: Text(
                    '$value $unit',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => onChange(value + step),
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: AppColors.brandGreen,
                  ),
                ),
              ],
            ),
          );
        }

        // scrolls, and lifts above the keyboard, while the name is being edited
        return Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheet).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 18),
                const Text(
                  'Edit meal',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.sentences,
                  cursorColor: AppColors.brandGreen,
                  style: const TextStyle(fontSize: 17, color: AppColors.ink),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.card,
                    prefixIcon: const Icon(
                      Icons.restaurant,
                      color: AppColors.textFaint,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.borderStrong,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.brandGreen,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'How much did you eat?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final (label, f) in _portions) ...[
                      if (f != _portions.first.$2) const SizedBox(width: 8),
                      Expanded(
                        child: Pressable(
                          onTap: () => set(() {
                            factor = f;
                            meal = original.scaled(f);
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: factor == f
                                  ? AppColors.brandGreenTint
                                  : AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: factor == f
                                    ? AppColors.brandGreen
                                    : AppColors.border,
                                width: factor == f ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: factor == f
                                    ? AppColors.brandGreenDark
                                    : AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                stepper(
                  'Calories',
                  meal.calories,
                  'kcal',
                  10,
                  AppColors.brandGreen,
                  (v) => set(() => meal = meal.copyWith(calories: v)),
                ),
                const SizedBox(height: 8),
                for (final macro in Macro.values) ...[
                  stepper(
                    macro.label,
                    meal.grams(macro),
                    'g',
                    1,
                    macro.color,
                    (v) => set(() {
                      meal = switch (macro) {
                        Macro.protein => meal.copyWith(protein: v),
                        Macro.carbs => meal.copyWith(carbs: v),
                        Macro.fat => meal.copyWith(fat: v),
                      };
                    }),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Save',
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final edited = meal.copyWith(
                      name: name.text.trim().isEmpty
                          ? original.name
                          : name.text.trim(),
                    );
                    Navigator.of(sheet).pop();
                    try {
                      await session.updateMeal(edited);
                    } catch (_) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Couldn't save your changes. Try again.",
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
