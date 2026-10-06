import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StepsStatus {
  /// never asked — the Home card offers "Count my steps"
  notConnected,

  /// the user said no; only Settings can undo that
  denied,

  /// this device has nothing to count with (e.g. a simulator)
  unavailable,
  connected,
}

String _day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Today's step count, from whatever the phone can offer.
///
/// - iPhone: Apple Health. The phone counts on its own, all day, app open or not.
/// - Android: the phone's step sensor, plus Health Connect when it's there
///   (Samsung Health, Google Fit write to it). Both see the same walking, so
///   the higher of the two wins.
///
/// The Android sensor only reports steps since the phone booted. The count at
/// the start of each day is kept as a baseline; steps from the last reading
/// until the first one today are counted as today's (a small overcount beats
/// missing a morning). The very first day starts from the first reading.
class StepCounter {
  static const _connectedKey = 'steps.connected';
  static const _dayKey = 'steps.sensor.day';
  static const _baseKey = 'steps.sensor.base';
  static const _lastKey = 'steps.sensor.last';

  final _health = Health();
  bool _configured = false;
  bool _healthConnect = false;
  StreamSubscription<StepCount>? _sensor;
  int _sensorToday = 0;
  int _healthToday = 0;

  /// Fires with the latest total whenever it changes.
  void Function(int steps)? onSteps;

  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  Future<bool> wasConnected() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_connectedKey) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Asks for permission and starts counting.
  Future<StepsStatus> connect() async {
    try {
      await _configure();
      final status = _isIOS ? await _connectIOS() : await _connectAndroid();
      if (status == StepsStatus.connected) {
        await (await SharedPreferences.getInstance()).setBool(
          _connectedKey,
          true,
        );
      }
      return status;
    } catch (e) {
      debugPrint('Step counting unavailable: $e');
      return StepsStatus.unavailable;
    }
  }

  Future<StepsStatus> _connectIOS() async {
    // HealthKit never says whether reading was refused — a "no" just reads as 0
    final ok = await _health.requestAuthorization(
      [HealthDataType.STEPS],
      permissions: [HealthDataAccess.READ],
    );
    return ok ? StepsStatus.connected : StepsStatus.denied;
  }

  Future<StepsStatus> _connectAndroid() async {
    final motion = await Permission.activityRecognition.request();
    if (motion.isPermanentlyDenied) return StepsStatus.denied;

    // Health Connect is a bonus: built into Android 14+, an app before that
    try {
      final sdk = await _health.getHealthConnectSdkStatus();
      if (sdk == HealthConnectSdkStatus.sdkAvailable) {
        _healthConnect = await _health.requestAuthorization(
          [HealthDataType.STEPS],
          permissions: [HealthDataAccess.READ],
        );
      }
    } catch (e) {
      debugPrint('Health Connect unavailable: $e');
    }

    if (motion.isGranted) {
      _listenToSensor();
      return StepsStatus.connected;
    }
    return _healthConnect ? StepsStatus.connected : StepsStatus.denied;
  }

  /// Re-reads today's total — on launch, on resume, and on a timer while open.
  Future<int> refresh() async {
    try {
      await _configure();
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      // after a restart, find out again whether Health Connect was granted
      if (!_isIOS && !_healthConnect) {
        _healthConnect =
            await _health.hasPermissions([HealthDataType.STEPS]) ?? false;
      }
      if (_isIOS || _healthConnect) {
        _healthToday =
            await _health.getTotalStepsInInterval(midnight, now) ?? 0;
      }
      if (!_isIOS &&
          _sensor == null &&
          await Permission.activityRecognition.isGranted) {
        _listenToSensor();
      }
    } catch (e) {
      debugPrint('Step refresh failed: $e');
    }
    return _total;
  }

  /// One reading, for the background task: no permission prompts, no stream
  /// left running. Returns the best count it can get, or null if none.
  Future<int?> readOnce() async {
    int? best;
    try {
      await _configure();
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      if (_isIOS ||
          (await _health.hasPermissions([HealthDataType.STEPS]) ?? false)) {
        best = await _health.getTotalStepsInInterval(midnight, now);
      }
    } catch (e) {
      // Health Connect may refuse background reads; the sensor still works
      debugPrint('Background health read failed: $e');
    }
    if (!_isIOS) {
      try {
        if (await Permission.activityRecognition.isGranted) {
          // the step counter reports its current value as soon as it's listened to
          final event = await Pedometer.stepCountStream.first.timeout(
            const Duration(seconds: 10),
          );
          final sensor = await _sensorStepsToday(event.steps);
          if (best == null || sensor > best) best = sensor;
        }
      } catch (e) {
        debugPrint('Background sensor read failed: $e');
      }
    }
    return best;
  }

  int get _total => _sensorToday > _healthToday ? _sensorToday : _healthToday;

  void _listenToSensor() {
    _sensor ??= Pedometer.stepCountStream.listen((event) async {
      _sensorToday = await _sensorStepsToday(event.steps);
      onSteps?.call(_total);
    }, onError: (Object e) => debugPrint('Step sensor error: $e'));
  }

  Future<int> _sensorStepsToday(int sinceBoot) async {
    final prefs = await SharedPreferences.getInstance();
    // the background task writes these too, from another isolate
    await prefs.reload();
    final today = _day(DateTime.now());
    var base = prefs.getInt(_baseKey) ?? sinceBoot;
    final last = prefs.getInt(_lastKey);

    final storedDay = prefs.getString(_dayKey);
    if (storedDay == null) {
      // first run ever: the counter holds days of walking; today starts now
      base = sinceBoot;
      await prefs.setString(_dayKey, today);
    } else if (storedDay != today) {
      // a new day starts from the last count we saw — or from zero if the phone rebooted
      base = (last != null && sinceBoot >= last) ? last : 0;
      await prefs.setString(_dayKey, today);
    } else if (sinceBoot < base) {
      base = 0; // rebooted today: the counter restarted
    }
    await prefs.setInt(_baseKey, base);
    await prefs.setInt(_lastKey, sinceBoot);
    return sinceBoot - base;
  }

  void dispose() {
    _sensor?.cancel();
    _sensor = null;
  }
}
