import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

import '../core/engagement.dart';
import '../data/doc_store.dart';
import '../data/docs.dart';
import '../data/models.dart';

/// Play Store rating: Google's in-app review card, shown only at happy
/// moments ([ReviewPolicy]), plus "Rate Sand Burst Magic" in Settings.
abstract class ReviewService {
  /// Asks for a rating if the policy allows. Never throws.
  Future<bool> maybeAsk({
    required bool happyMoment,
    required int puzzlesSolved,
  });

  /// Opens the Play Store page (Settings → Rate Sand Burst Magic).
  Future<bool> openStoreListing();
}

class PluginReviewService implements ReviewService {
  PluginReviewService(
    this._store, {
    this.policy = const ReviewPolicy(),
    this.delay = const Duration(milliseconds: 1500),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final DocStore _store;
  final ReviewPolicy policy;

  /// Lets the results card settle before Google's card appears.
  final Duration delay;
  final DateTime Function() _clock;

  /// Diagnostics for on-device tests.
  int policyApproved = 0;
  int cardsRequested = 0;

  @override
  Future<bool> maybeAsk({
    required bool happyMoment,
    required int puzzlesSolved,
  }) async {
    final state = _store.load(Docs.review).value ?? const ReviewState();
    final now = _clock().millisecondsSinceEpoch;
    if (!policy.shouldAsk(
      happyMoment: happyMoment,
      puzzlesSolved: puzzlesSolved,
      timesAsked: state.count,
      lastAskedMillis: state.lastMillis,
      nowMillis: now,
    )) {
      return false;
    }
    policyApproved++;
    try {
      final review = InAppReview.instance;
      // False when the app was not installed from Google Play.
      if (!await review.isAvailable()) return false;
      await Future<void>.delayed(delay);
      await review.requestReview();
      cardsRequested++;
      unawaited(
        _store.save(
          Docs.review,
          ReviewState(count: state.count + 1, lastMillis: now),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('In-app review unavailable: $e');
      return false;
    }
  }

  @override
  Future<bool> openStoreListing() async {
    try {
      await InAppReview.instance.openStoreListing();
      return true;
    } catch (e) {
      debugPrint('Store listing unavailable: $e');
      return false;
    }
  }
}

/// Never asks (tests).
class NoReviewService implements ReviewService {
  int asks = 0;

  @override
  Future<bool> maybeAsk({
    required bool happyMoment,
    required int puzzlesSolved,
  }) async {
    asks++;
    return false;
  }

  @override
  Future<bool> openStoreListing() async => false;
}
