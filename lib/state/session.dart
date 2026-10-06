import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        AuthException,
        FileOptions,
        FunctionException,
        OAuthProvider,
        SignedUrlSuccess;

import '../plan/plan.dart';
import '../theme/macros.dart';
import 'backend.dart';
import 'background.dart';
import 'reminders.dart';
import 'steps.dart';

class Profile {
  const Profile({
    required this.input,
    required this.plan,
    required this.timezone,
    required this.memberSince,
  });

  final PlanInput input;
  final Plan plan;
  final String timezone;
  final DateTime memberSince;
}

enum MealStatus { analyzing, completed }

class Meal {
  const Meal({
    required this.id,
    required this.image,
    required this.status,
    required this.loggedAt,
    this.imagePath,
    this.name = '',
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  final String id;

  /// What to draw: a signed https URL, a local file path (just taken), or an
  /// asset path (demo mode). See `mealImageProvider`.
  final String image;

  /// The photo's path in the meal-photos bucket, for rows from the database.
  final String? imagePath;
  final MealStatus status;
  final DateTime loggedAt;
  final String name;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  int grams(Macro macro) => switch (macro) {
    Macro.protein => protein,
    Macro.carbs => carbs,
    Macro.fat => fat,
  };

  Meal copyWith({
    String? name,
    int? calories,
    int? protein,
    int? carbs,
    int? fat,
  }) => Meal(
    id: id,
    image: image,
    imagePath: imagePath,
    status: status,
    loggedAt: loggedAt,
    name: name ?? this.name,
    calories: calories ?? this.calories,
    protein: protein ?? this.protein,
    carbs: carbs ?? this.carbs,
    fat: fat ?? this.fat,
  );

  /// "I ate half of it": every number scaled together, rounded.
  Meal scaled(double factor) => copyWith(
    calories: (calories * factor).round(),
    protein: (protein * factor).round(),
    carbs: (carbs * factor).round(),
    fat: (fat * factor).round(),
  );
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// "khalid.mohamud@gmail.com" → "Khalid Mohamud", "qaalidsome@gmail.com" →
/// "Qaalidsome". Digit-only parts ("ali_99") are dropped; null if nothing's left.
String? nameFromEmail(String email) {
  final name = email
      .split('@')
      .first
      .split(RegExp(r'[._\-+]+'))
      .where((w) => w.isNotEmpty && !RegExp(r'^\d+$').hasMatch(w))
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
  return name.isEmpty ? null : name;
}

/// How a scan ended.
sealed class ScanResult {
  const ScanResult();
}

class ScanSuccess extends ScanResult {
  const ScanSuccess(this.meal);
  final Meal meal;
}

class ScanNotFood extends ScanResult {
  const ScanNotFood();
}

class ScanQuotaReached extends ScanResult {
  const ScanQuotaReached(this.limit);
  final int limit;
}

class ScanFailed extends ScanResult {
  const ScanFailed();
}

/// What the demo scan "finds" when there's no backend.
const _demoResult = (
  name: 'Grilled chicken & rice',
  calories: 540,
  protein: 42,
  carbs: 55,
  fat: 12,
);

/// Long edge of the uploaded photo. The model downsamples anyway; this keeps
/// uploads ~100 KB and Gemini's image tokens low.
const _uploadEdge = 1024;

class CoachTurn {
  const CoachTurn({required this.fromUser, required this.text});
  final bool fromUser;
  final String text;
}

/// How a coach question ended.
sealed class CoachReply {
  const CoachReply();
}

class CoachAnswer extends CoachReply {
  const CoachAnswer(this.text, {this.used, this.limit});
  final String text;
  final int? used;
  final int? limit;
}

class CoachQuotaReached extends CoachReply {
  const CoachQuotaReached(this.limit);
  final int limit;
}

class CoachFailed extends CoachReply {
  const CoachFailed();
}

/// What an email sign-up ended in.
enum SignUpOutcome { signedIn, confirmEmail }

/// Who is signed in, their saved profile and their meals.
///
/// With Supabase configured ([backendEnabled]) everything is real: Supabase
/// Auth, the user's `profiles` row, and `meals` written by the `analyze-meal`
/// Edge Function. Without it, everything is in memory (demo mode). The screens
/// only ever talk to this object, so none of that reaches them.
class Session extends ChangeNotifier {
  bool _demoSignedIn = false;
  Profile? _profile;
  final List<Meal> _meals = [];

  bool get isSignedIn =>
      backendEnabled ? supabase.auth.currentSession != null : _demoSignedIn;
  Profile? get profile => _profile;

  // ── steps ──────────────────────────────────────────────────────────────────

  final _steps = StepCounter();
  StepsStatus stepsStatus = StepsStatus.notConnected;

  // ── preferences ────────────────────────────────────────────────────────────
  // Kept on the device and, when signed in, on the profile row, so they follow
  // the account to a new phone.

  int stepGoal = 10000;
  int reminderHour = 20;

  /// en | so | ar — the language the AI answers in (meal names, the coach).
  String language = 'en';

  Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      stepGoal = prefs.getInt('pref.stepGoal') ?? stepGoal;
      reminderHour = prefs.getInt('pref.reminderHour') ?? reminderHour;
      language = prefs.getString('pref.language') ?? language;
    } catch (e) {
      debugPrint('Could not read preferences: $e');
    }
  }

  Future<void> updatePreferences({
    int? stepGoal,
    int? reminderHour,
    String? language,
  }) async {
    this.stepGoal = stepGoal ?? this.stepGoal;
    this.reminderHour = reminderHour ?? this.reminderHour;
    this.language = language ?? this.language;
    notifyListeners();
    reminders.update(stepsToday, this.stepGoal, this.reminderHour);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('pref.stepGoal', this.stepGoal);
      await prefs.setInt('pref.reminderHour', this.reminderHour);
      await prefs.setString('pref.language', this.language);
    } catch (e) {
      debugPrint('Could not save preferences: $e');
    }

    final user = backendEnabled ? supabase.auth.currentUser : null;
    if (user == null) return;
    try {
      await supabase
          .from('profiles')
          .update({
            'step_goal': this.stepGoal,
            'reminder_hour': this.reminderHour,
            'language': this.language,
          })
          .eq('id', user.id);
    } catch (e) {
      // e.g. the preferences migration isn't pushed yet — the device copy still holds
      debugPrint('Could not sync preferences: $e');
    }
  }

