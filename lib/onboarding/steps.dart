import 'package:flutter/material.dart';

import '../plan/plan.dart';

const _yearMs = 31557600000;

String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The questionnaire's answers, keyed by [PlanInput] field name.
///
/// Plain module state for now — persist it (shared_preferences) once the flow
/// needs to survive the app being killed mid-questionnaire.
final Map<String, Object> answers = _defaults();

Map<String, Object> _defaults() => {
  'dateOfBirth': isoDate(
    DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch - 25 * _yearMs,
    ),
  ),
  'heightCm': 175.0,
  'weightKg': 70.0,
  'targetWeightKg': 70.0,
  'paceKgPerWeek': 0.5,
};

void resetAnswers() => answers
  ..clear()
  ..addAll(_defaults());

PlanInput? answersAsInput() {
  if (steps.any((s) => answers[s.field] == null)) return null;
  return PlanInput(
    gender: answers['gender'] as String,
    dateOfBirth: answers['dateOfBirth'] as String,
    heightCm: answers['heightCm'] as double,
    weightKg: answers['weightKg'] as double,
    goal: answers['goal'] as String,
    targetWeightKg: answers['targetWeightKg'] as double,
    activityLevel: answers['activityLevel'] as String,
    paceKgPerWeek: answers['paceKgPerWeek'] as double,
    dietPreference: answers['dietPreference'] as String,
  );
}

/// The plan generated from [answers], held between the reveal screen and sign-up.
Plan? draftPlan;

class StepOption {
  const StepOption(
    this.value,
    this.title, {
    this.subtitle,
    this.icon,
    this.glyph,
  });

  final String value;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? glyph;
}

sealed class OnboardingStep {
  const OnboardingStep({
    required this.key,
    required this.field,
    required this.title,
    required this.subtitle,
  });

  final String key;
  final String field;
  final String title;
  final String subtitle;
}

class CardsStep extends OnboardingStep {
  const CardsStep({
    required super.key,
    required super.field,
    required super.title,
    required super.subtitle,
    required this.options,
    this.tall = false,
  });

  final List<StepOption> options;
  final bool tall;
}

class RulerStep extends OnboardingStep {
  const RulerStep({
    required super.key,
    required super.field,
    required super.title,
    required super.subtitle,
    required this.unit,
    required this.min,
    required this.max,
    required this.increment,
    this.decimals = 0,
    this.labelEvery = 5,
    this.labelDecimals = 0,
    this.note,
  });

  final String unit;
  final double min;
  final double max;
  final double increment;
  final int decimals;
  final int labelEvery;
  final int labelDecimals;
  final String? Function(double value)? note;
}

class DateStep extends OnboardingStep {
  const DateStep({
    required super.key,
    required super.field,
    required super.title,
    required super.subtitle,
  });
}

final List<OnboardingStep> steps = [
  const CardsStep(
    key: 'gender',
    field: 'gender',
    tall: true,
    title: "Let's get to know you better",
    subtitle: 'This helps us personalize your plan and recommendations.',
    options: [
      StepOption('male', 'Male', icon: Icons.male),
      StepOption('female', 'Female', icon: Icons.female),
    ],
  ),
  const DateStep(
    key: 'birthday',
    field: 'dateOfBirth',
    title: "When's your birthday?",
    subtitle: 'Age changes how many calories your body burns at rest.',
  ),
  const RulerStep(
    key: 'height',
    field: 'heightCm',
    title: "What's your height?",
    subtitle: "We'll use this to calculate your calorie needs.",
    unit: 'cm',
    min: 120,
    max: 220,
    increment: 1,
  ),
  const RulerStep(
    key: 'weight',
    field: 'weightKg',
    title: "What's your current weight?",
    subtitle: 'This helps us understand your starting point.',
    unit: 'kg',
    min: 35,
    max: 200,
    increment: 0.5,
    decimals: 1,
    labelEvery: 4,
  ),
  const CardsStep(
    key: 'goal',
    field: 'goal',
    title: "What's your main goal?",
    subtitle: "We'll build your plan around this.",
    options: [
      StepOption(
        'lose',
        'Lose weight',
        subtitle: 'Shed fat at a steady pace',
        icon: Icons.trending_down,
      ),
      StepOption(
        'maintain',
        'Maintain weight',
        subtitle: 'Stay where you are',
        icon: Icons.trending_flat,
      ),
      StepOption(
        'gain',
        'Gain weight',
        subtitle: 'Build size and strength',
        icon: Icons.trending_up,
      ),
    ],
  ),
  const RulerStep(
    key: 'target-weight',
    field: 'targetWeightKg',
    title: "What's your goal weight?",
    subtitle: 'Where do you want to be?',
    unit: 'kg',
    min: 35,
    max: 200,
    increment: 0.5,
    decimals: 1,
    labelEvery: 4,
  ),
  const CardsStep(
    key: 'activity',
    field: 'activityLevel',
    title: 'How active are you during the day?',
    subtitle: 'This helps us estimate your daily calorie needs.',
    options: [
      StepOption(
        'sedentary',
        'Sedentary',
        subtitle: 'Little or no exercise',
        icon: Icons.weekend_outlined,
      ),
      StepOption(
        'light',
        'Lightly active',
        subtitle: '1–3 days per week',
        icon: Icons.directions_walk,
      ),
      StepOption(
        'moderate',
        'Moderately active',
        subtitle: '3–5 days per week',
        icon: Icons.fitness_center,
      ),
      StepOption(
        'very',
        'Very active',
        subtitle: '6–7 days per week',
        icon: Icons.directions_run,
      ),
      StepOption(
        'extra',
        'Extra active',
        subtitle: 'Very intense daily activity or physical job',
        icon: Icons.local_fire_department_outlined,
      ),
    ],
  ),
  RulerStep(
    key: 'pace',
    field: 'paceKgPerWeek',
    title: 'How fast do you want to move?',
    subtitle: 'You can change this later at any time.',
    unit: 'kg / week',
    min: 0.1,
    max: 1.5,
    increment: 0.1,
    decimals: 1,
    labelEvery: 5,
    labelDecimals: 1,
    note: (v) => v >= 1
        ? "That's an aggressive pace — it's harder to stick with, and to keep muscle."
        : null,
  ),
  const CardsStep(
    key: 'diet',
    field: 'dietPreference',
    title: 'Any diet preference?',
    subtitle: 'We shape your macro split around how you like to eat.',
    options: [
      StepOption(
        'classic',
        'Classic',
        subtitle: 'A bit of everything',
        icon: Icons.restaurant,
      ),
      StepOption(
        'keto',
        'Keto',
        subtitle: 'Low carb, high fat',
        icon: Icons.local_fire_department_outlined,
      ),
      StepOption(
        'vegan',
        'Vegan',
        subtitle: 'No animal products',
        icon: Icons.eco_outlined,
      ),
      StepOption(
        'vegetarian',
        'Vegetarian',
        subtitle: 'No meat or fish',
        icon: Icons.spa_outlined,
      ),
    ],
  ),
];

int stepIndex(String key) => steps.indexWhere((s) => s.key == key);
