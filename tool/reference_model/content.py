"""Sand Burst Magic campaign content: six worlds, 100 levels.

Each level is written here as a *specification*; gen_levels.py turns it
into a concrete level (seed, settled starting board, move limit, stars)
and proves it winnable by playing it with the bot. Only proven levels are
shipped, together with the bot's winning moves (replayed by the Dart
tests).

Objectives: ('rows', n) clear n rows - ('score', n) reach n points -
('multi', n) clear two or more rows at once n times - ('special', n, kind)
clear n grains of a special sand - ('obstacles', n) break n obstacles.

limit: None (no move limit), or 'auto' (set from the bot's winning game,
see SLACK).
"""
from core import (CRYSTAL, CRYSTAL_WALL, EXPLOSIVE, FROZEN, GOLDEN, HEAVY, ICE,
                  LOCKED, MAGNETIC, MOVER, MYSTERY, RAINBOW, STICKY, STONE,
                  TRAP, UNBREAKABLE, VOLCANIC, WOOD, W)

# Colour indices: 0 ruby, 1 orange, 2 golden, 3 emerald, 4 ocean, 5 purple,
# 6 pink, 7 turquoise, 8 coral, 9 lavender.
WORLDS = [
    # (id, name, piece palette)
    ('candy', 'Candy Dunes', [6, 9, 2, 7, 0, 1]),
    ('crystal', 'Crystal Desert', [7, 9, 4, 2, 5, 6]),
    ('ocean', 'Ocean Sands', [4, 7, 3, 9, 5, 2]),
    ('sunset', 'Sunset Valley', [1, 8, 0, 2, 6, 5]),
    ('forest', 'Mystic Forest', [3, 5, 9, 7, 2, 6]),
    ('cosmic', 'Cosmic Sands', [5, 6, 7, 4, 2, 0, 3, 1]),
]
CLASSIC_PALETTE = [0, 1, 2, 3, 4, 5, 6, 7]

# Move limit = ceil(bot moves * SLACK[world]) + 2. Humans get more room
# than the bot needed, a little less in later worlds.
SLACK = [1.8, 1.7, 1.6, 1.5, 1.45, 1.4]


def X(*cells):
    """Blocked cells given as (row, col)."""
    return tuple(r * W + c for r, c in cells)


def corners(n):
    out = []
    for r in range(n):
        for c in range(n - r):
            out += [(r, c), (r, W - 1 - c)]
    return X(*out)


PILLARS = X(*[(r, c) for r in range(0, 4) for c in (2, 7)])
NOTCH = X(*[(r, c) for r in range(0, 3) for c in (4, 5)])
SIDES = X(*[(r, c) for r in range(0, 5) for c in (0, 9)])


def L(world, objectives, limit=None, layout=None, pieces=None,
      weights='default', power=True, intro=None):
    objectives = [(o[0], o[1], o[2] if len(o) > 2 else 0) for o in objectives]
    return dict(world=world, objectives=objectives, limit=limit,
                layout=layout, pieces=pieces or {}, weights=weights,
                power=power, intro=intro)


def lay(fill, density=78, obstacles=(), specials=(), blocked=(), lock_rows=3):
    return dict(fill=fill, density=density, obstacles=list(obstacles),
                specials=list(specials), blocked=tuple(blocked),
                lock_rows=lock_rows)


