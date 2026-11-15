import 'package:flutter_test/flutter_test.dart';
import 'package:sand_burst_magic/core/engagement.dart';
import 'package:sand_burst_magic/services/ads/ad_config.dart';

void main() {
  group('rating prompt', () {
    const p = ReviewPolicy();
    const day = 24 * 60 * 60 * 1000;
    bool ask({
      bool happy = true,
      int solved = 20,
      int asked = 0,
      int last = 0,
      int now = 100 * day,
    }) => p.shouldAsk(
      happyMoment: happy,
      puzzlesSolved: solved,
      timesAsked: asked,
      lastAskedMillis: last,
      nowMillis: now,
    );

    test('only at happy moments', () {
      expect(ask(happy: false), isFalse);
      expect(ask(), isTrue);
    });

    test('not before the player has solved a few puzzles', () {
      expect(ask(solved: 7), isFalse);
      expect(ask(solved: 8), isTrue);
    });

    test('rarely, and never more than three times', () {
      expect(ask(asked: 1, last: 90 * day), isFalse);
      expect(ask(asked: 1, last: 50 * day), isTrue);
      expect(ask(asked: 3, last: 0), isFalse);
    });
  });

  group('reminders', () {
    test('seven days ahead starting today when not solved yet', () {
      final t = ReminderPlan.times(
        DateTime(2026, 10, 20, 9),
        19 * 60,
        solvedToday: false,
      );
      expect(t.length, ReminderPlan.days);
      expect(t.first, DateTime(2026, 10, 20, 19));
    });

    test('skips today when solved or the time has passed', () {
      final solved = ReminderPlan.times(
        DateTime(2026, 10, 20, 9),
        19 * 60,
        solvedToday: true,
      );
      expect(solved.first, DateTime(2026, 10, 21, 19));
      final late = ReminderPlan.times(
        DateTime(2026, 10, 20, 21),
        19 * 60,
        solvedToday: false,
      );
      expect(late.first, DateTime(2026, 10, 21, 19));
      expect(late.length, ReminderPlan.days);
    });
  });

  group('share texts', () {
    test('star line', () {
      expect(starLine(3), '★★★');
      expect(starLine(1), '★☆☆');
      expect(starLine(7), '★★★');
    });

    test('pour bar is spoiler-free and bounded', () {
      expect(pourBar(10, 10), '🟦' * 10);
      expect(pourBar(12, 10), '${'🟦' * 10}${'🟪' * 2}');
      final long = pourBar(60, 30);
      expect(long.runes.length, lessThanOrEqualTo(12));
      expect(pourBar(0, 10), '');
    });
  });

  group('interstitial frequency', () {
    const p = InterstitialPolicy();
    const minute = 60 * 1000;
    bool allows({
      int completed = 10,
      int since = 5,
      int last = 0,
      int now = 100 * minute,
    }) => p.allows(
      gamesCompleted: completed,
      gamesSinceLast: since,
      lastShownMillis: last,
      nowMillis: now,
    );

    test('the first one after the 2nd puzzle', () {
      expect(allows(completed: 1, since: 1), isFalse);
      expect(allows(completed: 2, since: 2), isTrue);
    });

    test('then after every 2nd finished puzzle, never twice for one', () {
      expect(allows(since: 1), isFalse);
      expect(allows(since: 2), isTrue);
      expect(allows(since: 0), isFalse);
    });

    test('at least 60 seconds between interstitials', () {
      expect(allows(since: 2, last: 100 * minute - 45 * 1000), isFalse);
      expect(allows(since: 2, last: 100 * minute - 60 * 1000), isTrue);
    });
  });
}
