import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/engine.dart';
import '../../core/levels.dart';
import '../../core/progression.dart';
import '../../core/sand.dart';
import '../../l10n/strings.dart';
import '../../services/audio_service.dart';
import '../../state/app_services.dart';
import '../../state/game_controller.dart';
import '../../state/launcher.dart';
import '../game/board_fx.dart';
import '../game/sand_painter.dart';
import '../theme/sand_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/game_widgets.dart';
import 'pause_sheet.dart';
import 'results_panel.dart';
import 'shop_screen.dart';

/// The playing screen: board, tray, power-ups, and the panels that appear
/// over it (mechanic intro, "Keep playing?", results). The banner sits at
/// the very bottom, below the tray, with a gap (as in Block Burst Magic).
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<GameScreen> createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late GameController _c = widget.controller;
  late BoardFx _fx = BoardFx(_c.state.board);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  int _shownSerial = 0;

  final GlobalKey _boardKey = GlobalKey();

  /// Tray as shown (the old set stays while the turn animates).
  List<Piece?> _tray = const [];
  Piece? _bonus;

  // Tap-to-place / drag state.
  int? _selected;
  int? _anchorR;
  int? _anchorC;
  bool _dragging = false;
  Offset _dragPos = Offset.zero;

  PowerUp? _power;
  String? _intro;
  bool _endAdDone = false;
  bool _leaving = false;
  int _lastCombo = 0;

  AppServices get _s => _c.services;

  /// The game shown (tests and store screenshots drive it directly).
  GameController get controller => _c;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _attach();
    final def = _c.level;
    if (def != null &&
        def.intro.isNotEmpty &&
        _c.state.moves == 0 &&
        !_c.progress.introSeen(def.intro)) {
      _intro = def.intro;
    }
  }

  void _attach() {
    _c.addListener(_onController);
    _shownSerial = _c.turnSerial;
    _tray = List<Piece?>.of(_c.state.tray);
    _bonus = _c.state.bonus;
    _fx.snap(_c.state.board);
    _s.audio.playMusic(MusicTrackFor.game);
  }

  /// Replaces the game on this screen (next level, play again).
  void _switchTo(GameController next) {
    _c.removeListener(_onController);
    _c.dispose();
    setState(() {
      _c = next;
      _fx.dispose();
      _fx = BoardFx(next.state.board);
      _selected = null;
      _power = null;
      _endAdDone = false;
      _intro = null;
      _attach();
      final def = next.level;
      if (def != null &&
          def.intro.isNotEmpty &&
          !next.progress.introSeen(def.intro)) {
        _intro = def.intro;
      }
    });
  }

  void _onController() {
    if (!mounted) return;
    if (_c.turnSerial != _shownSerial) {
      _shownSerial = _c.turnSerial;
      final turn = _c.lastTurn;
      _fx.reduceMotion = MediaQuery.disableAnimationsOf(context);
      if (turn == null) {
        _fx.snap(_c.state.board);
        _tray = List<Piece?>.of(_c.state.tray);
        _bonus = _c.state.bonus;
      } else {
        _fx.play(turn, _c.state.board, combo: _c.state.combo);
        _turnPopups(turn);
        if (!turn.dealt) {
          _tray = List<Piece?>.of(_c.state.tray);
        } else {
          // Keep the used set (now empty) until the sand has settled.
          _tray = const [null, null, null];
        }
        _bonus = _c.state.bonus;
      }
    }
    if (_c.finished && !_endAdDone) {
      _endAdDone = true;
      // The interstitial (frequency-limited by the ad service) comes a
      // moment after the results appear, never during play.
      Timer(const Duration(seconds: 1), () {
        if (mounted && !_leaving) unawaited(_s.ads.maybeShowInterstitial());
      });
    }
    setState(() {});
  }

  void _turnPopups(Turn turn) {
    final s = Strings.of(context);
    final big = turn.biggestWave;
    if (big >= 2) {
      _fx.popups.add(Popup(s.rowsBurst(big), 0.5, 0.32, life: 1.3, big: true));
    }
    final combo = _c.state.combo;
    if (combo >= 2 && combo != _lastCombo) {
      _fx.popups.add(Popup(s.combo(combo), 0.5, 0.2, life: 1.1, big: true));
    }
    _lastCombo = combo;
    if (_c.state.board.sandCount() == 0 && turn.rows > 0) {
      _fx.popups.add(Popup(s.perfectClear, 0.5, 0.5, life: 1.6, big: true));
    }
    final rev = turn.revealed;
    if (rev != null) {
      _fx.popups.add(Popup(s.revealed(rev), 0.5, 0.12, life: 1.4));
    }
    if (_c.timed && turn.rows > 0) {
      _fx.popups.add(
        Popup(s.plusTime(turn.rows * Modes.timePerRow), 0.85, 0.08),
      );
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1000.0;
    _last = elapsed;
    if (dt <= 0 || dt > 250) return;
    final wasBusy = _fx.busy;
    _fx.tick(dt);
    if (wasBusy && !_fx.busy) {
      // The turn has finished animating: show the real tray.
      setState(() {
        _tray = List<Piece?>.of(_c.state.tray);
        _bonus = _c.state.bonus;
      });
    }
    if (!_fx.animating && _needsLiveFrames) _fx.repaint();
    if (_intro == null && !_paused && !_c.finished) _c.tick(dt.round());
  }

  bool get _needsLiveFrames =>
      _power != null ||
      _c.hint != null ||
      _fx.shown.cells.any((c) => c != null && c.isSand && c.kind != 0);

  @override
  void dispose() {
    _leaving = true;
    _ticker.dispose();
    _c.removeListener(_onController);
    _c.saveNow();
    _c.dispose();
    _fx.dispose();
    _s.audio.playMusic(MusicTrackFor.menu);
    super.dispose();
  }

  // ---------------------------------------------------------- input

  bool get _inputBlocked =>
      _fx.busy || !_c.state.isPlaying || _c.finished || _intro != null;

  Piece? _piece(int slot) => slot == 3 ? _c.state.bonus : _c.state.tray[slot];

  List<int> _cellsFor(int slot, int r, int c) {
    final p = _piece(slot);
    if (p == null) return const [];
    return [
      for (final (dr, dc) in shapes[p.shape].cells)
        if (r + dr >= 0 && r + dr < boardH && c + dc >= 0 && c + dc < boardW)
          (r + dr) * boardW + (c + dc)
        else
          -1,
    ];
  }

  Rect? _boardRect() {
    final box = _boardKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _selectSlot(int slot) {
    if (_inputBlocked || _piece(slot) == null) return;
    _s.audio.play(Sfx.select);
    setState(() {
      _power = null;
      _selected = _selected == slot ? null : slot;
      _anchorR = null;
      _anchorC = null;
    });
  }

  void _onBoardTap(Offset local, Size size) {
    final cell = size.width / boardW;
    final r = (local.dy / cell).floor().clamp(0, boardH - 1);
    final c = (local.dx / cell).floor().clamp(0, boardW - 1);
    if (_power != null) {
      _applyPower(_power!, r, c);
      return;
    }
    final slot = _selected;
    if (slot == null || _inputBlocked) {
      toast(context, Strings.of(context).tapPieceFirst);
      return;
    }
    final p = _piece(slot);
    if (p == null) return;
    final shape = shapes[p.shape];
    // The tapped cell becomes the piece's centre.
    final ar = (r - (shape.rows - 1) ~/ 2).clamp(0, boardH - shape.rows);
    final ac = (c - (shape.cols - 1) ~/ 2).clamp(0, boardW - shape.cols);
    if (_anchorR == ar && _anchorC == ac) {
      _place(slot, ar, ac);
    } else {
      setState(() {
        _anchorR = ar;
        _anchorC = ac;
      });
    }
  }

  void _place(int slot, int r, int c) {
    final ok = _c.placePiece(slot, r, c);
    if (!ok) {
      toast(context, Strings.of(context).placeRejected);
      return;
    }
    setState(() {
      _selected = null;
      _anchorR = null;
      _anchorC = null;
    });
  }

  // Drag from the tray.
  void _dragStart(int slot, Offset global) {
    if (_inputBlocked || _piece(slot) == null) return;
    _s.audio.play(Sfx.select);
    setState(() {
      _power = null;
      _selected = slot;
      _dragging = true;
      _dragPos = global;
    });
    _updateAnchor();
  }

  void _dragUpdate(Offset global) {
    if (!_dragging) return;
    setState(() => _dragPos = global);
    _updateAnchor();
  }

  /// Top-left of the dragged piece (global), lifted above the finger.
  Offset _pieceOrigin(Rect board) {
    final p = _piece(_selected ?? 0);
    if (p == null) return _dragPos;
    final cell = board.width / boardW;
    final shape = shapes[p.shape];
    return Offset(
      _dragPos.dx - shape.cols * cell / 2,
      _dragPos.dy - shape.rows * cell - cell * 1.4,
    );
  }

  void _updateAnchor() {
    final board = _boardRect();
    final slot = _selected;
    if (board == null || slot == null) return;
    final cell = board.width / boardW;
    final o = _pieceOrigin(board) - board.topLeft;
    final r = (o.dy / cell).round();
    final c = (o.dx / cell).round();
    final p = _piece(slot)!;
    final shape = shapes[p.shape];
    final inside =
        r >= -1 && c >= -1 && r + shape.rows <= boardH + 1 && c + shape.cols <= boardW + 1;
    setState(() {
      _anchorR = inside ? r.clamp(0, boardH - shape.rows) : null;
      _anchorC = inside ? c.clamp(0, boardW - shape.cols) : null;
    });
  }

  void _dragEnd() {
    if (!_dragging) return;
    final slot = _selected;
    final r = _anchorR;
    final c = _anchorC;
    setState(() => _dragging = false);
    if (slot != null && r != null && c != null && _c.state.fits(slot, r, c)) {
      _place(slot, r, c);
    } else {
      if (r != null) _s.audio.play(Sfx.invalid);
      setState(() {
        _anchorR = null;
        _anchorC = null;
      });
    }
  }

  // ---------------------------------------------------------- power-ups

  Future<void> _tapPower(PowerUp p) async {
    if (_inputBlocked) return;
    final s = Strings.of(context);
    if (!_c.powerUpsAllowed) {
      toast(context, s.noPowerUps);
      return;
    }
    if (_power == p) {
      setState(() => _power = null);
      return;
    }
    var free = false;
    if (_c.progress.count(p) <= 0) {
      final choice = await _askForPower(p);
      if (!mounted || choice == null) return;
      if (choice == 'ad') {
        if (!await watchRewarded(context)) return;
        free = true;
      } else if (!_c.progress.buyPowerUp(p)) {
        if (mounted) toast(context, s.notEnoughCoins);
        return;
      }
    }
    if (!mounted) return;
    switch (p.target) {
      case PowerTarget.none:
        _usePower(p, null, free: free);
      case PowerTarget.side:
        final side = await showModalBottomSheet<int>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(ctx, -1),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(s.left),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pop(ctx, 1),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(s.right),
                ),
              ],
            ),
          ),
        );
        if (side != null) _usePower(p, side, free: free);
      default:
        setState(() {
          _power = p;
          _freePower = free;
          _selected = null;
          _anchorR = null;
        });
        toast(context, s.powerPrompt(p));
    }
  }

  bool _freePower = false;
  bool _paused = false;

  Future<String?> _askForPower(PowerUp p) {
    final s = Strings.of(context);
    final price = PowerShop.price(p);
    final canBuy = _c.progress.coins >= price;
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        final pal = AppPalette.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.powerName(p),
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: Space.xs),
                Text(s.powerDesc(p), style: TextStyle(color: pal.textMuted)),
                const SizedBox(height: Space.lg),
                FilledButton.icon(
                  onPressed: canBuy ? () => Navigator.pop(ctx, 'buy') : null,
                  icon: const CoinIcon(),
                  label: Text(s.buyFor(price)),
                ),
                const SizedBox(height: Space.sm),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'ad'),
                  icon: const Icon(Icons.ondemand_video_rounded),
                  label: Text(s.watchAdForPower),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _applyPower(PowerUp p, int r, int c) {
    final int arg = switch (p.target) {
      PowerTarget.row => r,
      PowerTarget.colour => _fx.shown.cells[r * boardW + c]?.colour ?? -1,
      _ => r * boardW + c,
    };
    _usePower(p, arg, free: _freePower);
  }

  void _usePower(PowerUp p, int? arg, {required bool free}) {
    final ok = _c.usePowerUp(p, arg, free: free);
    if (!ok) {
      toast(context, Strings.of(context).powerCannot);
      if (free) return; // keep the targeting open: the ad was already watched
    }
    setState(() {
      _power = null;
      _freePower = false;
    });
  }

  BoardOverlay _overlay() {
    final slot = _selected;
    var preview = const <int>[];
    var valid = true;
    var colour = 0;
    if (slot != null && _anchorR != null && _anchorC != null) {
      preview = _cellsFor(slot, _anchorR!, _anchorC!);
      valid = _c.state.fits(slot, _anchorR!, _anchorC!);
      colour = _piece(slot)?.colour ?? 0;
    }
    final h = _c.hint;
    final hint = h == null ? const <int>[] : _cellsFor(h.$1, h.$2, h.$3);
    final p = _power;
    var rows = const <int>[];
    var cells = const <int>[];
    if (p != null) {
      if (p.target == PowerTarget.row) {
        rows = [
          for (var r = 0; r < boardH; r++)
            if (powerApplies(_c.state, _c.config, p, r)) r,
        ];
      } else {
        cells = [
          for (var i = 0; i < boardN; i++)
            if (_fx.shown.cells[i] != null &&
                (p != PowerUp.crusher && p != PowerUp.blast ||
                    _fx.shown.cells[i]!.isSand))
              i,
        ];
      }
    }
    return BoardOverlay(
      preview: preview,
      previewValid: valid,
      previewColour: colour,
      hint: hint,
      targetRows: rows,
      targetCells: cells,
    );
  }

  // ---------------------------------------------------------- actions

  Future<void> _hint() async {
    if (_inputBlocked) return;
    final s = Strings.of(context);
    var paid = false;
    if (!_c.hintIsFree) {
      if (!await watchRewarded(context)) return;
      paid = true;
    }
    final ok = await _c.showHint(paid: paid);
    if (!mounted) return;
    toast(context, ok ? s.hintShown : s.noHint);
  }

  Future<void> _undo() async {
    if (_fx.busy) return;
    final s = Strings.of(context);
    if (!_c.canUndo) {
      toast(context, s.nothingToUndo);
      return;
    }
    var paid = false;
    if (!_c.undoIsFree) {
      if (!await watchRewarded(context)) return;
      paid = true;
    }
    _c.undo(paid: paid);
  }

  Future<void> _pause() async {
    _paused = true;
    final action = await showPauseSheet(context, _c);
    _paused = false;
    if (!mounted) return;
    switch (action) {
      case PauseAction.restart:
        _restart();
      case PauseAction.home:
        Navigator.of(context).pop();
      default:
        break;
    }
  }

  void _restart() {
    final next = switch (_c.mode) {
      GameMode.campaign => Launcher.level(_s, _c.spec.level, fresh: true),
      GameMode.daily => null,
      _ => Launcher.mode(_s, _c.mode, fresh: true),
    };
    if (next != null) {
      _switchTo(next);
    } else {
      // Daily: start the same puzzle again.
      _switchTo(GameController.start(_s, _c.spec, _c.config));
    }
  }

  void _nextLevel() {
    final n = _c.spec.level + 1;
    final next = n <= LevelCatalog.count ? Launcher.level(_s, n) : null;
    if (next == null) {
      Navigator.of(context).pop();
    } else {
      _switchTo(next);
    }
  }

  Future<void> _continueWithAd() async {
    if (await watchRewarded(context)) _c.keepPlaying();
  }

  Future<void> _doubleCoins() async {
    if (await watchRewarded(context)) _c.doubleReward();
  }

  // ---------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final look = lookOf(_s);
    final ads = _s.ads;
    final bannerH = ads.gameBannerHeight;
    final pal = AppPalette.of(context);
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: look.board.bottom,
        body: ThemedBackground(
          theme: look.board,
          child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      SafeArea(
                        bottom: bannerH == 0,
                        child: Column(
                          children: [
                            _TopBar(
                              controller: _c,
                              onPause: _pause,
                              light: look.board.light,
                            ),
                            _GoalBar(controller: _c, light: look.board.light),
                            Expanded(child: _boardArea(look)),
                            _TrayRow(
                              tray: _tray,
                              bonus: _bonus,
                              look: look,
                              selected: _dragging ? null : _selected,
                              dragging: _dragging ? _selected : null,
                              onTap: _selectSlot,
                              onDragStart: _dragStart,
                              onDragUpdate: _dragUpdate,
                              onDragEnd: _dragEnd,
                              fits: (slot) {
                                final p = _piece(slot);
                                return p != null &&
                                    fitsAnywhere(_c.state.board, p.shape);
                              },
                            ),
                            _PowerBar(
                              controller: _c,
                              active: _power,
                              onPower: _tapPower,
                              onHint: _hint,
                              onUndo: _undo,
                            ),
                            // Keep a gap between the controls and the
                            // banner, so nobody taps the ad by accident.
                            SizedBox(height: bannerH > 0 ? Space.lg : Space.xs),
                          ],
                        ),
                      ),
                      if (_dragging) _floatingPiece(look),
                      if (_intro != null) _introCard(_intro!, pal),
                      if (_c.offerContinue)
                        _ContinuePanel(
                          adReady: ads.rewardedReady,
                          onWatch: _continueWithAd,
                          onDecline: _c.declineContinue,
                        ),
                      if (_c.finished && !_fx.busy)
                        ResultsPanel(
                          controller: _c,
                          onNext: _nextLevel,
                          onAgain: _restart,
                          onHome: () => Navigator.of(context).pop(),
                          onDouble: _doubleCoins,
                        ),
                    ],
                  ),
                ),
                if (bannerH > 0)
                  ColoredBox(
                    color: look.board.bottom,
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        key: const ValueKey('game-banner-slot'),
                        height: bannerH,
                        width: double.infinity,
                        child: Center(child: ads.buildBanner(context)),
                      ),
                    ),
                  ),
              ],
            ),
        ),
      ),
    );
  }

  Widget _boardArea(Look look) {
    final s = Strings.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final side = (box.maxWidth - Space.lg * 2)
            .clamp(0.0, box.maxHeight - Space.sm)
            .toDouble();
        return Center(
          child: SizedBox.square(
            dimension: side,
            child: Semantics(
              label: s.boardLabel,
              child: GestureDetector(
                key: _boardKey,
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _onBoardTap(d.localPosition, Size.square(side)),
                child: RepaintBoundary(
                  child: CustomPaint(
                    key: const ValueKey('sand-board'),
                    size: Size.square(side),
                    painter: SandBoardPainter(
                      fx: _fx,
                      look: look,
                      overlay: _overlay(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _floatingPiece(Look look) {
    final board = _boardRect();
    final p = _piece(_selected ?? 0);
    if (board == null || p == null) return const SizedBox.shrink();
    final cell = board.width / boardW;
    final shape = shapes[p.shape];
    final origin = _pieceOrigin(board);
    final stack = context.findRenderObject();
    final local = stack is RenderBox ? stack.globalToLocal(origin) : origin;
    return Positioned(
      left: local.dx,
      top: local.dy,
      child: IgnorePointer(
        child: CustomPaint(
          size: Size(shape.cols * cell, shape.rows * cell),
          painter: _FloatPainter(p, look, cell),
        ),
      ),
    );
  }

  Widget _introCard(String id, AppPalette pal) {
    final s = Strings.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Material(
              color: pal.surface,
              borderRadius: BorderRadius.circular(Radii.xl),
              child: Padding(
                padding: const EdgeInsets.all(Space.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: pal.gold, size: 40),
                    const SizedBox(height: Space.md),
                    Text(
                      s.introTitle(id),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      s.introBody(id),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: pal.textMuted, fontSize: 16),
                    ),
                    const SizedBox(height: Space.lg),
                    if (_c.level != null)
                      for (final o in _c.level!.objectives)
                        Text(
                          s.objectiveText(o),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                    const SizedBox(height: Space.lg),
                    FilledButton(
                      onPressed: () {
                        _c.progress.markIntroSeen(id);
                        setState(() => _intro = null);
                      },
                      child: Text(s.gotIt),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Music for menus and games.
abstract final class MusicTrackFor {
  static const menu = MusicTrack.main;
  static const game = MusicTrack.relax;
}

class _FloatPainter extends CustomPainter {
  _FloatPainter(this.piece, this.look, this.cell);
  final Piece piece;
  final Look look;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) =>
      PiecePainter.paintBlocks(canvas, Offset.zero, cell, piece, look);

  @override
  bool shouldRepaint(_FloatPainter old) =>
      old.piece.code != piece.code || old.cell != cell;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.onPause,
    required this.light,
  });

  final GameController controller;
  final VoidCallback onPause;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final c = controller;
    final fg = light ? const Color(0xFF131A3E) : Colors.white;
    final muted = fg.withValues(alpha: 0.7);
    final best = c.progress.stats.best(c.mode);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.sm, Space.xs, Space.md, 0),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('pause-button'),
            tooltip: s.pause,
            onPressed: onPause,
            icon: Icon(Icons.pause_rounded, color: fg, size: 30),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  s.gameTitle(c.mode, c.spec.level),
                  style: TextStyle(color: muted, fontWeight: FontWeight.w600),
                ),
                Semantics(
                  label: '${s.score} ${c.state.score}',
                  child: ExcludeSemantics(
                    child: TweenAnimationBuilder<int>(
                      tween: IntTween(end: c.state.score),
                      duration: const Duration(milliseconds: 450),
                      builder: (context, v, _) => Text(
                        s.formatNumber(v),
                        key: const ValueKey('score'),
                        style: TextStyle(
                          color: fg,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFF6C453),
                  size: 20,
                ),
                Text(
                  s.formatNumber(best > c.state.score ? best : c.state.score),
                  style: TextStyle(color: muted, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalBar extends StatelessWidget {
  const _GoalBar({required this.controller, required this.light});

  final GameController controller;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final c = controller;
    final fg = light ? const Color(0xFF131A3E) : Colors.white;
    final chips = <Widget>[];
    for (final o in c.config.objectives) {
      final v = objectiveValue(c.state, o);
      final done = v >= o.target;
      chips.add(
        _Chip(
          icon: done ? Icons.check_circle_rounded : Icons.flag_rounded,
          text: '${s.objectiveText(o)}  ${s.objectiveProgress(v, o.target)}',
          fg: fg,
          highlight: done,
        ),
      );
    }
    if (c.movesLeft >= 0) {
      chips.add(
        _Chip(
          icon: Icons.grid_view_rounded,
          text: '${s.movesLeftLabel} ${c.movesLeft}',
          fg: fg,
          warn: c.movesLeft <= 3,
        ),
      );
    }
    if (c.timed) {
      chips.add(
        _Chip(
          icon: Icons.timer_rounded,
          text: s.clock(c.timeLeftMs),
          fg: fg,
          warn: c.timeLeftMs < 15000,
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox(height: Space.sm);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.xs,
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: Space.sm,
        runSpacing: Space.xs,
        children: chips,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.text,
    required this.fg,
    this.highlight = false,
    this.warn = false,
  });

  final IconData icon;
  final String text;
  final Color fg;
  final bool highlight;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final colour = warn
        ? const Color(0xFFFF6F86)
        : highlight
        ? const Color(0xFF2ECC71)
        : fg;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: colour.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colour),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                color: colour,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrayRow extends StatelessWidget {
  const _TrayRow({
    required this.tray,
    required this.bonus,
    required this.look,
    required this.selected,
    required this.dragging,
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.fits,
  });

  final List<Piece?> tray;
  final Piece? bonus;
  final Look look;
  final int? selected;
  final int? dragging;
  final void Function(int slot) onTap;
  final void Function(int slot, Offset global) onDragStart;
  final void Function(Offset global) onDragUpdate;
  final VoidCallback onDragEnd;
  final bool Function(int slot) fits;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final slots = [0, 1, 2, if (bonus != null) 3];
    return SizedBox(
      height: 104,
      child: Row(
        children: [
          for (final slot in slots)
            Expanded(
              child: Builder(
                builder: (context) {
                  final p = slot == 3 ? bonus : tray[slot];
                  if (p == null) {
                    return const SizedBox.expand();
                  }
                  final isSel = selected == slot;
                  final hidden = dragging == slot;
                  final canFit = fits(slot);
                  return Semantics(
                    button: true,
                    selected: isSel,
                    label: s.pieceLabel(
                      slot,
                      shapes[p.shape].name,
                      shapes[p.shape].size,
                      p.colour,
                      p.kind,
                    ),
                    child: GestureDetector(
                      key: ValueKey('tray-$slot'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(slot),
                      onPanStart: (d) => onDragStart(slot, d.globalPosition),
                      onPanUpdate: (d) => onDragUpdate(d.globalPosition),
                      onPanEnd: (_) => onDragEnd(),
                      onPanCancel: onDragEnd,
                      child: AnimatedScale(
                        scale: isSel ? 1.12 : 1,
                        duration: const Duration(milliseconds: 140),
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey('piece-${p.code}-$slot'),
                          tween: Tween(begin: 0.4, end: 1),
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutBack,
                          builder: (context, v, child) =>
                              Transform.scale(scale: v, child: child),
                          child: Opacity(
                            opacity: hidden ? 0.15 : 1,
                            child: CustomPaint(
                              size: const Size.square(96),
                              painter: PiecePainter(p, look, dim: !canFit),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PowerBar extends StatelessWidget {
  const _PowerBar({
    required this.controller,
    required this.active,
    required this.onPower,
    required this.onHint,
    required this.onUndo,
  });

  final GameController controller;
  final PowerUp? active;
  final void Function(PowerUp p) onPower;
  final VoidCallback onHint;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final pal = AppPalette.of(context);
    final c = controller;
    Widget button({
      required Key key,
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      String? badge,
      bool on = false,
      bool enabled = true,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Tooltip(
          message: label,
          child: Semantics(
            button: true,
            label: label,
            child: InkWell(
              key: key,
              onTap: onTap,
              borderRadius: BorderRadius.circular(Radii.md),
              child: Opacity(
                opacity: enabled ? 1 : 0.4,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: on
                        ? pal.gold.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(
                      color: on ? pal.gold : Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(child: Icon(icon, color: Colors.white, size: 24)),
                      if (badge != null)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: pal.violet,
                              borderRadius: BorderRadius.circular(Radii.pill),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 58,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 6),
        children: [
          button(
            key: const ValueKey('hint-button'),
            icon: Icons.lightbulb_rounded,
            label: s.hint,
            onTap: onHint,
            badge: c.hintIsFree ? s.free : '▶',
          ),
          button(
            key: const ValueKey('undo-button'),
            icon: Icons.undo_rounded,
            label: s.undo,
            onTap: onUndo,
            badge: c.canUndo ? (c.undoIsFree ? s.free : '▶') : null,
            enabled: c.canUndo,
          ),
          const SizedBox(width: Space.sm),
          for (final p in PowerUp.values)
            button(
              key: ValueKey('power-${p.name}'),
              icon: powerIcon(p.index),
              label: s.powerCount(p, c.progress.count(p)),
              onTap: () => onPower(p),
              badge: c.progress.count(p) > 0 ? '${c.progress.count(p)}' : '+',
              on: active == p,
              enabled: c.powerUpsAllowed,
            ),
        ],
      ),
    );
  }
}

class _ContinuePanel extends StatelessWidget {
  const _ContinuePanel({
    required this.adReady,
    required this.onWatch,
    required this.onDecline,
  });

  final bool adReady;
  final VoidCallback onWatch;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final pal = AppPalette.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.xl),
            child: Material(
              color: pal.surface,
              borderRadius: BorderRadius.circular(Radii.xl),
              child: Padding(
                padding: const EdgeInsets.all(Space.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hourglass_bottom_rounded, size: 44, color: pal.cyan),
                    const SizedBox(height: Space.md),
                    Text(
                      s.continueTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      s.continueBody,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: pal.textMuted),
                    ),
                    const SizedBox(height: Space.lg),
                    FilledButton.icon(
                      key: const ValueKey('continue-watch'),
                      onPressed: onWatch,
                      icon: const Icon(Icons.ondemand_video_rounded),
                      label: Text(adReady ? s.continueWatch : s.adLoading),
                    ),
                    const SizedBox(height: Space.sm),
                    TextButton(
                      key: const ValueKey('continue-decline'),
                      onPressed: onDecline,
                      child: Text(s.noThanks),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the shop from inside a game (power-ups tab).
void openShopFromGame(BuildContext context) => Navigator.of(
  context,
).push(FadeScaleRoute<void>(builder: (_) => const ShopScreen()));
