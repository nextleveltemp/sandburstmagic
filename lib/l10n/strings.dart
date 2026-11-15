import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/engine.dart';
import '../core/levels.dart';
import '../core/progression.dart';
import '../core/sand.dart';

/// All user-facing text.
///
/// LANGUAGE-READY: English lives in this base class. To add a language,
/// create a subclass (for example `class StringsEs extends Strings`),
/// override the getters, and register it in [Strings.forLocale] and
/// [StringsDelegate.supportedLocales].
class Strings {
  const Strings();

  static Strings of(BuildContext context) =>
      Localizations.of<Strings>(context, Strings) ?? const Strings();

  static Strings forLocale(Locale locale) => const Strings();

  String formatNumber(int n) {
    final s = n.abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return n < 0 ? '-$b' : b.toString();
  }

  /// "1 h 05 min", "12 min", "45 s".
  String formatDuration(int seconds) {
    if (seconds < 60) return '$seconds s';
    final m = seconds ~/ 60;
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    return '$h h ${(m % 60).toString().padLeft(2, '0')} min';
  }

  /// "1:05" for the Time Challenge clock.
  String clock(int ms) {
    final s = (ms + 999) ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------- General
  String get appName => 'Sand Burst Magic';
  String get appNameLine1 => 'Sand Burst';
  String get appNameLine2 => 'Magic';
  String get studioName => 'Magivix Studio';
  String get byStudio => 'by Magivix Studio';
  String get gameByStudio => 'A puzzle game by Magivix Studio';
  String get ok => 'OK';
  String get cancel => 'Cancel';
  String get close => 'Close';
  String get back => 'Back';
  String get done => 'Done';
  String get locked => 'Locked';
  String get loading => 'Loading…';

  // ---------------------------------------------------------------- Colours
  String colourName(int id) => switch (id) {
    0 => 'ruby red',
    1 => 'sunset orange',
    2 => 'golden yellow',
    3 => 'emerald green',
    4 => 'ocean blue',
    5 => 'royal purple',
    6 => 'bubblegum pink',
    7 => 'turquoise',
    8 => 'coral',
    9 => 'lavender',
    _ => 'grey',
  };

  String kindName(int kind) => switch (kind) {
    SandKind.heavy => 'Heavy sand',
    SandKind.sticky => 'Sticky sand',
    SandKind.explosive => 'Explosive sand',
    SandKind.rainbow => 'Rainbow sand',
    SandKind.frozen => 'Frozen sand',
    SandKind.crystal => 'Crystal sand',
    SandKind.golden => 'Golden sand',
    SandKind.magnetic => 'Magnetic sand',
    SandKind.volcanic => 'Volcanic sand',
    SandKind.mystery => 'Mystery sand',
    _ => 'Sand',
  };

  String obstacleName(int o) => switch (o) {
    Obstacle.stone => 'Stone block',
    Obstacle.wood => 'Wooden barrier',
    Obstacle.ice => 'Frozen cell',
    Obstacle.locked => 'Locked cell',
    Obstacle.unbreakable => 'Unbreakable block',
    Obstacle.trap => 'Sand trap',
    Obstacle.crystalWall => 'Crystal wall',
    _ => 'Moving barrier',
  };

  // ---------------------------------------------------------------- Home
  String get play => 'Play';
  String get continueGame => 'Continue';
  String get classicBlurb => 'Endless puzzle. Fill rows, chase your best.';
  String levelN(int n) => 'Level $n';
  String playLevelLabel(int n) => 'Play level $n';
  String get campaign => 'Campaign';
  String get allLevelsDone => 'Every level won!';
  String levelsProgress(int done, int total) =>
      '${formatNumber(done)} of ${formatNumber(total)} levels';
  String starsTotal(int n) => '${formatNumber(n)} stars';
  String get modes => 'Game Modes';
  String get daily => 'Daily Puzzle';
  String get dailyBlurbNew => 'A new puzzle is ready';
  String get dailyBlurbDone => 'Done for today';
  String dailyStreak(int n) => switch (n) {
    <= 0 => 'No streak yet',
    1 => '1-day streak',
    _ => '$n-day streak',
  };
  String get shop => 'Shop';
  String get themes => 'Themes';
  String get statistics => 'Statistics';
  String get settings => 'Settings';
  String coinsLabel(int n) => '${formatNumber(n)} coins';
  String bestScore(int n) => 'Best ${formatNumber(n)}';
  String get dailyPaused =>
      'Your device date moved backwards, so daily rewards are paused until it catches up.';

  // ---------------------------------------------------------------- Modes
  String modeName(GameMode m) => switch (m) {
    GameMode.classic => 'Classic',
    GameMode.campaign => 'Campaign',
    GameMode.time => 'Time Challenge',
    GameMode.moves => 'Limited Moves',
    GameMode.daily => 'Daily Puzzle',
    GameMode.endless => 'Endless Sand',
  };
  String modeBlurb(GameMode m) => switch (m) {
    GameMode.classic =>
      'No timer. Place pieces until nothing fits. Frozen and sticky sand appear as your score grows.',
    GameMode.campaign => '100 levels in six worlds.',
    GameMode.time =>
      '${Modes.timeSeconds ~/ 60} minutes on the clock. Every cleared row adds ${Modes.timePerRow} seconds.',
    GameMode.moves =>
      '${Modes.limitedMoves} pieces to reach the target score. The target grows as you win.',
    GameMode.daily => 'The same puzzle for everyone today.',
    GameMode.endless =>
      'Special sands join in as your score climbs: crystal, gold, explosive and more.',
  };
  String movesTarget(int n) => 'Target: ${formatNumber(n)} points';

  // ---------------------------------------------------------------- Worlds
  String worldName(String id) => switch (id) {
    'candy' => 'Candy Dunes',
    'crystal' => 'Crystal Desert',
    'ocean' => 'Ocean Sands',
    'sunset' => 'Sunset Valley',
    'forest' => 'Mystic Forest',
    _ => 'Cosmic Sands',
  };
  String worldN(int n) => 'World $n';
  String worldLocked(int level) => 'Reach level $level to enter';
  String levelCellLabel(int n, bool unlocked, bool current, int stars) {
    if (!unlocked) return 'Level $n, locked';
    final st = stars > 0 ? ', $stars of 3 stars' : '';
    return 'Level $n${current ? ', next to play' : ''}$st';
  }

  // ---------------------------------------------------------------- Game
  String gameTitle(GameMode m, int level) =>
      m == GameMode.campaign ? levelN(level) : modeName(m);
  String get score => 'Score';
  String get boardLabel => 'Game board';
  String get best => 'Best';
  String get movesLeftLabel => 'Moves';
  String get timeLabel => 'Time';
  String get pause => 'Pause';
  String get paused => 'Paused';
  String get resume => 'Resume';
  String get restart => 'Restart';
  String get home => 'Home';
  String get hint => 'Hint';
  String get undo => 'Undo';
  String get free => 'Free';
  String get nothingToUndo => 'Nothing to undo';
  String get watchAdForHint => 'Watch an ad for a hint';
  String get watchAdForUndo => 'Watch an ad to undo';
  String get adUnavailable => 'No ad is available right now. Try again later.';
  String get adLoading => 'Loading an ad…';
  String get noHint => 'No piece fits anywhere.';
  String get hintShown => 'Try the glowing spot.';
  String get placeRejected => 'That piece doesn’t fit there.';
  String get tapPieceFirst =>
      'Drag a piece onto the board, or tap it and then tap a cell.';
  String combo(int n) => 'Combo ×$n';
  String rowsBurst(int n) => switch (n) {
    2 => 'Double Burst!',
    3 => 'Triple Burst!',
    4 => 'Mega Burst!',
    _ => 'Sand Storm!',
  };
  String get perfectClear => 'Perfect clear! +1,000';
  String revealed(int kind) => 'Mystery: ${kindName(kind)}!';
  String plusTime(int s) => '+$s s';
  String get restartTitle => 'Restart this game?';
  String get restartBody =>
      'The board goes back to the start. Your stars and records are kept.';
  String objectiveText(Objective o) => switch (o.type) {
    ObjectiveType.rows => 'Clear ${o.target} rows',
    ObjectiveType.score => 'Score ${formatNumber(o.target)}',
    ObjectiveType.multi =>
      o.target == 1
          ? 'Clear 2+ rows at once'
          : 'Clear 2+ rows at once, ${o.target} times',
    ObjectiveType.special =>
      'Clear ${o.target} ${kindName(o.kind).toLowerCase()}',
    ObjectiveType.obstacles => 'Break ${o.target} obstacles',
  };
  String objectiveProgress(int v, int target) =>
      '${formatNumber(v)}/${formatNumber(target)}';
  String get noPowerUps => 'No power-ups in this level';
  String movesLimit(int n) => 'in $n moves';
  String cellLabel(int row, int col, String what) =>
      'Row ${row + 1}, column ${col + 1}: $what';
  String get emptyCell => 'empty';
  String sandCell(int colour, int kind) => kind == SandKind.normal
      ? '${colourName(colour)} sand'
      : '${kindName(kind)} (${colourName(colour)})';
  String pieceLabel(int index, String shape, int cells, int colour, int kind) =>
      'Piece ${index + 1}: $cells blocks, ${sandCell(colour, kind)}';
  String get usedPiece => 'Used';

  // ---------------------------------------------------------------- Power-ups
  String powerName(PowerUp p) => switch (p) {
    PowerUp.sweep => 'Sand Sweep',
    PowerUp.blast => 'Colour Blast',
    PowerUp.shaker => 'Sand Shaker',
    PowerUp.rowClear => 'Row Clear',
    PowerUp.crusher => 'Block Crusher',
    PowerUp.gravity => 'Gravity Shift',
    PowerUp.bomb => 'Sand Bomb',
    PowerUp.extra => 'Extra Move',
  };
  String powerDesc(PowerUp p) => switch (p) {
    PowerUp.sweep => 'Removes one whole row of your choice.',
    PowerUp.blast => 'Removes all sand of one colour (and rainbow sand).',
    PowerUp.shaker => 'Shuffles the loose sand around a cell.',
    PowerUp.rowClear =>
      'Fills a row missing at most 3 grains, so it bursts at once.',
    PowerUp.crusher => 'Crushes a connected group of one colour (up to 12).',
    PowerUp.gravity => 'Slides all loose sand to the left or right wall.',
    PowerUp.bomb => 'Blows up a 3×3 area.',
    PowerUp.extra => 'Gives a bonus single block (and one more move).',
  };
  String powerPrompt(PowerUp p) => switch (p.target) {
    PowerTarget.row => 'Tap a row',
    PowerTarget.colour => 'Tap a grain of the colour to remove',
    PowerTarget.cell => 'Tap a cell',
    PowerTarget.side => 'Choose a side',
    PowerTarget.none => '',
  };
  String get left => 'Left';
  String get right => 'Right';
  String get powerCannot => 'That power-up does nothing there.';
  String powerCount(PowerUp p, int n) => '${powerName(p)}, $n left';
  String get getMore => 'Get more';
  String buyFor(int price) => 'Buy for ${formatNumber(price)}';
  String get notEnoughCoins => 'Not enough coins yet.';
  String get watchAdForPower => 'Watch an ad: use one free';

  // ---------------------------------------------------------------- Intros
  String introTitle(String id) => switch (id) {
    'place' => 'Place a piece',
    'sand' => 'Blocks turn to sand',
    'rows' => 'Fill a row',
    'score' => 'Score points',
    'multi' => 'Multi-row bursts',
    'limit' => 'Move limits',
    'nopower' => 'Pure skill',
    'crystal' => 'Crystal sand',
    'golden' => 'Golden sand',
    'stone' => 'Stone blocks',
    'crystalWall' => 'Crystal walls',
    'heavy' => 'Heavy sand',
    'frozen' => 'Frozen sand',
    'ice' => 'Frozen cells',
    'wood' => 'Wooden barriers',
    'explosive' => 'Explosive sand',
    'volcanic' => 'Volcanic sand',
    'sticky' => 'Sticky sand',
    'trap' => 'Sand traps',
    'magnetic' => 'Magnetic sand',
    'mystery' => 'Mystery sand',
    'rainbow' => 'Rainbow sand',
    'locked' => 'Locked cells',
    'blocked' => 'Restricted areas',
    'mover' => 'Moving barriers',
    'unbreakable' => 'Unbreakable blocks',
    _ => '',
  };
  String introBody(String id) => switch (id) {
    'place' =>
      'Drag a piece from the tray onto the board, or tap it and then tap a cell.',
    'sand' =>
      'Placed blocks dissolve into grains of sand that fall and slide down slopes.',
    'rows' =>
      'When a whole row is full of sand, it bursts and disappears. Colours don’t need to match.',
    'score' => 'Every grain and every burst scores. Combos score more.',
    'multi' => 'Finish two rows with one piece for a bigger burst.',
    'limit' =>
      'This level counts your pieces. Reach the goal before they run out.',
    'nopower' => 'No power-ups here. Just you and the sand.',
    'crystal' =>
      'Crystal sand sparkles and gives 40 extra points when it bursts.',
    'golden' => 'Golden sand gives 5 coins for every grain you clear.',
    'stone' => 'Stone fills its cell. Burst its row twice to break it.',
    'crystalWall' =>
      'Crystal walls take three bursts to break and give 100 points.',
    'heavy' => 'Heavy sand only falls straight down. It never slides.',
    'frozen' => 'Frozen sand doesn’t move. Burst a row next to it to thaw it.',
    'ice' =>
      'Frozen cells break when their row, or a row next to them, bursts.',
    'wood' => 'Wooden barriers break when their row bursts.',
    'explosive' =>
      'When explosive sand bursts, it also clears the 8 cells around it.',
    'volcanic' =>
      'Volcanic sand blasts two cells up and two cells down when it bursts.',
    'sticky' =>
      'Sticky sand holds itself and its neighbours in place for 3 moves.',
    'trap' =>
      'A sand trap swallows 3 grains, then fills up. A row with an open trap can’t burst.',
    'magnetic' =>
      'When magnetic sand bursts, it pulls in nearby sand of its own colour.',
    'mystery' =>
      'Mystery sand becomes a random special sand when you place it.',
    'rainbow' =>
      'Rainbow sand shimmers through every colour and counts for any Colour Blast.',
    'locked' =>
      'Locked cells open after enough rows burst anywhere. The number shows how many.',
    'blocked' =>
      'You can’t place pieces on the dotted cells, but sand can still flow into them.',
    'mover' => 'Moving barriers slide one cell sideways after every move.',
    'unbreakable' =>
      'Unbreakable blocks never break, but they count as filled for rows.',
    _ => '',
  };
  String get gotIt => 'Got it';

  // ---------------------------------------------------------------- Results
  String get levelComplete => 'Level complete!';
  String get dailySolved => 'Daily Puzzle done!';
  String get targetReached => 'Target reached!';
  String endTitle(String reason) => switch (reason) {
    'moves' => 'Out of moves',
    'time' => 'Time’s up!',
    _ => 'No room left',
  };
  String get gameOver => 'Game over';
  String get finalScore => 'Final score';
  String get newBest => 'New best!';
  String bestWas(int n) => 'Best ${formatNumber(n)}';
  String get rowsCleared => 'Rows cleared';
  String get highestCombo => 'Highest combo';
  String get grainsCleared => 'Grains cleared';
  String get movesUsed => 'Moves';
  String coinsEarned(int n) => '+${formatNumber(n)} coins';
  String doubleCoins(int n) => 'Watch ad: double coins (+${formatNumber(n)})';
  String coinsDoubled(int n) => '+${formatNumber(n)} coins (doubled)';
  String get nextLevel => 'Next level';
  String get playAgain => 'Play again';
  String get tryAgain => 'Try again';
  String get achievementsUnlocked => 'Achievements unlocked';
  String get missionsDone => 'Missions complete';
  String get allMissionsBonus => 'All missions: +50 coins';
  String giftReceived(String list) => 'World complete! Gift: $list';
  String themeUnlocked(String name) => 'New board theme: $name';
  String get dailyRewardAlready => 'Already done today: no extra reward.';
  String starsSemantics(int n) => '$n of 3 stars';
  String get share => 'Share';
  String get shareFailed => "Couldn't open sharing. Please try again.";
  String get remindMe => 'Remind me daily';
  String get continueTitle => 'Keep playing?';
  String get continueBody =>
      'Watch a short ad to clear the bottom three rows and get new pieces.';
  String get continueWatch => 'Watch ad and continue';
  String get noThanks => 'No thanks';

  String shareText({
    required String what,
    required int score,
    required int rows,
    required int stars,
    required String url,
  }) {
    final st = stars > 0 ? ' ${'★' * stars}' : '';
    return 'I scored ${formatNumber(score)} and burst ${formatNumber(rows)} '
        'rows in Sand Burst Magic ($what)$st. Can you beat it?\n$url';
  }

  String shareAppText(String url) =>
      'Place blocks, watch them turn to sand and burst full rows in Sand Burst Magic: $url';

  // ---------------------------------------------------------------- Share card
  String get cardScore => 'Score';
  String get cardRows => 'Rows';
  String get cardCombo => 'Best combo';
  String get cardFooter => 'Sand Burst Magic · by Magivix Studio';
  String get cardTagline => 'Place. Pour. Burst.';

  // ---------------------------------------------------------------- Daily
  String get dailyTitle => 'Daily Puzzle';
  String dailyFor(String date) => 'Puzzle for $date';
  String get dailyExplain =>
      'A new puzzle every day at midnight (your device date). Everyone with the same date gets the same puzzle. Win it to keep your streak and earn coins.';
  String get dailyPlay => 'Play today’s puzzle';
  String get dailyContinue => 'Continue today’s puzzle';
  String bestStreak(int n) => 'Best streak: $n';
  String get dailyPreparing => 'Preparing today’s puzzle…';
  String get dailyFailed => "Couldn't prepare the puzzle. Please try again.";
  String get dailyDoneAgain => 'Play again (no extra reward)';

  // ---------------------------------------------------------------- Missions
  String get missions => "Today's missions";
  String get missionsHint =>
      'Each mission gives 30 coins. Finish all three for 50 more.';
  String get missionsAllDone => 'All done for today. New missions tomorrow!';
  String get showMissions => 'Show missions';
  String get showMissionsHint => "Today's missions on the home screen";
  String missionText(MissionDef m) => switch (m.metric) {
    MissionMetric.rows => 'Clear ${m.target} rows',
    MissionMetric.multi =>
      m.target == 1
          ? 'Clear 2+ rows at once'
          : 'Clear 2+ rows at once ${m.target} times',
    MissionMetric.pieces => 'Place ${m.target} pieces',
    MissionMetric.games => 'Play ${m.target} games',
    MissionMetric.special => 'Clear ${m.target} special grains',
    MissionMetric.powerUp => 'Use a power-up',
    MissionMetric.level => 'Win ${m.target} campaign levels',
    MissionMetric.score => 'Score ${formatNumber(m.target)} in one game',
  };

  // ---------------------------------------------------------------- Shop
  String get shopPowerUps => 'Power-ups';
  String cosmeticKindName(CosmeticKind k) => switch (k) {
    CosmeticKind.board => 'Boards',
    CosmeticKind.palette => 'Sand colours',
    CosmeticKind.grain => 'Grains',
    CosmeticKind.burst => 'Bursts',
    CosmeticKind.piece => 'Pieces',
  };
  String cosmeticName(Cosmetic c) => switch (c.kind) {
    CosmeticKind.board =>
      c.id == 'midnight'
          ? 'Midnight'
          : c.id == 'daylight'
          ? 'Daylight'
          : worldName(c.id),
    CosmeticKind.palette => switch (c.id) {
      'pastel' => 'Pastel',
      'neon' => 'Neon',
      'jewel' => 'Jewel',
      _ => 'Classic',
    },
    CosmeticKind.grain => switch (c.id) {
      'pixel' => 'Pixel',
      'sparkle' => 'Sparkle',
      'glass' => 'Glass beads',
      _ => 'Round',
    },
    CosmeticKind.burst => switch (c.id) {
      'stars' => 'Stars',
      'confetti' => 'Confetti',
      'rings' => 'Rings',
      _ => 'Sparks',
    },
    CosmeticKind.piece => switch (c.id) {
      'flat' => 'Flat',
      'outline' => 'Outline',
      _ => 'Glossy',
    },
  };
  String get inUse => 'In use';
  String get use => 'Use';
  String get owned => 'Owned';
  String worldTheme(int world) => 'Free when you reach world $world';
  String get freeCoins => 'Free coins';
  String watchForCoins(int n) => 'Watch an ad: +$n coins';
  String get cosmeticsNote =>
      'Looks only: every board, colour and grain plays exactly the same.';
  String bought(String name) => '$name is yours!';

  // ---------------------------------------------------------------- Stats
  String get statsGames => 'Games';
  String get statsPlayed => 'Games played';
  String get statsRows => 'Rows cleared';
  String get statsGrains => 'Sand grains cleared';
  String get statsPieces => 'Pieces placed';
  String get statsCombo => 'Highest combo';
  String get statsBiggest => 'Most rows in one burst';
  String get statsMulti => 'Multi-row bursts';
  String get statsPerfect => 'Perfect clears';
  String get statsPowerUps => 'Power-ups used';
  String get statsCoins => 'Coins earned';
  String get statsPlayTime => 'Time playing';
  String get statsLevels => 'Campaign';
  String get statsLevelsCompleted => 'Levels won';
  String get statsStars => 'Stars earned';
  String get statsBests => 'Best scores';
  String get statsDaily => 'Daily Puzzle';
  String get statsCurrentStreak => 'Current streak';
  String get statsBestStreak => 'Best streak';
  String get statsNote =>
      'Statistics count what happened on this phone. Time playing counts time in a game with the app open.';
  String get achievements => 'Achievements';
  String get statsTab => 'Stats';
  String achievementsCount(int done, int total) => '$done of $total unlocked';
  String achievementTitle(String id) => switch (id) {
    'firstRow' => 'First burst',
    'rows100' => 'Sand sweeper',
    'rows1000' => 'Dune master',
    'double' => 'Double trouble',
    'triple' => 'Triple threat',
    'quad' => 'Sand storm',
    'combo5' => 'On a roll',
    'combo10' => 'Unstoppable',
    'score5000' => 'High roller',
    'score15000' => 'Legend of the dunes',
    'perfect' => 'Spotless',
    'sand5000' => 'Grain collector',
    'golden50' => 'Gold rush',
    'powers10' => 'Power player',
    'level10' => 'Explorer',
    'world1' => 'Candy conqueror',
    'world3' => 'Halfway hero',
    'allLevels' => 'Sand sorcerer',
    'stars150' => 'Star gazer',
    'streak3' => 'Three in a row',
    'streak7' => 'A week of sand',
    'streak30' => 'Monthly magic',
    _ => id,
  };
  String achievementDesc(String id) => switch (id) {
    'firstRow' => 'Clear your first row',
    'rows100' => 'Clear 100 rows',
    'rows1000' => 'Clear 1,000 rows',
    'double' => 'Clear 2 rows at once',
    'triple' => 'Clear 3 rows at once',
    'quad' => 'Clear 4 rows at once',
    'combo5' => 'Reach a ×5 combo',
    'combo10' => 'Reach a ×10 combo',
    'score5000' => 'Score 5,000 in Classic',
    'score15000' => 'Score 15,000 in Classic',
    'perfect' => 'Clear every grain from the board',
    'sand5000' => 'Clear 5,000 grains of sand',
    'golden50' => 'Clear 50 golden grains',
    'powers10' => 'Use 10 power-ups',
    'level10' => 'Win 10 campaign levels',
    'world1' => 'Finish Candy Dunes',
    'world3' => 'Finish three worlds',
    'allLevels' => 'Win all 100 levels',
    'stars150' => 'Earn 150 stars',
    'streak3' => 'Win the Daily Puzzle 3 days in a row',
    'streak7' => 'Win the Daily Puzzle 7 days in a row',
    'streak30' => 'Win the Daily Puzzle 30 days in a row',
    _ => '',
  };

  // ---------------------------------------------------------------- Tutorial
  String get skip => 'Skip';
  String get next => 'Next';
  String get howToPlay => 'How to play';
  String tutorialTitle(int page) => switch (page) {
    0 => 'Place colourful pieces',
    1 => 'Watch them turn to sand',
    2 => 'Fill a row to burst it',
    _ => 'Keep room on the board',
  };
  String tutorialBody(int page) => switch (page) {
    0 =>
      'Drag a piece from the tray onto any empty cells, or tap a piece and then tap the board.',
    1 => 'Blocks dissolve into grains that fall, slide down slopes and settle.',
    2 =>
      'When a whole row is filled with sand, it bursts. Colours don’t need to match. Several rows at once score much more.',
    _ =>
      'The game ends when none of your pieces fits. Power-ups, hints and undo help you out of a tight spot.',
  };
  String get startPlaying => 'Start playing';
  String tutorialProgress(int step, int total) => 'Step $step of $total';

  // ---------------------------------------------------------------- Settings
  String get sound => 'Sound';
  String get soundEffects => 'Sound effects';
  String get music => 'Music';
  String get musicHint => 'Music in menus and while playing';
  String get volume => 'Volume';
  String get haptics => 'Vibration';
  String get hapticsHint => 'Light feedback when placing and bursting rows';
  String get display => 'Display';
  String get appearance => 'Appearance';
  String get appearanceSystem => 'System';
  String get appearanceDark => 'Dark';
  String get appearanceLight => 'Light';
  String get reduceMotion => 'Reduce motion';
  String get reduceMotionHint => 'Faster sand, smaller bursts, no screen shake';
  String get help => 'Help';
  String get privacy => 'Privacy';
  String get privacyPolicy => 'Privacy policy';
  String get privacyChoices => 'Ad privacy choices';
  String get about => 'About';
  String version(String v) => 'Version $v';
  String get data => 'Data';
  String get resetProgress => 'Reset all progress';
  String get resetTitle => 'Reset all progress?';
  String get resetBody =>
      'This permanently deletes your levels and stars, coins, power-ups, bought items, achievements, statistics, daily streak, missions and games in progress. Your settings are kept.';
  String get resetConfirmField => 'Type RESET to confirm';
  String get resetWord => 'RESET';
  String get resetAction => 'Delete progress';
  String get resetDone => 'Progress reset';
  String get testAdsNote => 'This build shows Google test ads.';
  String get rateApp => 'Rate Sand Burst Magic';
  String get rateAppHint => 'Opens Google Play';
  String get storeUnavailable => "Couldn't open Google Play.";
  String get shareApp => 'Share Sand Burst Magic';
  String get shareAppHint => 'Send the game to a friend';

  // ---------------------------------------------------------------- Reminders
  String get remindersHeading => 'Reminders';
  String get reminder => 'Daily Puzzle reminder';
  String get reminderHint => 'Skipped on days you already solved it';
  String get reminderTime => 'Time';
  String get reminderOn => 'Daily reminder on';
  String get reminderDenied =>
      'Notifications are off for Sand Burst Magic. Allow them in Android settings to get reminders.';
  String get reminderTitle => 'Your Daily Puzzle is ready';
  String get reminderBody =>
      'A fresh sand puzzle is waiting. Keep your streak going!';
  String get reminderChannel => 'Daily Puzzle reminder';
  String get reminderChannelDescription =>
      'One reminder a day to solve the Daily Puzzle';

  // ---------------------------------------------------------------- About/Privacy
  String get aboutBody =>
      'Sand Burst Magic is a colourful block puzzle with real flowing sand. Place pieces, watch them pour into grains, and fill whole rows to make them burst. 100 campaign levels in six worlds, a Daily Puzzle and five more modes, all playable offline.';
  String get credits => 'Credits';
  String get licenses => 'Open-source licences';
  String get creditsBody =>
      'Typeface: Outfit (SIL Open Font License 1.1). Sounds and music were synthesised for Sand Burst Magic.';
  String get privacyHeading => 'How Sand Burst Magic handles data';
  String get privacyBodyGame =>
      'Your game progress, statistics and settings are stored only on this device. Sand Burst Magic has no account system and does not send your game data to a server.';
  String get privacyBodyAds =>
      'Sand Burst Magic shows ads using Google AdMob. Google may collect and process device identifiers, approximate location derived from your IP address, and ad interaction data to show and measure ads, subject to the choices you make in the consent form where applicable. See Google’s policies at policies.google.com/privacy.';
  String get privacyBodyNoAds => 'This build does not show ads.';
  String get privacyBodyFeatures =>
      'If you turn on the daily reminder, it is scheduled on your phone and nothing is sent to a server. Sharing only happens when you tap Share, and you choose where it goes. Purchases ("Remove ads") are handled by Google Play; the game only remembers on your phone that ads are removed.';
  String get privacyBodyReset =>
      'You can delete all game progress at any time from Settings → Reset all progress. Uninstalling the app also removes it.';
  String get privacyFullPolicy => 'Full privacy policy';

  // ---------------------------------------------------------------- Welcome
  String get welcomeTitle => 'Welcome to Sand Burst Magic';
  String get welcomeBefore => 'Please accept our ';
  String get welcomeMiddle => ' and read our ';
  String get welcomeAfter => '.';
  String get termsOfUse => 'Terms of Use';
  String get accept => 'Accept';
  String get termsFull => 'Full Terms of Use';
  String get termsHeading => 'Terms of Use for Sand Burst Magic';
  String get termsBodyIntro =>
      'Sand Burst Magic is made by Magivix Studio. By playing the game you agree to these terms. If you do not agree, please do not use the app.';
  String get termsBodyUse =>
      'You may use the game for your own personal, non-commercial entertainment. Please do not copy, modify, resell or reverse engineer the app, interfere with its ads or purchases, or use it in any unlawful way.';
  String get termsBodyAds =>
      'The game is free and shows ads from Google AdMob. Ads that give a reward (an extra hint, an extra undo, a power-up, "Keep playing?", double coins) are always your choice. The one-time "Remove ads" purchase turns off the banner and the ads between puzzles; ads you choose to watch for a reward stay available.';
  String get termsBodyPurchases =>
      'Purchases are made through Google Play and are subject to Google Play’s terms, including its refund policies. "Restore purchase" in Settings brings back "Remove ads" on the same Google account.';
  String get termsBodyProgress =>
      'Coins, power-ups, levels, themes and other in-game rewards have no money value and cannot be exchanged or transferred. Your progress is stored only on your device: uninstalling the app or resetting progress deletes it.';
  String get termsBodyWarranty =>
      'The game is provided "as is", without warranties of any kind. To the extent allowed by law, Magivix Studio is not liable for any loss or damage arising from the use of the app.';
  String get termsBodyChanges =>
      'We may update the game and these terms. If the terms change, the app asks you to accept them again before you continue playing. Questions? Visit magivix.com.';

  // ---------------------------------------------------------------- Purchases
  String get removeAdsHeading => 'Ads';
  String get removeAds => 'Remove ads';
  String removeAdsHint(String? price) => price == null
      ? 'No banner and no ads between puzzles, forever'
      : 'No banner and no ads between puzzles, forever · $price';
  String get adsRemovedTitle => 'Ads removed';
  String get adsRemovedHint => 'Thank you for supporting Sand Burst Magic!';
  String get restorePurchase => 'Restore purchase';
  String get restorePurchaseHint =>
      'Already bought "Remove ads"? Get it back here';
  String get purchaseUnavailable =>
      "Purchases aren't available right now. Please try again later.";
  String get restoreStarted => 'Checking Google Play for your purchase…';
  String get purchaseThanks => 'Ads removed. Thank you!';

  // ---------------------------------------------------------------- Feedback & social
  String get sendFeedback => 'Send feedback';
  String get sendFeedbackHint => 'Ideas, problems or praise, we read it all';
  String feedbackSubject(String version) =>
      'Sand Burst Magic feedback (version $version)';
  String get followUs => 'Follow us';
  String socialComingSoon(String name) => 'Our $name page is coming soon.';

  // ---------------------------------------------------------------- Studio
  String get studioHeading => 'Magivix Studio';
  String get studioBody =>
      'Sand Burst Magic is made by Magivix Studio, a small studio making calm, colourful games.';
  String get visitWebsite => 'Visit our website';
  String get linkFailed => "Couldn't open the link. Please try again later.";
  String get emailFailed => "Couldn't open an email app.";
}

class StringsDelegate extends LocalizationsDelegate<Strings> {
  const StringsDelegate();

  static const supportedLocales = [Locale('en')];

  @override
  bool isSupported(Locale locale) =>
      supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<Strings> load(Locale locale) =>
      SynchronousFuture<Strings>(Strings.forLocale(locale));

  @override
  bool shouldReload(StringsDelegate old) => false;
}
