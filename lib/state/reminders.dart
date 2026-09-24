import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

String _thousands(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// Step notifications, made on the phone — no server, no push service.
///
/// - Every evening at [summaryHour]: "You've walked 6,842 steps so far today".
///   The number is the last one the app saw, so the notification is
///   rescheduled each time the count changes.
/// - On days the app isn't opened, a plain nudge fires at that time instead
///   (the app can't read the count without running).
/// - Once a day, when the goal is reached: "10,000 steps!".
class StepReminders {
  static const summaryHour = 20;
  static const _enabledKey = 'reminders.steps';
  static const _goalShownKey = 'reminders.goalShownOn';

  // one id per notification, so rescheduling replaces rather than stacks
  static const _todayId = 1;
  static const _nudgeId = 2;
  static const _goalId = 3;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool enabled = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'steps',
      'Step summary',
      channelDescription: 'Your daily steps, every evening',
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // permission is asked when they switch reminders on, not at launch
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      enabled =
          (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? false;
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  /// Asks the OS for permission. Returns whether reminders are now on.
  Future<bool> enable() async {
    if (!_ready) return false;
    final granted = defaultTargetPlatform == TargetPlatform.iOS
        ? await _plugin
                  .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin
                  >()
                  ?.requestPermissions(alert: true, sound: true) ??
              false
        : await _plugin
                  .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin
                  >()
                  ?.requestNotificationsPermission() ??
              false;
    enabled = granted;
    await (await SharedPreferences.getInstance()).setBool(_enabledKey, granted);
    return granted;
  }

  Future<void> disable() async {
    enabled = false;
    await (await SharedPreferences.getInstance()).setBool(_enabledKey, false);
    if (_ready) await _plugin.cancelAll();
  }

  /// Called whenever today's count changes.
  Future<void> update(int steps, int goal) async {
    if (!_ready || !enabled) return;
    try {
      final now = tz.TZDateTime.now(tz.local);
      final tonight = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        summaryHour,
      );

      // tonight's summary, with the latest count
      if (now.isBefore(tonight)) {
        final left = goal - steps;
        await _plugin.zonedSchedule(
          id: _todayId,
          scheduledDate: tonight,
          title: "You've walked ${_thousands(steps)} steps today 👟",
          body: left > 0
              ? '${_thousands(left)} more to reach ${_thousands(goal)}. A short evening walk gets you there.'
              : 'Goal reached — great work today! 🎉',
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }

      // the nudge repeats daily from tomorrow; opening the app pushes it back again
      await _plugin.zonedSchedule(
        id: _nudgeId,
        scheduledDate: tonight.add(const Duration(days: 1)),
        title: 'How many steps today? 👟',
        body: 'Open NutriStep to see your steps and log dinner.',
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      // the goal, once a day
      if (steps >= goal) {
        final prefs = await SharedPreferences.getInstance();
        final today = '${now.year}-${now.month}-${now.day}';
        if (prefs.getString(_goalShownKey) != today) {
          await prefs.setString(_goalShownKey, today);
          await _plugin.show(
            id: _goalId,
            title: '${_thousands(goal)} steps! 🎉',
            body: 'You hit your step goal today. Keep it going tomorrow.',
            notificationDetails: _details,
          );
        }
      }
    } catch (e) {
      debugPrint('Could not schedule step notifications: $e');
    }
  }
}
