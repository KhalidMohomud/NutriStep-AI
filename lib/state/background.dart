import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'reminders.dart';
import 'steps.dart';

/// Also the iOS BGTaskScheduler identifier (Info.plist, AppDelegate).
const stepsTaskId = 'com.ditalsolutions.nutristep.steps';

/// Runs in its own isolate, woken by the OS about once an hour — even with the
/// app closed — so the evening notification carries today's real count.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      if (!(prefs.getBool('reminders.steps') ?? false)) return true;

      final steps = await StepCounter().readOnce();
      if (steps == null) return true;

      final reminders = StepReminders();
      await reminders.init();
      await reminders.update(
        steps,
        prefs.getInt('pref.stepGoal') ?? 10000,
        prefs.getInt('pref.reminderHour') ?? 20,
      );
    } catch (e) {
      debugPrint('Background step refresh failed: $e');
    }
    return true; // never ask the OS to retry: the next run is an hour away anyway
  });
}

bool _initialized = false;

Future<void> _init() async {
  if (_initialized) return;
  await Workmanager().initialize(backgroundDispatcher);
  _initialized = true;
}

/// Starts (or keeps) the hourly refresh.
Future<void> startBackgroundSteps() async {
  try {
    await _init();
    await Workmanager().registerPeriodicTask(
      stepsTaskId,
      stepsTaskId,
      frequency: const Duration(hours: 1),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  } catch (e) {
    debugPrint('Background steps unavailable: $e');
  }
}

Future<void> stopBackgroundSteps() async {
  try {
    await _init();
    await Workmanager().cancelByUniqueName(stepsTaskId);
  } catch (e) {
    debugPrint('Could not stop background steps: $e');
  }
}
