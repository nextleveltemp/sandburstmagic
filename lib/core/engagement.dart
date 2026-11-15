/// Pure rules for the rating prompt, daily reminders and share texts.
/// No Flutter or plugin code here, so everything is unit tested.
library;

/// When to ask for a Play Store rating with Google's in-app review card.
///
/// Google already limits how often the card can really appear; these rules
/// make sure the app only *asks* at a happy moment (a three-star solve, a
/// solved daily puzzle or challenge), after the player has had time to form
/// an opinion, and rarely.
class ReviewPolicy {
  const ReviewPolicy({
    this.minSolved = 8,
    this.maxAsks = 3,
    this.minDaysBetween = 45,
  });

  final int minSolved;
  final int maxAsks;
  final int minDaysBetween;

  bool shouldAsk({
    required bool happyMoment,
    required int puzzlesSolved,
    required int timesAsked,
    required int lastAskedMillis,
    required int nowMillis,
  }) {
    if (!happyMoment) return false;
    if (puzzlesSolved < minSolved) return false;
    if (timesAsked >= maxAsks) return false;
    if (timesAsked > 0 &&
        nowMillis - lastAskedMillis <
            Duration(days: minDaysBetween).inMilliseconds) {
      return false;
    }
    return true;
  }
}

/// Local times at which daily-puzzle reminders should fire.
abstract final class ReminderPlan {
  /// Notification ids used for the reminders (one per scheduled day).
  static const int firstId = 100;
  static const int days = 7;

  /// The next [days] reminder times (local), starting today unless today's
  /// time has passed or today's puzzle is already solved.
  static List<DateTime> times(
    DateTime nowLocal,
    int minutesAfterMidnight, {
    required bool solvedToday,
  }) {
    final h = minutesAfterMidnight ~/ 60;
    final m = minutesAfterMidnight % 60;
    final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day, h, m);
    final startToday = !solvedToday && today.isAfter(nowLocal);
    return [
      for (var i = startToday ? 0 : 1; i < (startToday ? days : days + 1); i++)
        DateTime(nowLocal.year, nowLocal.month, nowLocal.day + i, h, m),
    ];
  }
}

/// Spoiler-free star line for share texts: 2 of 3 → "★★☆".
String starLine(int stars) {
  final s = stars.clamp(0, 3);
  return '★' * s + '☆' * (3 - s);
}

/// Spoiler-free picture of the solve for the daily share text: one drop
/// per pour against the par, e.g. 24 pours with par 20 →
/// "🟦🟦🟦🟦🟦🟦🟦🟦🟦🟦🟪🟪" (blue up to par, violet for extra pours),
/// scaled to at most [width] squares.
String pourBar(int moves, int par, {int width = 12}) {
  if (moves <= 0 || par <= 0 || width <= 0) return '';
  final total = moves > par ? moves : par;
  final scale = total > width ? width / total : 1.0;
  final blue = (((moves < par ? moves : par)) * scale).round();
  final extra = ((moves > par ? moves - par : 0) * scale).round();
  return '🟦' * blue + '🟪' * extra;
}