  final reminders = StepReminders();
  bool get remindersOn => reminders.enabled;

  Future<void> setReminders(bool on) async {
    if (on) {
      await reminders.enable();
      if (reminders.enabled) {
        await reminders.update(stepsToday, stepGoal, reminderHour);
        // hourly, even with the app closed, so 8 PM shows the real count
        await startBackgroundSteps();
      }
    } else {
      await reminders.disable();
      await stopBackgroundSteps();
    }
    notifyListeners();
  }

  /// The evening summary, right now — so it can be checked without waiting.
  /// Asks for permission first if reminders were never switched on.
  Future<bool> sendTestReminder() async {
    if (!reminders.enabled) await setReminders(true);
    if (!reminders.enabled) return false;
    await refreshSteps();
    return reminders.showTest(stepsToday, stepGoal);
  }

  /// Today's step count, kept live while the app is open.
  int stepsToday = 0;
  int _syncedSteps = -1;
  DateTime _syncedAt = DateTime(0);

  /// On launch: carry on counting if the user connected before, without asking again.
  Future<void> resumeSteps() async {
    if (stepsStatus == StepsStatus.connected) return;
    if (!await _steps.wasConnected()) return;
    stepsStatus = StepsStatus.connected;
    _steps.onSteps = _setSteps;
    await refreshSteps();
  }

  /// The "Count my steps" button: asks for permission, then starts counting.
  Future<void> connectSteps() async {
    _steps.onSteps = _setSteps;
    stepsStatus = await _steps.connect();
    notifyListeners();
    if (stepsStatus == StepsStatus.connected) {
      await refreshSteps();
      // counting steps and hearing about them go together — one OS prompt, right here
      if (!reminders.enabled) await setReminders(true);
    }
  }

  Future<void> refreshSteps() async {
    if (stepsStatus != StepsStatus.connected) return;
    _setSteps(await _steps.refresh());
    // on every open/resume, even when the count hasn't moved since last time
    await reminders.update(stepsToday, stepGoal, reminderHour);
  }

