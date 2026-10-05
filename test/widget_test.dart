import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/material.dart';
import 'package:nutristep_ai/main.dart';
import 'package:nutristep_ai/plan/plan.dart';
import 'package:nutristep_ai/state/session.dart';
import 'package:nutristep_ai/screens/settings_screens.dart';
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

  test('a name is made from the email', () {
    expect(nameFromEmail('qaalidsome@gmail.com'), 'Qaalidsome');
    expect(nameFromEmail('khalid.mohamud@gmail.com'), 'Khalid Mohamud');
    expect(nameFromEmail('ali_99@yahoo.com'), 'Ali');
    expect(nameFromEmail('12345@test.com'), isNull);
  });

  test('a portion scales every number together', () {
    final m = Meal(
      id: 'm',
      image: '',
      status: MealStatus.completed,
      loggedAt: DateTime(2026),
      name: 'Rice bowl',
      calories: 540,
      protein: 42,
      carbs: 55,
      fat: 13,
    );
    final half = m.scaled(0.5);
    expect(
      [half.calories, half.protein, half.carbs, half.fat],
      [270, 21, 28, 7],
    );
    expect(half.name, 'Rice bowl');
    expect(m.scaled(2).calories, 1080);
  });

  test('reminder hours read like a clock', () {
    expect(hourLabel(20), '8 PM');
    expect(hourLabel(12), '12 PM');
    expect(hourLabel(0), '12 AM');
    expect(hourLabel(9), '9 AM');
  });

  test('the coach answers in demo mode and keeps the conversation', () async {
    final s = Session();
    final reply = await s.askCoach('What should I eat?');
    expect(reply, isA<CoachAnswer>());
    expect(s.coachTurns.map((t) => t.fromUser), [true, false]);
    expect(
      await s.askCoach('   '),
      isA<CoachFailed>(),
      reason: 'blank questions are not sent',
    );
  });
}
