import 'package:flutter/services.dart';

enum Haptic { select, place, invalid, row, win }

/// Haptic feedback through Flutter's built-in [HapticFeedback] API, which
/// uses the system haptic engine and needs no Android permission. Used
/// sparingly: selection, placements, rejected placements and row bursts only.
class HapticsService {
  HapticsService({this.enabled = true});

  bool enabled;

  /// Diagnostics for on-device tests: haptics actually requested.
  int fired = 0;

  void fire(Haptic h) {
    if (!enabled) return;
    fired++;
    switch (h) {
      case Haptic.select:
        HapticFeedback.selectionClick();
      case Haptic.place:
        HapticFeedback.lightImpact();
      case Haptic.invalid:
        HapticFeedback.mediumImpact();
      case Haptic.row:
        HapticFeedback.mediumImpact();
      case Haptic.win:
        HapticFeedback.heavyImpact();
    }
  }
}
