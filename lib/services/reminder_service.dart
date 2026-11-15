import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/engagement.dart';

/// Opt-in daily puzzle reminder as a local notification. Nothing leaves the
/// device. Reminders are scheduled a week ahead ([ReminderPlan]) and
/// rescheduled whenever the app opens or the daily puzzle is solved, so a
/// solved day is skipped and a player who stops playing simply stops
/// getting reminders after a week.
abstract class ReminderService {
  Future<void> init();

  /// Asks Android for notification permission (Android 13+). True if
  /// notifications are allowed.
  Future<bool> requestPermission();

  Future<void> schedule({
    required int minutesAfterMidnight,
    required bool solvedToday,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  });

  Future<void> cancelAll();

  /// Number of reminders currently scheduled (diagnostics and tests).
  Future<int> pendingCount();
}

class PluginReminderService implements ReminderService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Small white notification icon (android/app/src/main/res/drawable-*).
  static const _icon = 'ic_stat_sandburstmagic';
  static const _channelId = 'daily_reminder';

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> init() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(_icon),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Reminders unavailable: $e');
    }
  }

  @override
  Future<bool> requestPermission() async {
    await init();
    final android = _android;
    if (!_ready || android == null) return false;
    try {
      if (await android.areNotificationsEnabled() ?? false) return true;
      return await android.requestNotificationsPermission() ?? false;
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
      return false;
    }
  }

  @override
  Future<void> schedule({
    required int minutesAfterMidnight,
    required bool solvedToday,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    await init();
    if (!_ready) return;
    await cancelAll();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        channelName,
        channelDescription: channelDescription,
        icon: _icon,
        color: const Color(0xFF8C5CFF),
      ),
    );
    final times = ReminderPlan.times(
      DateTime.now(),
      minutesAfterMidnight,
      solvedToday: solvedToday,
    );
    for (var i = 0; i < times.length; i++) {
      try {
        // UTC needs no time-zone database; the instant is the same.
        await _plugin.zonedSchedule(
          id: ReminderPlan.firstId + i,
          scheduledDate: tz.TZDateTime.from(times[i].toUtc(), tz.UTC),
          notificationDetails: details,
          // Inexact: no "alarms & reminders" permission needed.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: title,
          body: body,
        );
      } catch (e) {
        debugPrint('Could not schedule reminder: $e');
      }
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!_ready) return;
    for (var i = 0; i <= ReminderPlan.days; i++) {
      try {
        await _plugin.cancel(id: ReminderPlan.firstId + i);
      } catch (_) {}
    }
  }

  @override
  Future<int> pendingCount() async {
    if (!_ready) return 0;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending
          .where(
            (p) =>
                p.id >= ReminderPlan.firstId &&
                p.id <= ReminderPlan.firstId + ReminderPlan.days,
          )
          .length;
    } catch (_) {
      return 0;
    }
  }
}

/// Does nothing (tests and unsupported platforms).
class NoReminderService implements ReminderService {
  int scheduled = 0;
  bool permission = true;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> schedule({
    required int minutesAfterMidnight,
    required bool solvedToday,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    scheduled = ReminderPlan.times(
      DateTime.now(),
      minutesAfterMidnight,
      solvedToday: solvedToday,
    ).length;
  }

  @override
  Future<void> cancelAll() async => scheduled = 0;

  @override
  Future<int> pendingCount() async => scheduled;
}
