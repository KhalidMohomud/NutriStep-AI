import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutristep_ai/state/session.dart';
import 'package:nutristep_ai/widgets/sheets.dart';

void main() {
  testWidgets('portion chip rescales the numbers', (t) async {
    t.view.physicalSize = const Size(393 * 3, 852 * 3);
    t.view.devicePixelRatio = 3;
    final meal = Meal(
      id: 'm',
      image: '',
      status: MealStatus.completed,
      loggedAt: DateTime.now(),
      name: 'Rice',
      calories: 540,
      protein: 42,
      carbs: 55,
      fat: 12,
    );
    session.addMeal(meal);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => showEditMealSheet(c, meal),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('½'), warnIfMissed: true);
    await t.pumpAndSettle();
    expect(find.text('270 kcal'), findsOneWidget);
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(session.mealById('m')!.calories, 270);
  });
}
