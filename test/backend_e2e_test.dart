import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutristep_ai/plan/plan.dart';
import 'package:nutristep_ai/state/backend.dart';
import 'package:nutristep_ai/state/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs against a local Supabase (`supabase start`), skipped otherwise:
///   flutter test test/backend_e2e_test.dart --dart-define-from-file=env.local.json
/// The scan test also needs the function served against a fake Gemini
/// (`supabase functions serve` with GEMINI_API_BASE pointing at it).
void main() {
  setUpAll(() async {
    if (!backendEnabled) return;
    TestWidgetsFlutterBinding.ensureInitialized();
    // flutter_test blocks real HTTP; these tests want the local server
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    await initBackend();
  });

  test(
    'sign up → save profile → sign out → sign in → profile restored',
    skip: !backendEnabled,
    () async {
      final email = 'e2e${DateTime.now().millisecondsSinceEpoch}@test.com';
      final s = Session();
      expect(
        await s.signUpWithEmail(email, 'password123'),
        SignUpOutcome.signedIn,
      );
      expect(s.isSignedIn, isTrue);
      expect(s.profile, isNull, reason: 'fresh account has not onboarded');

      const input = PlanInput(
        gender: 'female',
        dateOfBirth: '1998-05-04',
        heightCm: 165,
        weightKg: 68,
        goal: 'lose',
        targetWeightKg: 60,
        activityLevel: 'light',
        paceKgPerWeek: 0.5,
        dietPreference: 'vegetarian',
      );
      await s.saveProfile(
        Profile(
          input: input,
          plan: formulaPlan(input),
          timezone: 'Africa/Mogadishu',
          memberSince: DateTime.now(),
        ),
      );

      await s.signOut();
      expect(s.isSignedIn, isFalse);
      expect(s.profile, isNull);

      expect(await s.signInWithEmail(email, 'wrong-password'), isNotNull);
      expect(await s.signInWithEmail(email, 'password123'), isNull);
      final p = s.profile!;
      expect(p.input.weightKg, 68);
      expect(p.input.dietPreference, 'vegetarian');
      expect(p.plan.calories, formulaPlan(input).calories);
      expect(p.timezone, 'Africa/Mogadishu');
      await s.signOut();
    },
  );

  test(
    'scan: upload → analyze-meal → meal row → reload → delete',
    skip: !backendEnabled,
    () async {
      final s = Session();
      final email = 'scan${DateTime.now().millisecondsSinceEpoch}@test.com';
      await s.signUpWithEmail(email, 'password123');
      const input = PlanInput(
        gender: 'male',
        dateOfBirth: '1995-01-01',
        heightCm: 180,
        weightKg: 80,
        goal: 'maintain',
        targetWeightKg: 80,
        activityLevel: 'moderate',
        paceKgPerWeek: 0.5,
        dietPreference: 'classic',
      );
      await s.saveProfile(
        Profile(
          input: input,
          plan: formulaPlan(input),
          timezone: 'UTC',
          memberSince: DateTime.now(),
        ),
      );

      final photo = '${Directory.systemTemp.path}/nutristep-test-meal.jpg';
      await File('assests/image/demo-meal.jpg').copy(photo);

      final result = await s.scanMeal(photo);
      expect(result, isA<ScanSuccess>());
      final meal = (result as ScanSuccess).meal;
      expect(meal.calories, greaterThan(0));
      expect(s.mealsOn(DateTime.now()).map((m) => m.id), [meal.id]);

      // a fresh session sees it from the database, with a signed photo URL
      await s.loadMeals();
      final loaded = s.mealsOn(DateTime.now()).single;
      expect(loaded.name, meal.name);
      expect(loaded.image, startsWith('http'));

      // the free allowance is 2 a day
      expect(await s.scanMeal(photo), isA<ScanSuccess>());
      expect(await s.scanMeal(photo), isA<ScanQuotaReached>());
      expect(
        s.mealsOn(DateTime.now()),
        hasLength(2),
        reason: 'a blocked scan leaves no meal',
      );

      await s.deleteMeal(loaded.id);
      await s.loadMeals();
      expect(s.mealsOn(DateTime.now()), hasLength(1));
      await s.signOut();
    },
  );
}