  void _setSteps(int steps) {
    if (steps == stepsToday) return;
    stepsToday = steps;
    notifyListeners();
    _syncSteps();
    reminders.update(steps, stepGoal, reminderHour);
  }

  /// Today's total into activity_logs — at most every few minutes, not every step.
  Future<void> _syncSteps() async {
    if (!backendEnabled || stepsToday == _syncedSteps) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final sinceSync = DateTime.now().difference(_syncedAt);
    if (sinceSync < const Duration(minutes: 3)) return;
    _syncedAt = DateTime.now();
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    try {
      await supabase.from('activity_logs').upsert({
        'user_id': user.id,
        'date': date,
        'steps': stepsToday,
        'synced_at': now.toUtc().toIso8601String(),
      }, onConflict: 'user_id,date');
      _syncedSteps = stepsToday;
    } catch (e) {
      debugPrint('Step sync failed: $e');
    }
  }

  String? get email => backendEnabled ? supabase.auth.currentUser?.email : null;

  String? _displayName;

  /// What to call them: the name they set, else one made from their email.
  /// Nobody is asked for it.
  String? get displayName {
    final name = _displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final e = email;
    return e == null ? null : nameFromEmail(e);
  }

  bool get hasName => (_displayName?.trim() ?? '').isNotEmpty;

