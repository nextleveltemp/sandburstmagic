import 'package:flutter/material.dart';

import '../../core/engine.dart';
import '../../core/progression.dart';
import '../../core/sand.dart';
import '../../l10n/strings.dart';
import '../../state/app_services.dart';
import '../game/board_fx.dart';
import '../game/sand_painter.dart';
import '../theme/sand_theme.dart';
import '../theme/tokens.dart';
import '../widgets/game_widgets.dart';

/// Coins buy power-ups and cosmetics (looks only, never gameplay).
/// Free coins with an optional rewarded ad.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final services = AppScope.of(context);
    final tabs = [
      s.shopPowerUps,
      for (final k in CosmeticKind.values) s.cosmeticKindName(k),
    ];
    return DefaultTabController(
      length: tabs.length,
      initialIndex: initialTab.clamp(0, tabs.length - 1),
      child: ListenableBuilder(
        listenable: services.progress,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: Text(s.shop),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: Space.md),
                child: Center(
                  child: CoinPill(
                    key: const ValueKey('shop-coins'),
                    coins: services.progress.coins,
                  ),
                ),
              ),
            ],
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (final t in tabs) Tab(text: t)],
            ),
          ),
          body: TabBarView(
            children: [
              const _PowerTab(),
              for (final k in CosmeticKind.values) _CosmeticTab(kind: k),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreeCoins extends StatelessWidget {
  const _FreeCoins();

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final services = AppScope.of(context);
    if (!services.ads.canShowAds) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: OutlinedButton.icon(
        key: const ValueKey('free-coins'),
        onPressed: () async {
          if (await watchRewarded(context)) {
            services.progress.addCoins(Coins.rewardedBonus);
          }
        },
        icon: const Icon(Icons.ondemand_video_rounded),
        label: Text(s.watchForCoins(Coins.rewardedBonus)),
      ),
    );
  }
}

class _PowerTab extends StatelessWidget {
  const _PowerTab();

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final pal = AppPalette.of(context);
    final p = AppScope.of(context).progress;
    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        const _FreeCoins(),
        for (final pw in PowerUp.values)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: pal.violet.withValues(alpha: 0.25),
                child: Icon(powerIcon(pw.index), color: pal.text),
              ),
              title: Text('${s.powerName(pw)}  ×${p.count(pw)}'),
              subtitle: Text(s.powerDesc(pw)),
              trailing: FilledButton.tonal(
                key: ValueKey('buy-${pw.name}'),
                onPressed: p.coins >= PowerShop.price(pw)
                    ? () => p.buyPowerUp(pw)
                    : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CoinIcon(size: 16),
                    const SizedBox(width: 4),
                    Text('${PowerShop.price(pw)}'),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CosmeticTab extends StatelessWidget {
  const _CosmeticTab({required this.kind});

  final CosmeticKind kind;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final pal = AppPalette.of(context);
    final services = AppScope.of(context);
    final p = services.progress;
    final base = lookOf(services);
    final selected = p.selected(kind);
    return ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        Text(s.cosmeticsNote, style: TextStyle(color: pal.textMuted)),
        const SizedBox(height: Space.md),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Space.md,
          crossAxisSpacing: Space.md,
          childAspectRatio: 0.78,
          children: [
            for (final c in Cosmetics.ofKind(kind))
              _CosmeticCard(
                cosmetic: c,
                look: _preview(base, c),
                owned: p.owns(c),
                inUse: selected == c.id,
                canAfford: p.coins >= c.price,
                onTap: () {
                  if (p.owns(c)) {
                    p.select(c);
                  } else if (p.buy(c)) {
                    p.select(c);
                    toast(context, s.bought(s.cosmeticName(c)));
                  } else {
                    toast(context, s.notEnoughCoins);
                  }
                },
              ),
          ],
        ),
      ],
    );
  }

  static Look _preview(Look base, Cosmetic c) => Look(
    board: c.kind == CosmeticKind.board ? BoardTheme.byId(c.id) : base.board,
    palette: c.kind == CosmeticKind.palette
        ? SandPalette.byId(c.id)
        : base.palette,
    grain: c.kind == CosmeticKind.grain ? c.id : base.grain,
    burst: c.kind == CosmeticKind.burst ? c.id : base.burst,
    piece: c.kind == CosmeticKind.piece ? c.id : base.piece,
  );
}

class _CosmeticCard extends StatelessWidget {
  const _CosmeticCard({
    required this.cosmetic,
    required this.look,
    required this.owned,
    required this.inUse,
    required this.canAfford,
    required this.onTap,
  });

  final Cosmetic cosmetic;
  final Look look;
  final bool owned;
  final bool inUse;
  final bool canAfford;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final pal = AppPalette.of(context);
    final status = inUse
        ? s.inUse
        : owned
        ? s.use
        : cosmetic.world > 0
        ? s.worldTheme(cosmetic.world)
        : s.buyFor(cosmetic.price);
    return Material(
      key: ValueKey('cosmetic-${cosmetic.key}'),
      color: pal.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(
          color: inUse ? pal.gold : pal.stroke,
          width: inUse ? 2.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: ThemedBackground(
                theme: look.board,
                child: Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: cosmetic.kind == CosmeticKind.piece
                          ? CustomPaint(
                              painter: PiecePainter(const Piece(18, 5), look),
                            )
                          : _MiniBoard(look: look),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.sm),
              child: Column(
                children: [
                  Text(
                    s.cosmeticName(cosmetic),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    status,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      color: inUse
                          ? pal.gold
                          : owned || canAfford
                          ? pal.cyan
                          : pal.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small static board with a sand pile, for previews.
class _MiniBoard extends StatefulWidget {
  const _MiniBoard({required this.look});
  final Look look;

  @override
  State<_MiniBoard> createState() => _MiniBoardState();
}

class _MiniBoardState extends State<_MiniBoard> {
  static final Board _board = makeLayout(7, 5, density: 85);
  late final BoardFx _fx = BoardFx(_board);

  @override
  void dispose() {
    _fx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: SandBoardPainter(
      fx: _fx,
      look: widget.look,
      overlay: BoardOverlay.none,
    ),
  );
}