LEVELS = [
    # ---------------- World 1: Candy Dunes - the basics -----------------
    L(1, [('rows', 1)], weights='gentle', intro='place'),
    L(1, [('rows', 2)], weights='gentle', intro='sand'),
    L(1, [('rows', 3)], layout=lay(2, 70), weights='gentle', intro='rows'),
    L(1, [('score', 500)], layout=lay(2, 75), weights='gentle', intro='score'),
    L(1, [('rows', 4)], layout=lay(3, 70), weights='gentle'),
    L(1, [('rows', 5)], layout=lay(3, 80), weights='gentle'),
    L(1, [('score', 900)], layout=lay(3, 72), weights='gentle'),
    L(1, [('multi', 1)], layout=lay(3, 88), weights='gentle', intro='multi'),
    L(1, [('rows', 5)], 'auto', layout=lay(3, 75), weights='gentle',
      intro='limit'),
    L(1, [('rows', 6)], layout=lay(4, 70)),
    L(1, [('score', 1500)], 'auto', layout=lay(3, 80)),
    L(1, [('multi', 1), ('rows', 5)], layout=lay(4, 85)),
    L(1, [('rows', 7)], 'auto', layout=lay(4, 75)),
    L(1, [('score', 2000)], layout=lay(4, 80)),
    L(1, [('multi', 2)], layout=lay(4, 88)),
    L(1, [('rows', 8)], 'auto', layout=lay(4, 80)),
    L(1, [('rows', 6), ('score', 2000)], 'auto', layout=lay(4, 80),
      power=False, intro='nopower'),

    # ---------------- World 2: Crystal Desert - crystal, gold, stone ----
    L(2, [('special', 3, CRYSTAL)], pieces={CRYSTAL: 25}, layout=lay(3, 70),
      intro='crystal'),
    L(2, [('rows', 6), ('special', 4, CRYSTAL)], pieces={CRYSTAL: 18},
      layout=lay(3, 75)),
    L(2, [('special', 3, GOLDEN)], pieces={GOLDEN: 20}, layout=lay(3, 72),
      intro='golden'),
    L(2, [('obstacles', 2)], layout=lay(3, 70, obstacles=[(STONE, 3, 6, 9)]),
      intro='stone'),
    L(2, [('score', 2500)], 'auto', pieces={CRYSTAL: 15},
      layout=lay(4, 78)),
    L(2, [('obstacles', 4)], layout=lay(3, 72, obstacles=[(STONE, 5, 5, 9)])),
    L(2, [('obstacles', 1)],
      layout=lay(3, 70, obstacles=[(CRYSTAL_WALL, 2, 6, 9)]),
      intro='crystalWall'),
    L(2, [('rows', 8), ('special', 5, GOLDEN)], 'auto',
      pieces={GOLDEN: 15}, layout=lay(4, 75)),
    L(2, [('multi', 2), ('special', 4, CRYSTAL)], pieces={CRYSTAL: 15},
      layout=lay(4, 85)),
    L(2, [('obstacles', 4)], 'auto',
      layout=lay(4, 72, obstacles=[(STONE, 3, 5, 9), (CRYSTAL_WALL, 2, 6, 9)])),
    L(2, [('rows', 9)], 'auto', layout=lay(4, 78)),
    L(2, [('special', 6, CRYSTAL), ('special', 3, GOLDEN)],
      pieces={CRYSTAL: 15, GOLDEN: 10}, layout=lay(3, 75)),
    L(2, [('obstacles', 6)], 'auto',
      layout=lay(4, 70, obstacles=[(STONE, 6, 4, 9)])),
    L(2, [('multi', 3)], layout=lay(5, 86)),
    L(2, [('score', 3500), ('obstacles', 3)], 'auto',
      layout=lay(4, 75, obstacles=[(CRYSTAL_WALL, 3, 5, 9)])),
    L(2, [('rows', 8), ('special', 5, CRYSTAL)], 'auto',
      pieces={CRYSTAL: 15}, layout=lay(4, 80), power=False),
    L(2, [('rows', 10), ('obstacles', 4)], 'auto',
      layout=lay(5, 76, obstacles=[(STONE, 4, 4, 9)])),

    # ---------------- World 3: Ocean Sands - heavy, frozen, ice, wood ----
    L(3, [('rows', 6)], pieces={HEAVY: 25}, layout=lay(3, 72), intro='heavy'),
    L(3, [('special', 4, HEAVY)], pieces={HEAVY: 20}, layout=lay(3, 75)),
    L(3, [('rows', 6)], layout=lay(4, 75, specials=[(FROZEN, 6)]),
      intro='frozen'),
    L(3, [('special', 10, FROZEN)], pieces={FROZEN: 20},
      layout=lay(4, 78, specials=[(FROZEN, 6)])),
    L(3, [('obstacles', 3)], layout=lay(3, 72, obstacles=[(ICE, 4, 5, 9)]),
      intro='ice'),
    L(3, [('obstacles', 3)], layout=lay(3, 72, obstacles=[(WOOD, 4, 5, 9)]),
      intro='wood'),
    L(3, [('rows', 8)], 'auto', pieces={HEAVY: 15},
      layout=lay(4, 75, specials=[(FROZEN, 5)])),
    L(3, [('obstacles', 5)], 'auto',
      layout=lay(4, 70, obstacles=[(ICE, 3, 4, 9), (WOOD, 3, 4, 9)])),
    L(3, [('multi', 2), ('special', 4, FROZEN)],
      layout=lay(4, 85, specials=[(FROZEN, 7)])),
    L(3, [('score', 3500)], 'auto', pieces={HEAVY: 12, FROZEN: 6},
      layout=lay(4, 78)),
    L(3, [('rows', 10)], layout=lay(5, 78, obstacles=[(WOOD, 3, 4, 9)])),
    L(3, [('obstacles', 6), ('rows', 6)], 'auto',
      layout=lay(4, 72, obstacles=[(ICE, 4, 4, 9), (STONE, 2, 6, 9)])),
    L(3, [('special', 6, HEAVY), ('special', 5, FROZEN)],
      pieces={HEAVY: 20}, layout=lay(4, 78, specials=[(FROZEN, 8)])),
    L(3, [('multi', 3)], 'auto', layout=lay(5, 86)),
    L(3, [('score', 4000), ('obstacles', 4)], 'auto',
      layout=lay(4, 75, obstacles=[(WOOD, 3, 5, 9), (ICE, 3, 5, 9)])),
    L(3, [('rows', 10)], 'auto', pieces={HEAVY: 12, FROZEN: 8},
      layout=lay(5, 78), power=False),
    L(3, [('rows', 12), ('obstacles', 5)], 'auto',
      layout=lay(5, 74, obstacles=[(ICE, 3, 4, 9), (WOOD, 3, 4, 9)],
                 specials=[(FROZEN, 5)])),

    # ---------------- World 4: Sunset Valley - explosive, volcanic, sticky, traps
    L(4, [('special', 2, EXPLOSIVE)], pieces={EXPLOSIVE: 20},
      layout=lay(3, 72), intro='explosive'),
    L(4, [('rows', 8)], pieces={EXPLOSIVE: 12}, layout=lay(4, 78)),
    L(4, [('special', 2, VOLCANIC)], pieces={VOLCANIC: 18},
      layout=lay(4, 75), intro='volcanic'),
    L(4, [('rows', 6)], pieces={STICKY: 18}, layout=lay(3, 72),
      intro='sticky'),
    L(4, [('obstacles', 3), ('rows', 4)],
      layout=lay(3, 70, obstacles=[(TRAP, 3, 5, 9)]), intro='trap'),
    L(4, [('score', 4000)], 'auto', pieces={EXPLOSIVE: 10, VOLCANIC: 8},
      layout=lay(4, 78)),
    L(4, [('rows', 8), ('special', 3, EXPLOSIVE)], 'auto',
      pieces={EXPLOSIVE: 15}, layout=lay(4, 76)),
    L(4, [('obstacles', 2)], 'auto',
      layout=lay(4, 72, obstacles=[(TRAP, 2, 5, 9), (STONE, 2, 5, 9)])),
    L(4, [('multi', 2)], pieces={STICKY: 12, EXPLOSIVE: 8}, layout=lay(4, 85)),
    L(4, [('rows', 10)], 'auto', pieces={VOLCANIC: 10, STICKY: 8},
      layout=lay(4, 78)),
    L(4, [('special', 4, VOLCANIC), ('rows', 8)], pieces={VOLCANIC: 15},
      layout=lay(4, 78)),
    L(4, [('obstacles', 5)], 'auto',
      layout=lay(4, 72, obstacles=[(TRAP, 2, 5, 9), (WOOD, 4, 4, 9)])),
    L(4, [('score', 5000)], 'auto',
      pieces={EXPLOSIVE: 10, VOLCANIC: 8, STICKY: 6}, layout=lay(5, 78)),
    L(4, [('multi', 3), ('special', 3, EXPLOSIVE)], pieces={EXPLOSIVE: 12},
      layout=lay(5, 86)),
    L(4, [('rows', 12)], 'auto', pieces={STICKY: 12},
      layout=lay(5, 76, obstacles=[(TRAP, 2, 5, 9)])),
    L(4, [('rows', 10), ('obstacles', 4)], 'auto',
      pieces={EXPLOSIVE: 12, VOLCANIC: 8},
      layout=lay(5, 74, obstacles=[(STONE, 3, 4, 9), (TRAP, 1, 5, 9)]),
      power=False),
    L(4, [('score', 6000), ('special', 4, VOLCANIC)], 'auto',
      pieces={VOLCANIC: 14, STICKY: 8}, layout=lay(5, 78)),

    # ---------------- World 5: Mystic Forest - magnetic, mystery, rainbow, locks
    L(5, [('special', 3, MAGNETIC)], pieces={MAGNETIC: 20},
      layout=lay(3, 74), intro='magnetic'),
    L(5, [('rows', 8)], pieces={MYSTERY: 20}, layout=lay(4, 76),
      intro='mystery'),
    L(5, [('special', 4, RAINBOW)], pieces={RAINBOW: 20}, layout=lay(3, 74),
      intro='rainbow'),
    L(5, [('obstacles', 2)],
      layout=lay(3, 72, obstacles=[(LOCKED, 2, 5, 9)], lock_rows=4),
      intro='locked'),
    L(5, [('rows', 8)], layout=lay(3, 74, blocked=corners(3)),
      intro='blocked'),
    L(5, [('score', 5000)], 'auto', pieces={MAGNETIC: 10, RAINBOW: 8},
      layout=lay(4, 78)),
    L(5, [('rows', 10)], 'auto', pieces={MYSTERY: 15},
      layout=lay(4, 76, blocked=PILLARS)),
    L(5, [('obstacles', 3), ('rows', 6)], 'auto',
      layout=lay(4, 72, obstacles=[(LOCKED, 3, 4, 9)], lock_rows=5)),
    L(5, [('multi', 3)], pieces={MAGNETIC: 10}, layout=lay(5, 86,
                                                            blocked=NOTCH)),
    L(5, [('special', 5, RAINBOW), ('special', 3, MAGNETIC)],
      pieces={RAINBOW: 15, MAGNETIC: 12}, layout=lay(4, 76)),
    L(5, [('rows', 12)], 'auto', pieces={MYSTERY: 10, MAGNETIC: 8},
      layout=lay(5, 76, blocked=SIDES)),
    L(5, [('obstacles', 5)], 'auto',
      layout=lay(4, 72, obstacles=[(LOCKED, 2, 5, 9), (STONE, 3, 4, 9),
                                   (ICE, 2, 4, 9)], lock_rows=4)),
    L(5, [('score', 6000), ('multi', 2)], 'auto',
      pieces={RAINBOW: 8, MYSTERY: 8, STICKY: 6}, layout=lay(5, 80)),
    L(5, [('rows', 12), ('special', 4, MAGNETIC)], 'auto',
      pieces={MAGNETIC: 14}, layout=lay(5, 78, blocked=corners(2)),
      power=False),
    L(5, [('obstacles', 6), ('rows', 8)], 'auto',
      layout=lay(5, 72, obstacles=[(LOCKED, 3, 4, 9), (WOOD, 3, 4, 9)],
                 specials=[(FROZEN, 5)], lock_rows=5)),
    L(5, [('score', 7000)], 'auto',
      pieces={MAGNETIC: 8, MYSTERY: 8, RAINBOW: 6, VOLCANIC: 6},
      layout=lay(5, 78, blocked=PILLARS)),

    # ---------------- World 6: Cosmic Sands - moving barriers, everything
    L(6, [('rows', 8)], layout=lay(3, 72, obstacles=[(MOVER, 2, 4, 7)]),
      intro='mover'),
    L(6, [('obstacles', 2)],
      layout=lay(3, 70, obstacles=[(MOVER, 2, 4, 8),
                                   (UNBREAKABLE, 2, 6, 9)]),
      intro='unbreakable'),
    L(6, [('score', 6000)], 'auto', pieces={CRYSTAL: 10, EXPLOSIVE: 8},
      layout=lay(4, 78, obstacles=[(MOVER, 1, 4, 7)])),
    L(6, [('rows', 10)], 'auto', pieces={HEAVY: 8, STICKY: 8, MAGNETIC: 6},
      layout=lay(4, 76, obstacles=[(UNBREAKABLE, 2, 5, 9)])),
    L(6, [('multi', 3), ('obstacles', 3)],
      layout=lay(5, 84, obstacles=[(CRYSTAL_WALL, 3, 4, 9)])),
    L(6, [('special', 5, GOLDEN), ('rows', 8)], 'auto',
      pieces={GOLDEN: 15, MYSTERY: 8}, layout=lay(4, 76)),
    L(6, [('obstacles', 6)], 'auto',
      layout=lay(4, 72, obstacles=[(MOVER, 2, 4, 8), (STONE, 2, 4, 9),
                                   (TRAP, 1, 5, 9), (ICE, 2, 4, 9)])),
    L(6, [('rows', 12)], 'auto',
      pieces={FROZEN: 8, VOLCANIC: 8, RAINBOW: 6},
      layout=lay(5, 78, blocked=NOTCH)),
    L(6, [('score', 7500), ('special', 4, EXPLOSIVE)], 'auto',
      pieces={EXPLOSIVE: 14, CRYSTAL: 8}, layout=lay(5, 78)),
    L(6, [('multi', 4)], 'auto', pieces={MAGNETIC: 8},
      layout=lay(5, 86, obstacles=[(MOVER, 1, 3, 5)])),
    L(6, [('obstacles', 6), ('rows', 10)], 'auto',
      layout=lay(5, 72, obstacles=[(LOCKED, 2, 4, 9), (CRYSTAL_WALL, 2, 4, 9),
                                   (WOOD, 3, 4, 9)], lock_rows=6)),
    L(6, [('rows', 14)], 'auto',
      pieces={HEAVY: 6, STICKY: 6, MYSTERY: 6, FROZEN: 6},
      layout=lay(5, 78, obstacles=[(UNBREAKABLE, 2, 6, 9)])),
    L(6, [('score', 9000)], 'auto',
      pieces={CRYSTAL: 8, GOLDEN: 6, EXPLOSIVE: 6, VOLCANIC: 6},
      layout=lay(5, 80, blocked=corners(2)), power=False),
    L(6, [('special', 5, MAGNETIC), ('special', 5, RAINBOW), ('rows', 10)],
      'auto', pieces={MAGNETIC: 12, RAINBOW: 12}, layout=lay(5, 78)),
    L(6, [('obstacles', 8), ('multi', 2)], 'auto',
      layout=lay(5, 72, obstacles=[(MOVER, 2, 3, 8), (STONE, 3, 4, 9),
                                   (ICE, 2, 4, 9), (TRAP, 1, 5, 9)],
                 specials=[(FROZEN, 4)])),
    L(6, [('rows', 15), ('score', 10000)], 'auto',
      pieces={EXPLOSIVE: 6, VOLCANIC: 6, MAGNETIC: 6, MYSTERY: 6,
              STICKY: 6},
      layout=lay(6, 80, obstacles=[(MOVER, 1, 3, 6), (CRYSTAL_WALL, 2, 5, 9)],
                 blocked=corners(2))),
]

assert len(LEVELS) == 100, [sum(1 for l in LEVELS if l["world"] == w) for w in range(1, 7)]
