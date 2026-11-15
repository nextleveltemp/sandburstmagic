import 'package:flutter/material.dart';

import '../../app_info.dart';
import '../../core/engine.dart';
import '../../core/levels.dart';
import '../../l10n/strings.dart';
import '../../state/app_services.dart';
import '../../state/game_controller.dart';
import '../widgets/game_widgets.dart';
import 'result_card.dart';

/// The share card for finished game [c].
ResultCardData cardData(Strings s, GameController c) {
  final report = c.report;
  final st = c.state;
  String? badge;
  if (report != null && report.newBest) {
    badge = s.newBest;
  } else if (st.status == Status.won && c.mode == GameMode.campaign) {
    badge = s.levelComplete;
  }
  return ResultCardData(
    modeLabel: s.gameTitle(c.mode, c.spec.level),
    scoreText: s.formatNumber(st.score),
    scoreLabel: s.cardScore,
    stars: report?.stars ?? 0,
    badgeText: badge,
    stats: [
      (s.cardRows, s.formatNumber(st.rows)),
      (s.cardCombo, '×${st.bestCombo}'),
      (s.movesUsed, s.formatNumber(st.moves)),
    ],
    board: st.board,
    look: lookOf(c.services),
    taglineText: s.cardTagline,
    footerText: s.cardFooter,
  );
}

/// Shares a result card image plus the link. Only when the player taps
/// Share; nothing is sent anywhere else.
Future<void> shareResult(BuildContext context, GameController c) async {
  final s = Strings.of(context);
  final services = AppScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final report = c.report;
  if (report == null) return;
  final text = s.shareText(
    what: c.mode == GameMode.daily
        ? '${s.daily} ${c.spec.date}'
        : s.gameTitle(c.mode, c.spec.level),
    score: c.state.score,
    rows: c.state.rows,
    stars: report.stars,
    url: AppInfo.shareUrl,
  );
  final png = await ResultCard.renderPng(cardData(s, c));
  final ok = png == null
      ? await services.share.shareText(text)
      : await services.share.shareImage(
          png: png,
          fileName: 'sand-burst-magic-result.png',
          text: text,
        );
  if (!ok) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(s.shareFailed)));
  }
}
