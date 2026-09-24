import 'dart:math';

import '../theme/macros.dart';

/// The nine onboarding answers. Storage is metric — conversion happens at the
/// display edge only.
class PlanInput {
  const PlanInput({
    required this.gender,
    required this.dateOfBirth,
    required this.heightCm,
    required this.weightKg,
    required this.goal,
    required this.targetWeightKg,
    required this.activityLevel,
    required this.paceKgPerWeek,
    required this.dietPreference,
  });

  final String gender; // male | female
  final String dateOfBirth; // yyyy-mm-dd, no timezone
  final double heightCm;
  final double weightKg;
  final String goal; // lose | maintain | gain
  final double targetWeightKg;
  final String activityLevel; // sedentary | light | moderate | very | extra
  final double paceKgPerWeek;
  final String dietPreference; // classic | keto | vegan | vegetarian

  Map<String, Object> toJson() => {
    'gender': gender,
    'dateOfBirth': dateOfBirth,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'goal': goal,
    'targetWeightKg': targetWeightKg,
    'activityLevel': activityLevel,
    'paceKgPerWeek': paceKgPerWeek,
    'dietPreference': dietPreference,
  };
}

class Plan {
  const Plan({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.rationale,
  });

  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final String rationale;

  int grams(Macro macro) => switch (macro) {
    Macro.protein => protein,
    Macro.carbs => carbs,
    Macro.fat => fat,
  };
}

const _yearMs = 31557600000;

int ageFrom(String dateOfBirth, {DateTime? now}) {
  final ms =
      (now ?? DateTime.now()).millisecondsSinceEpoch -
      DateTime.parse(dateOfBirth).millisecondsSinceEpoch;
  return max(14, ms ~/ _yearMs);
}

/// The AI is non-deterministic, so anything outside a sane calorie band — or
/// whose macros don't add back up to the calorie total — is rejected.
bool isPlausible(Plan plan) {
  final numbers = [plan.calories, plan.protein, plan.carbs, plan.fat];
  if (numbers.any((n) => n < 0)) return false;
  if (plan.calories < 1200 || plan.calories > 5000) return false;

  final fromMacros = plan.protein * 4 + plan.carbs * 4 + plan.fat * 9;
  return (fromMacros - plan.calories).abs() <= plan.calories * 0.15;
}

const _activityFactor = {
  'sedentary': 1.2,
  'light': 1.375,
  'moderate': 1.55,
  'very': 1.725,
  'extra': 1.9,
};

const _split = {
  'classic': [0.3, 0.4, 0.3],
  'keto': [0.25, 0.1, 0.65],
  'vegan': [0.25, 0.5, 0.25],
  'vegetarian': [0.25, 0.5, 0.25],
};

/// Mifflin-St Jeor, so the user always gets a number. Until the Supabase Edge
/// Function exists this is the whole plan; afterwards it's the AI's fallback.
Plan formulaPlan(PlanInput input, {DateTime? now}) {
  final bmr =
      10 * input.weightKg +
      6.25 * input.heightCm -
      5 * ageFrom(input.dateOfBirth, now: now) +
      (input.gender == 'female' ? -161 : 5);

  final tdee = bmr * _activityFactor[input.activityLevel]!;
  final dailyDelta = input.paceKgPerWeek * 7700 / 7; // ~7700 kcal per kg
  final raw = switch (input.goal) {
    'lose' => tdee - dailyDelta,
    'gain' => tdee + dailyDelta,
    _ => tdee,
  };

  final calories = (raw.clamp(1200, 5000) / 10).round() * 10;
  final [p, c, f] = _split[input.dietPreference]!;

  return Plan(
    calories: calories,
    protein: (calories * p / 4).round(),
    carbs: (calories * c / 4).round(),
    fat: (calories * f / 9).round(),
    rationale:
        'Based on your body stats and activity level, adjusted for your goal to ${input.goal} weight.',
  );
}
