import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../state/app_services.dart';

/// Turns the daily reminder on: asks Android for notification permission
/// first (Android 13+) and only enables the setting if it is granted.
/// Returns whether reminders are now on.
Future<bool> turnOnReminders(BuildContext context) async {
  final services = AppScope.read(context);
  final s = Strings.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final granted = await services.reminders.requestPermission();
  messenger.hideCurrentSnackBar();
  if (!granted) {
    messenger.showSnackBar(SnackBar(content: Text(s.reminderDenied)));
    return false;
  }
  services.settings.update((v) => v.copyWith(reminder: true));
  services.applySettings();
  messenger.showSnackBar(SnackBar(content: Text(s.reminderOn)));
  return true;
}

/// "7:00 PM" or "19:00", following the phone's 24-hour setting.
String formatReminderTime(BuildContext context, int minutes) {
  final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  return MaterialLocalizations.of(context).formatTimeOfDay(
    time,
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

/// Lets the player pick the reminder time.
Future<void> pickReminderTime(BuildContext context) async {
  final services = AppScope.read(context);
  final current = services.settings.value.reminderMinutes;
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
  );
  if (picked == null) return;
  services.settings.update(
    (v) => v.copyWith(reminderMinutes: picked.hour * 60 + picked.minute),
  );
  services.applySettings();
}