  Future<void> updateDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (backendEnabled) {
      final user = supabase.auth.currentUser;
      if (user == null) throw StateError('Not signed in');
      await supabase
          .from('profiles')
          .update({'display_name': trimmed})
          .eq('id', user.id);
    }
    _displayName = trimmed;
    notifyListeners();
  }

  /// Restores a saved session's profile before the first frame, so a returning
  /// user lands on Home instead of flashing through onboarding.
  Future<void> restore() async {
    if (!backendEnabled || !isSignedIn) return;
    try {
      await _loadAccount();
    } catch (e) {
      // offline: the tabs' gate sends them to onboarding
      debugPrint('Could not load account: $e');
    }
  }

  /// Demo mode's stand-in for every sign-in button.
  void signInDemo() {
    _demoSignedIn = true;
    notifyListeners();
  }

  /// Returns an error message to show, or null on success.
  Future<String?> signInWithEmail(String email, String password) async {
    try {
      await supabase.auth.signInWithPassword(email: email, password: password);
      await _loadAccount();
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  static bool get googleConfigured =>
      backendEnabled &&
      googleWebClientId != '' &&
      (defaultTargetPlatform != TargetPlatform.iOS || googleIosClientId != '');

  bool _googleReady = false;

  /// Native Google sheet → ID token → Supabase session. Returns an error message
  /// to show, or null — which covers the user closing the sheet, too.
  Future<String?> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    try {
      if (!_googleReady) {
        await google.initialize(
          clientId: defaultTargetPlatform == TargetPlatform.iOS
              ? googleIosClientId
              : null,
          serverClientId: googleWebClientId,
        );
        _googleReady = true;
      }
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) return 'Google did not return an ID token.';

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      await _loadAccount();
      notifyListeners();
      return null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      debugPrint('Google sign-in failed: $e');
      return 'Google sign-in failed. Please try again.';
    } on AuthException catch (e) {
      return e.message;
    }
  }

  /// Throws [AuthException] with a message to show.
  Future<SignUpOutcome> signUpWithEmail(
    String email,
    String password, {
    String? name,
  }) async {
    // the name rides along as metadata too, so it survives an email-confirm detour
    final res = await supabase.auth.signUp(
      email: email,
      password: password,
      data: name == null || name.trim().isEmpty
          ? null
          : {'display_name': name.trim()},
    );
    // with "Confirm email" on (the Supabase default) there's no session until
    // they tap the link in their inbox
    if (res.session == null) return SignUpOutcome.confirmEmail;
    await _loadAccount();
    notifyListeners();
    return SignUpOutcome.signedIn;
  }

  Future<void> _loadAccount() async {
    await loadProfile();
    await loadMeals();
  }

  Future<void> loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final row = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    _profile = row == null ? null : _profileFromRow(row);
    _displayName = row?['display_name'] as String?;
    if (row != null) {
      stepGoal = (row['step_goal'] as int?) ?? stepGoal;
      reminderHour = (row['reminder_hour'] as int?) ?? reminderHour;
      language = (row['language'] as String?) ?? language;
    }

    // given at sign-up but not saved yet (the row is made by a trigger)
    final pending = user.userMetadata?['display_name'] as String?;
    if (!hasName && pending != null && pending.trim().isNotEmpty) {
      try {
        await updateDisplayName(pending);
      } catch (e) {
        debugPrint('Could not save name: $e');
      }
    }
  }

  Future<void> saveProfile(Profile profile) async {
    if (backendEnabled) {
      final user = supabase.auth.currentUser;
      if (user == null) throw StateError('Not signed in');
      final i = profile.input;
      final now = DateTime.now().toUtc().toIso8601String();
      final saved = await supabase
          .from('profiles')
          .update({
            'timezone': profile.timezone,
            'gender': i.gender,
            'date_of_birth': i.dateOfBirth,
            'height_cm': i.heightCm,
            'weight_kg': i.weightKg,
            'goal': i.goal,
            'target_weight_kg': i.targetWeightKg,
            'activity_level': i.activityLevel,
            'pace_kg_per_week': i.paceKgPerWeek,
            'diet_preference': i.dietPreference,
            'daily_calories': profile.plan.calories,
            'protein_g': profile.plan.protein,
            'carbs_g': profile.plan.carbs,
            'fat_g': profile.plan.fat,
            'plan_rationale': profile.plan.rationale,
            'plan_source': 'formula', // 'ai' once generate-plan runs on Gemini
            'plan_generated_at': now,
            'onboarding_completed_at': now,
          })
          .eq('id', user.id)
          .select('id');
      // an account made before the schema existed has no profile row to update
      if (saved.isEmpty) throw StateError('No profile row for ${user.id}');
    }
    _profile = profile;
    notifyListeners();
  }

  Future<void> signOut() async {
    if (backendEnabled) {
      await supabase.auth.signOut();
      // so the next Google sign-in offers the account picker again
      if (_googleReady) await GoogleSignIn.instance.signOut();
    }
    _demoSignedIn = false;
    _profile = null;
    _displayName = null;
    _meals.clear();
    coachTurns.clear();
    notifyListeners();
  }

  /// Erases the account everywhere (photos, rows, login), then signs out.
  /// Throws if the server couldn't finish — the account still works then.
  Future<void> deleteAccount() async {
    if (backendEnabled) await supabase.functions.invoke('delete-account');
    await signOut();
  }

  /// "Send feedback" — straight into the feedback table.
  Future<void> sendFeedback(String message) async {
    final text = message.trim();
    if (text.isEmpty) return;
    if (!backendEnabled) return;
    await supabase.from('feedback').insert({
      'user_id': supabase.auth.currentUser?.id,
      'message': text,
      'app_info': '${defaultTargetPlatform.name} · NutriStep AI',
    });
  }

  // ── AI coach ───────────────────────────────────────────────────────────────

  /// This session's conversation — not stored; it starts fresh on next launch.
  final List<CoachTurn> coachTurns = [];
  bool coachThinking = false;

  Future<CoachReply> askCoach(String question) async {
    final text = question.trim();
    if (text.isEmpty || coachThinking) return const CoachFailed();
    coachTurns.add(CoachTurn(fromUser: true, text: text));
    coachThinking = true;
    notifyListeners();

    CoachReply reply;
    try {
      reply = backendEnabled ? await _askServer() : await _askDemo(text);
    } catch (e) {
      debugPrint('Coach failed: $e');
      reply = const CoachFailed();
    }
    if (reply case CoachAnswer(:final text)) {
      coachTurns.add(CoachTurn(fromUser: false, text: text));
    } else {
      coachTurns.removeLast(); // so "try again" resends it
    }
    coachThinking = false;
    notifyListeners();
    return reply;
  }

  Future<CoachReply> _askServer() async {
    try {
      final res = await supabase.functions.invoke(
        'ai-coach',
        body: {
          'messages': [
            for (final t in coachTurns)
              {'role': t.fromUser ? 'user' : 'model', 'text': t.text},
          ],
          'utc_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
        },
      );
      final data = res.data as Map;
      return CoachAnswer(
        data['reply'] as String,
        used: (data['used'] as num?)?.toInt(),
        limit: (data['limit'] as num?)?.toInt(),
      );
    } on FunctionException catch (e) {
      final details = e.details is Map ? e.details as Map : const {};
      return e.status == 429
          ? CoachQuotaReached((details['limit'] as num?)?.toInt() ?? 3)
          : const CoachFailed();
    }
  }

  Future<CoachReply> _askDemo(String question) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final left =
        (profile?.plan.calories ?? 2000) -
        mealsOn(DateTime.now()).fold(0, (t, m) => t + m.calories);
    return CoachAnswer(
      'You have about $left kcal left today. A plate of grilled chicken, rice and '
      'vegetables would fit well and keep your protein up.',
    );
  }

  /// The last five weeks — everything the date strip can reach, with room.
  Future<void> loadMeals() async {
    final since = DateTime.now().subtract(const Duration(days: 35)).toUtc();
    final rows = await supabase
        .from('meals')
        .select(
          'id, image_path, status, name, calories, protein_g, carbs_g, fat_g, logged_at',
        )
        .eq('status', 'completed')
        .gte('logged_at', since.toIso8601String())
        .order('logged_at', ascending: false)
        .limit(500);

    // private bucket: thumbnails load through short-lived signed URLs
    final paths = [for (final r in rows) r['image_path'] as String];
    final urls = <String, String>{};
    if (paths.isNotEmpty) {
      final signed = await supabase.storage
          .from('meal-photos')
          .createSignedUrlsResult(paths, 60 * 60 * 6);
      for (final u in signed) {
        // a photo that's gone just leaves the thumbnail blank
        if (u case SignedUrlSuccess(:final path, :final signedUrl)) {
          urls[path] = signedUrl;
        }
      }
    }

    _meals
      ..clear()
      ..addAll([
        for (final r in rows) _mealFromRow(r, urls[r['image_path']] ?? ''),
      ]);
    notifyListeners();
  }

  /// Photo → meal. It shows on Home straight away as analyzing, then becomes the
  /// real row — or disappears if it wasn't a meal after all.
  Future<ScanResult> scanMeal(String photo) async {
    final pendingId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    addMeal(
      Meal(
        id: pendingId,
        image: photo,
        status: MealStatus.analyzing,
        loggedAt: DateTime.now(),
      ),
    );

    ScanResult result;
    try {
      result = backendEnabled
          ? await _scanOnServer(photo)
          : await _scanDemo(photo);
    } catch (e) {
      debugPrint('Scan failed: $e');
      result = const ScanFailed();
    }

    _meals.removeWhere((m) => m.id == pendingId);
    if (result case ScanSuccess(:final meal)) _meals.add(meal);
    notifyListeners();
    return result;
  }

  Future<ScanResult> _scanDemo(String photo) async {
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    return ScanSuccess(
      Meal(
        id: 'demo-${DateTime.now().microsecondsSinceEpoch}',
        image: photo,
        status: MealStatus.completed,
        loggedAt: DateTime.now(),
        name: _demoResult.name,
        calories: _demoResult.calories,
        protein: _demoResult.protein,
        carbs: _demoResult.carbs,
        fat: _demoResult.fat,
      ),
    );
  }

  Future<ScanResult> _scanOnServer(String photo) async {
    final user = supabase.auth.currentUser;
    if (user == null) return const ScanFailed();

    final bytes = await _downsize(photo);
    final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await supabase.storage
        .from('meal-photos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );

    try {
      final res = await supabase.functions.invoke(
        'analyze-meal',
        body: {
          'image_path': path,
          'utc_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
        },
      );
      final row = ((res.data as Map)['meal'] as Map).cast<String, dynamic>();
      // the local file is already on screen; no need to fetch it back
      return ScanSuccess(_mealFromRow(row, photo));
    } on FunctionException catch (e) {
      final details = e.details is Map ? e.details as Map : const {};
      return switch (e.status) {
        429 => ScanQuotaReached((details['limit'] as num?)?.toInt() ?? 2),
        422 => const ScanNotFood(),
        _ => const ScanFailed(),
      };
    }
  }

  /// A phone photo is 3–5 MB; the bucket takes 1 MB and the model needs far less.
  Future<Uint8List> _downsize(String photo) async {
    try {
      final out = await FlutterImageCompress.compressWithFile(
        photo,
        minWidth: _uploadEdge,
        minHeight: _uploadEdge,
        quality: 70,
      );
      if (out != null) return out;
    } catch (e) {
      debugPrint('Compression unavailable: $e');
    }
    // no compressor: send the original if the bucket will take it
    final raw = await File(photo).readAsBytes();
    if (raw.length > 1024 * 1024) throw StateError('Photo too large to upload');
    return raw;
  }

  /// A local day's meals, newest first.
  List<Meal> mealsOn(DateTime day) =>
      _meals.where((m) => _day(m.loggedAt) == _day(day)).toList()
        ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

  void addMeal(Meal meal) {
    _meals.add(meal);
    notifyListeners();
  }

  Meal? mealById(String id) {
    for (final m in _meals) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Saves a corrected meal (portion or numbers). Shows at once; rolls back
  /// and rethrows if the server says no.
  Future<void> updateMeal(Meal meal) async {
    final i = _meals.indexWhere((m) => m.id == meal.id);
    if (i < 0) return;
    final before = _meals[i];
    _meals[i] = meal;
    notifyListeners();

    if (!backendEnabled) return;
    try {
      await supabase
          .from('meals')
          .update({
            'name': meal.name,
            'calories': meal.calories,
            'protein_g': meal.protein,
            'carbs_g': meal.carbs,
            'fat_g': meal.fat,
            'source': 'user_corrected',
          })
          .eq('id', meal.id);
    } catch (e) {
      debugPrint('Meal update failed, restoring: $e');
      _meals[i] = before;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteMeal(String id) async {
    final meal = mealById(id);
    _meals.removeWhere((m) => m.id == id);
    notifyListeners();

    if (!backendEnabled || meal == null) return;
    try {
      await supabase.from('meals').delete().eq('id', id);
      if (meal.imagePath != null) {
        await supabase.storage.from('meal-photos').remove([meal.imagePath!]);
      }
    } catch (e) {
      debugPrint('Delete failed, restoring: $e');
      _meals.add(meal);
      notifyListeners();
      rethrow;
    }
  }

  /// Consecutive days with at least one meal, ending today — or yesterday, so the
  /// streak doesn't read 0 before you've eaten today.
  int get streak {
    final days = _meals.map((m) => _day(m.loggedAt)).toSet();
    var day = _day(DateTime.now());
    if (!days.contains(day)) day = day.subtract(const Duration(days: 1));

    var count = 0;
    while (days.contains(day)) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }
}

Meal _mealFromRow(Map<String, dynamic> r, String image) => Meal(
  id: r['id'] as String,
  image: image,
  imagePath: r['image_path'] as String?,
  status: r['status'] == 'completed'
      ? MealStatus.completed
      : MealStatus.analyzing,
  loggedAt: DateTime.parse(r['logged_at'] as String).toLocal(),
  name: (r['name'] as String?) ?? '',
  calories: (r['calories'] as int?) ?? 0,
  protein: (r['protein_g'] as int?) ?? 0,
  carbs: (r['carbs_g'] as int?) ?? 0,
  fat: (r['fat_g'] as int?) ?? 0,
);

/// A `profiles` row → [Profile], or null if they never finished onboarding.
Profile? _profileFromRow(Map<String, dynamic> r) {
  if (r['onboarding_completed_at'] == null) return null;
  double n(String k) => (r[k] as num).toDouble();
  return Profile(
    input: PlanInput(
      gender: r['gender'] as String,
      dateOfBirth: r['date_of_birth'] as String,
      heightCm: n('height_cm'),
      weightKg: n('weight_kg'),
      goal: r['goal'] as String,
      targetWeightKg: n('target_weight_kg'),
      activityLevel: r['activity_level'] as String,
      paceKgPerWeek: n('pace_kg_per_week'),
      dietPreference: r['diet_preference'] as String,
    ),
    plan: Plan(
      calories: r['daily_calories'] as int,
      protein: r['protein_g'] as int,
      carbs: r['carbs_g'] as int,
      fat: r['fat_g'] as int,
      rationale: (r['plan_rationale'] as String?) ?? '',
    ),
    timezone: (r['timezone'] as String?) ?? 'UTC',
    memberSince: DateTime.parse(r['created_at'] as String).toLocal(),
  );
}

final session = Session();
