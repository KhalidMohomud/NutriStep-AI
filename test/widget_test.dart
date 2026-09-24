import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/material.dart';
import 'package:nutristep_ai/main.dart';
import 'package:nutristep_ai/plan/plan.dart';
import 'package:nutristep_ai/state/session.dart';
import 'package:nutristep_ai/widgets/onboarding.dart';

void main() {
  testWidgets('Welcome screen shows the brand and CTA', (tester) async {
    await tester.pumpWidget(const NutriStepApp());

    expect(find.text('Calorie tracking made easy'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  group('formulaPlan', () {
    const input = PlanInput(
      gender: 'male',
      dateOfBirth: '2000-01-01',
      heightCm: 175,
      weightKg: 70,
      goal: 'lose',
      targetWeightKg: 65,
      activityLevel: 'moderate',
      paceKgPerWeek: 0.5,
      dietPreference: 'classic',
    );

    test('produces a plan the plausibility check accepts', () {
      final plan = formulaPlan(input, now: DateTime(2026, 9, 23));
      // age 26: BMR 1668.75 × 1.55 − 550 = 2036.6 → 2040
      expect(plan.calories, 2040);
      expect(isPlausible(plan), isTrue);
    });

    test('clamps to the 1200 kcal floor', () {
      const tiny = PlanInput(
        gender: 'female',
        dateOfBirth: '1950-01-01',
        heightCm: 140,
        weightKg: 40,
        goal: 'lose',
        targetWeightKg: 38,
        activityLevel: 'sedentary',
        paceKgPerWeek: 1.5,
        dietPreference: 'keto',
      );
      expect(formulaPlan(tiny).calories, 1200);
    });
  });

  group('streak', () {
    Meal at(DateTime d) => Meal(
      id: '${d.microsecondsSinceEpoch}',
      image: '',
      status: MealStatus.completed,
      loggedAt: d,
    );
    final now = DateTime.now();
    DateTime daysAgo(int n) => DateTime(now.year, now.month, now.day - n, 12);

    test('counts consecutive days ending today', () {
      final s = Session()
        ..addMeal(at(daysAgo(0)))
        ..addMeal(at(daysAgo(1)))
        ..addMeal(at(daysAgo(2)))
        ..addMeal(at(daysAgo(4))); // gap: doesn't count
      expect(s.streak, 3);
    });

    test("hasn't broken yet when only yesterday is logged", () {
      final s = Session()..addMeal(at(daysAgo(1)));
      expect(s.streak, 1);
    });

    test('is 0 with no meals', () => expect(Session().streak, 0));
  });

  testWidgets("the ruler doesn't change the value until it's touched", (
    tester,
  ) async {
    final changes = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RulerPicker(
            value: 175,
            onChanged: changes.add,
            min: 120,
            max: 220,
            increment: 1,
            unit: 'cm',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(changes, isEmpty);
    expect(find.text('175'), findsWidgets);
  });
}
