"""Sand Burst Magic reference model: board, sand, pieces, clears, scoring,
piece generator, turn engine and the evaluation bot.

This is the *specification* of the game's rules in plain Python. The Dart
code in lib/core/ implements exactly the same rules; tests compare both
(test/fixtures/reference_vectors.json), so neither can silently drift.

Board
-----
10 columns x 10 rows, index i = row * 10 + col, row 0 at the TOP. A cell is
empty (None) or a Cell. A cell is either sand (obstacle == -1) or an
obstacle. The logical grid is authoritative: the app only animates what
this model decides.

Sand
----
Every placed block becomes one cell of sand ("a cluster of grains" on
screen). Settling runs in synchronous steps. In step s, rows are visited
from the second-lowest up to the top, columns left-to-right on even steps
and right-to-left on odd steps. A movable grain

* falls one row if the cell below can be entered;
* otherwise (not heavy, not sticky) slides one cell diagonally down if the
  cell beside it is empty and the cell diagonally below can be entered,
  trying left first when (s + row + col) is even, else right first.

A cell can be entered when it is empty or an open sand trap (the trap
swallows the grain). Frozen sand, sticky sand (while its timer runs) and
grains orthogonally next to active sticky sand do not move. Settling ends
after a step with no moves; every move lowers a grain, so it always ends.

Rows
----
A row is complete when every cell holds sand or an obstacle other than an
open trap. All complete rows clear together ("a wave"); sand above then
settles and may complete more rows (chain waves). See clear_wave().
"""
from __future__ import annotations

from collections import deque

MASK32 = 0xFFFFFFFF
W = 10
H = 10
N = W * H
GREY = 10          # packed sand from a filled trap

# Sand kinds
NORMAL, HEAVY, STICKY, EXPLOSIVE, RAINBOW, FROZEN, CRYSTAL, GOLDEN, \
    MAGNETIC, VOLCANIC, MYSTERY = range(11)
KIND_NAMES = ['normal', 'heavy', 'sticky', 'explosive', 'rainbow', 'frozen',
              'crystal', 'golden', 'magnetic', 'volcanic', 'mystery']
MYSTERY_REVEAL = [HEAVY, EXPLOSIVE, CRYSTAL, GOLDEN, RAINBOW]
STICKY_TTL = 3

# Obstacles
NONE = -1
STONE, WOOD, ICE, LOCKED, UNBREAKABLE, TRAP, CRYSTAL_WALL, MOVER = range(8)
OBSTACLE_NAMES = ['stone', 'wood', 'ice', 'locked', 'unbreakable', 'trap',
                  'crystalWall', 'mover']
OBSTACLE_HP = {STONE: 2, WOOD: 1, ICE: 1, LOCKED: 3, UNBREAKABLE: 0,
               TRAP: 3, CRYSTAL_WALL: 3, MOVER: 1}

ROW_BASE = [0, 100, 250, 450, 700]


# ---------------------------------------------------------------- random

def imul32(a: int, b: int) -> int:
    return (a & MASK32) * (b & MASK32) & MASK32


class Rng:
    """mulberry32: the whole state is one 32-bit integer (persistable)."""

    def __init__(self, seed: int):
        self.state = seed & MASK32

    def next_u32(self) -> int:
        self.state = (self.state + 0x6D2B79F5) & MASK32
        t = self.state
        t = imul32(t ^ (t >> 15), t | 1)
        t = (t ^ ((t + imul32(t ^ (t >> 7), t | 61)) & MASK32)) & MASK32
        return (t ^ (t >> 14)) & MASK32

    def next_int(self, n: int) -> int:
        assert 0 < n <= (1 << 20)
        return (self.next_u32() * n) >> 32


def hash_string(s: str) -> int:
    h = 0x811C9DC5
    for ch in s:
        h ^= ord(ch) & 0xFFFF
        h = imul32(h, 0x01000193)
    return h & MASK32


# ---------------------------------------------------------------- cells

class Cell:
    __slots__ = ('id', 'colour', 'kind', 'obstacle', 'hp', 'ttl')

    def __init__(self, id, colour, kind=NORMAL, obstacle=NONE, hp=0, ttl=0):
        self.id = id
        self.colour = colour
        self.kind = kind
        self.obstacle = obstacle
        self.hp = hp
        self.ttl = ttl

    def copy(self, **kw):
        c = Cell(self.id, self.colour, self.kind, self.obstacle, self.hp, self.ttl)
        for k, v in kw.items():
            setattr(c, k, v)
        return c

    @property
    def is_sand(self):
        return self.obstacle == NONE

    def code(self):
        """Compact text used in reference vectors (no id)."""
        if self.obstacle == NONE:
            return f's{self.colour}k{self.kind}t{self.ttl}'
        return f'o{self.obstacle}h{self.hp}t{self.ttl}'


class Board:
    def __init__(self):
        self.cells = [None] * N
        self.no_place = [False] * N
        self.next_id = 1

    def copy(self):
        b = Board()
        b.cells = list(self.cells)   # cells are treated as immutable
        b.no_place = self.no_place    # never changes during a game
        b.next_id = self.next_id
        return b

    def new_id(self):
        i = self.next_id
        self.next_id += 1
        return i

    def encode(self):
        return ','.join('' if c is None else c.code() for c in self.cells)

    def ids(self):
        return [0 if c is None else c.id for c in self.cells]

    def heights(self):
        hs = []
        for c in range(W):
            h = 0
            for r in range(H):
                if self.cells[r * W + c] is not None:
                    h = H - r
                    break
            hs.append(h)
        return hs

    def holes(self):
        n = 0
        for c in range(W):
            seen = False
            for r in range(H):
                cell = self.cells[r * W + c]
                if cell is not None:
                    seen = True
                elif seen:
                    n += 1
        return n

    def empty_count(self):
        return sum(1 for i in range(N) if self.cells[i] is None and not self.no_place[i])

    def sand_count(self):
        return sum(1 for c in self.cells if c is not None and c.is_sand)


# Layout text: 10 strings of 10 characters.
SAND_SPECIALS = {'h': HEAVY, 'k': STICKY, 'e': EXPLOSIVE, 'r': RAINBOW,
                 'f': FROZEN, 'c': CRYSTAL, 'g': GOLDEN, 'm': MAGNETIC,
                 'v': VOLCANIC}
OBSTACLE_CHARS = {'S': STONE, 'W': WOOD, 'I': ICE, 'L': LOCKED,
                  'U': UNBREAKABLE, 'T': TRAP, 'C': CRYSTAL_WALL, 'M': MOVER,
                  'N': MOVER}


def layout_colour(r, c):
    """Colour of a pre-placed special grain at (r, c) in a layout."""
    return (r + 2 * c) % 10


def board_from_layout(rows, lock_rows=3):
    assert len(rows) == H, rows
    b = Board()
    for r, line in enumerate(rows):
        assert len(line) == W, line
        for c, ch in enumerate(line):
            i = r * W + c
            if ch == '.':
                continue
            if ch == 'x':
                b.no_place[i] = True
            elif ch.isdigit():
                b.cells[i] = Cell(b.new_id(), int(ch))
            elif ch in SAND_SPECIALS:
                k = SAND_SPECIALS[ch]
                b.cells[i] = Cell(b.new_id(), layout_colour(r, c), k,
                                  ttl=STICKY_TTL if k == STICKY else 0)
            elif ch in OBSTACLE_CHARS:
                o = OBSTACLE_CHARS[ch]
                hp = lock_rows if o == LOCKED else OBSTACLE_HP[o]
                ttl = (-1 if ch == 'N' else 1) if o == MOVER else 0
                b.cells[i] = Cell(b.new_id(), 0, NORMAL, o, hp, ttl)
            else:
                raise ValueError(f'bad layout char {ch!r}')
    return b


# ---------------------------------------------------------------- shapes

SHAPES = [
    ('single', [(0, 0)]),
    ('line2', [(0, 0), (0, 1)]),
    ('line2', [(0, 0), (1, 0)]),
    ('line3', [(0, 0), (0, 1), (0, 2)]),
    ('line3', [(0, 0), (1, 0), (2, 0)]),
    ('line4', [(0, 0), (0, 1), (0, 2), (0, 3)]),
    ('line4', [(0, 0), (1, 0), (2, 0), (3, 0)]),
    ('square', [(0, 0), (0, 1), (1, 0), (1, 1)]),
    ('lshape', [(0, 0), (1, 0), (2, 0), (2, 1)]),
    ('lshape', [(0, 0), (0, 1), (0, 2), (1, 0)]),
    ('lshape', [(0, 0), (0, 1), (1, 1), (2, 1)]),
    ('lshape', [(0, 2), (1, 0), (1, 1), (1, 2)]),
    ('jshape', [(0, 1), (1, 1), (2, 0), (2, 1)]),
    ('jshape', [(0, 0), (1, 0), (1, 1), (1, 2)]),
    ('jshape', [(0, 0), (0, 1), (1, 0), (2, 0)]),
    ('jshape', [(0, 0), (0, 1), (0, 2), (1, 2)]),
    ('tshape', [(0, 0), (0, 1), (0, 2), (1, 1)]),
    ('tshape', [(0, 0), (1, 0), (1, 1), (2, 0)]),
    ('tshape', [(0, 1), (1, 0), (1, 1), (1, 2)]),
    ('tshape', [(0, 1), (1, 0), (1, 1), (2, 1)]),
    ('corner', [(0, 0), (0, 1), (1, 0)]),
    ('corner', [(0, 0), (0, 1), (1, 1)]),
    ('corner', [(0, 1), (1, 0), (1, 1)]),
    ('corner', [(0, 0), (1, 0), (1, 1)]),
    ('zigzag', [(0, 0), (0, 1), (1, 1), (1, 2)]),
    ('zigzag', [(0, 1), (1, 0), (1, 1), (2, 0)]),
    ('rzigzag', [(0, 1), (0, 2), (1, 0), (1, 1)]),
    ('rzigzag', [(0, 0), (1, 0), (1, 1), (2, 1)]),
    ('line5', [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)]),
    ('line5', [(0, 0), (1, 0), (2, 0), (3, 0), (4, 0)]),
]

# Default piece weights (index = shape id).
DEFAULT_WEIGHTS = [4, 6, 6, 6, 6, 4, 4, 6,
                   2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
                   3, 3, 3, 3, 3, 3, 3, 3, 2, 2]
# Gentle weights (tutorial and the first levels): small, simple pieces.
GENTLE_WEIGHTS = [6, 8, 8, 8, 8, 4, 4, 6,
                  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
                  3, 3, 3, 3, 1, 1, 1, 1, 0, 0]


def shape_size(sid):
    return len(SHAPES[sid][1])


def can_place(board, sid, r0, c0):
    for dr, dc in SHAPES[sid][1]:
        r, c = r0 + dr, c0 + dc
        if r < 0 or r >= H or c < 0 or c >= W:
            return False
        i = r * W + c
        if board.cells[i] is not None or board.no_place[i]:
            return False
    return True


def fits_anywhere(board, sid):
    for r in range(H):
        for c in range(W):
            if can_place(board, sid, r, c):
                return True
    return False


# ---------------------------------------------------------------- sand

def _enterable(board, i):
    c = board.cells[i]
    return c is None or c.obstacle == TRAP


def _held(board, i):
    r, c = divmod(i, W)
    for nr, nc in ((r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)):
        if 0 <= nr < H and 0 <= nc < W:
            n = board.cells[nr * W + nc]
            if n is not None and n.is_sand and n.kind == STICKY and n.ttl > 0:
                return True
    return False


def movable(board, i):
    c = board.cells[i]
    if c is None or not c.is_sand:
        return False
    if c.kind == FROZEN:
        return False
    if c.kind == STICKY and c.ttl > 0:
        return False
    return not _held(board, i)


def _move(board, frm, to, moves, fills):
    cell = board.cells[frm]
    target = board.cells[to]
    board.cells[frm] = None
    if target is not None and target.obstacle == TRAP:
        hp = target.hp - 1
        moves.append((cell.id, frm, to, 1))
        if hp <= 0:
            nid = board.new_id()
            board.cells[to] = Cell(nid, GREY)
            fills.append((to, nid))
        else:
            board.cells[to] = target.copy(hp=hp)
    else:
        board.cells[to] = cell
        moves.append((cell.id, frm, to, 0))


def settle_step(board, step):
    """One synchronous settling step. Returns (moves, trap_fills); a move is
    (id, from, to, absorbed)."""
    moves, fills = [], []
    cols = range(W) if step % 2 == 0 else range(W - 1, -1, -1)
    for r in range(H - 2, -1, -1):
        for c in cols:
            i = r * W + c
            if not movable(board, i):
                continue
            below = i + W
            if _enterable(board, below):
                _move(board, i, below, moves, fills)
                continue
            kind = board.cells[i].kind
            if kind == HEAVY or kind == STICKY:
                continue
            first = -1 if (step + r + c) % 2 == 0 else 1
            for d in (first, -first):
                nc = c + d
                if nc < 0 or nc >= W:
                    continue
                if board.cells[r * W + nc] is None and _enterable(board, (r + 1) * W + nc):
                    _move(board, i, (r + 1) * W + nc, moves, fills)
                    break
    return moves, fills


def settle(board, max_steps=400):
    """Settles in place. Returns the list of steps (moves, fills)."""
    steps = []
    for s in range(max_steps):
        moves, fills = settle_step(board, s)
        if not moves:
            break
        steps.append((moves, fills))
    return steps


def shift_sideways(board, d, max_steps=400):
    """Gravity Shift power-up: loose grains slide to the left (d = -1) or
    right (d = +1) wall, one cell per step, then settle down normally."""
    steps = []
    for _ in range(max_steps):
        moves, fills = [], []
        cols = range(W) if d < 0 else range(W - 1, -1, -1)
        for r in range(H):
            for c in cols:
                i = r * W + c
                nc = c + d
                if nc < 0 or nc >= W or not movable(board, i):
                    continue
                if _enterable(board, r * W + nc):
                    _move(board, i, r * W + nc, moves, fills)
        if not moves:
            break
        steps.append((moves, fills))
    return steps


# ---------------------------------------------------------------- clears

def full_rows(board):
    out = []
    for r in range(H):
        ok = True
        for c in range(W):
            cell = board.cells[r * W + c]
            if cell is None or cell.obstacle == TRAP:
                ok = False
                break
        if ok:
            out.append(r)
    return out


class Wave:
    """Result of clearing the complete rows once."""

    def __init__(self, rows):
        self.rows = rows
        self.removed = []          # (id, index, colour, kind, obstacle)
        self.damaged = []          # (index, hp)
        self.thawed = []           # indices
        self.sand = 0
        self.obstacles = 0
        self.crystal_walls = 0
        self.kinds = {}            # sand kind -> count removed
        self.blasts = []           # (index, kind) of triggered specials
        self.points = 0


def _hit(board, i, w, queue):
    cell = board.cells[i]
    if cell is None:
        return
    if cell.is_sand:
        board.cells[i] = None
        w.removed.append((cell.id, i, cell.colour, cell.kind, NONE))
        w.sand += 1
        w.kinds[cell.kind] = w.kinds.get(cell.kind, 0) + 1
        if cell.kind in (EXPLOSIVE, VOLCANIC, MAGNETIC):
            queue.append((i, cell.kind, cell.colour))
        return
    o = cell.obstacle
    if o in (STONE, CRYSTAL_WALL):
        hp = cell.hp - 1
        if hp > 0:
            board.cells[i] = cell.copy(hp=hp)
            w.damaged.append((i, hp))
            return
    elif o not in (WOOD, ICE, MOVER):
        return     # locked, unbreakable, trap
    board.cells[i] = None
    w.removed.append((cell.id, i, cell.colour, cell.kind, o))
    w.obstacles += 1
    if o == CRYSTAL_WALL:
        w.crystal_walls += 1


def clear_wave(board, rows):
    w = Wave(rows)
    queue = deque()
    for r in rows:
        for c in range(W):
            _hit(board, r * W + c, w, queue)
    while queue:
        i, kind, colour = queue.popleft()
        w.blasts.append((i, kind))
        r, c = divmod(i, W)
        if kind == EXPLOSIVE:
            targets = [(r + dr, c + dc) for dr in (-1, 0, 1) for dc in (-1, 0, 1)
                       if dr or dc]
        elif kind == VOLCANIC:
            targets = [(r + dr, c) for dr in (-2, -1, 1, 2)]
        else:  # MAGNETIC: same-colour sand within two cells
            targets = []
            for dr in range(-2, 3):
                for dc in range(-2, 3):
                    if not dr and not dc:
                        continue
                    rr, cc = r + dr, c + dc
                    if 0 <= rr < H and 0 <= cc < W:
                        t = board.cells[rr * W + cc]
                        if t is not None and t.is_sand and t.colour == colour:
                            targets.append((rr, cc))
        for rr, cc in targets:
            if 0 <= rr < H and 0 <= cc < W:
                _hit(board, rr * W + cc, w, queue)
    # Next to a cleared row: ice breaks, frozen sand thaws.
    cleared = set(rows)
    for r in rows:
        for rr in (r - 1, r + 1):
            if rr < 0 or rr >= H or rr in cleared:
                continue
            for c in range(W):
                i = rr * W + c
                cell = board.cells[i]
                if cell is None:
                    continue
                if cell.obstacle == ICE:
                    board.cells[i] = None
                    w.removed.append((cell.id, i, cell.colour, cell.kind, ICE))
                    w.obstacles += 1
                elif cell.is_sand and cell.kind == FROZEN:
                    # Thawed grains count as freed frozen sand.
                    board.cells[i] = cell.copy(kind=NORMAL)
                    w.thawed.append(i)
                    w.kinds[FROZEN] = w.kinds.get(FROZEN, 0) + 1
    # Locks open after enough cleared rows.
    for i in range(N):
        cell = board.cells[i]
        if cell is not None and cell.obstacle == LOCKED:
            hp = cell.hp - len(rows)
            if hp <= 0:
                board.cells[i] = None
                w.removed.append((cell.id, i, cell.colour, cell.kind, LOCKED))
                w.obstacles += 1
            else:
                board.cells[i] = cell.copy(hp=hp)
                w.damaged.append((i, hp))
    return w


def row_base(k):
    if k <= 4:
        return ROW_BASE[k]
    return 700 + 300 * (k - 4)


def wave_points(w, combo, index):
    base = row_base(len(w.rows))
    pts = base * (4 + min(combo, 8)) * (2 + min(index, 6)) // 8
    pts += 10 * w.sand + 10 * w.obstacles
    pts += 40 * w.kinds.get(CRYSTAL, 0) + 15 * w.kinds.get(RAINBOW, 0)
    pts += 100 * w.crystal_walls
    return pts


# ---------------------------------------------------------------- config

class Config:
    """Everything that defines a game (mode rules, level)."""

    def __init__(self, mode='classic', seed=1, layout=None, lock_rows=3,
                 objectives=(), move_limit=0, weights=None, palette=None,
                 specials=None, schedule=None, allow_powerups=True):
        self.mode = mode
        self.seed = seed & MASK32
        self.layout = layout
        self.lock_rows = lock_rows
        self.objectives = list(objectives)   # (type, target, kind)
        self.move_limit = move_limit
        self.weights = weights or DEFAULT_WEIGHTS
        self.palette = palette or list(range(10))
        self.specials = specials or {}       # kind -> percent
        self.schedule = schedule             # None, 'classic', 'endless'
        self.allow_powerups = allow_powerups


CLASSIC_STEPS = [  # (min score, {kind: percent})
    (0, {}),
    (1000, {FROZEN: 8}),
    (2500, {FROZEN: 14, STICKY: 4}),
    (5000, {FROZEN: 20, STICKY: 6}),
]
ENDLESS_STEPS = [
    (0, {}),
    (500, {CRYSTAL: 5, GOLDEN: 3}),
    (1500, {CRYSTAL: 5, GOLDEN: 3, EXPLOSIVE: 4, HEAVY: 4}),
    (3000, {CRYSTAL: 5, GOLDEN: 3, EXPLOSIVE: 4, HEAVY: 4, STICKY: 4,
            FROZEN: 10, VOLCANIC: 3}),
    (5000, {CRYSTAL: 5, GOLDEN: 3, EXPLOSIVE: 4, HEAVY: 4, STICKY: 4,
            FROZEN: 16, VOLCANIC: 3, MAGNETIC: 3, RAINBOW: 3, MYSTERY: 3}),
]
KIND_ORDER = [HEAVY, STICKY, EXPLOSIVE, RAINBOW, FROZEN, CRYSTAL, GOLDEN,
              MAGNETIC, VOLCANIC, MYSTERY]


def specials_for(cfg, score):
    if cfg.schedule is None:
        return cfg.specials
    steps = CLASSIC_STEPS if cfg.schedule == 'classic' else ENDLESS_STEPS
    out = {}
    for min_score, table in steps:
        if score >= min_score:
            out = table
    return out


def weights_for(cfg, score, empty):
    w = list(cfg.weights)
    if cfg.schedule is not None and score >= 3000:
        w[28] = w[28] + 2
        w[29] = w[29] + 2
    if empty < 30:
        w = [x * 2 if shape_size(i) <= 3 else x for i, x in enumerate(w)]
    return w


# ---------------------------------------------------------------- state

PLAYING, WON, LOST = 'playing', 'won', 'lost'


class Piece:
    __slots__ = ('shape', 'colour', 'kind')

    def __init__(self, shape, colour, kind=NORMAL):
        self.shape = shape
        self.colour = colour
        self.kind = kind

    def code(self):
        return f'{self.shape}:{self.colour}:{self.kind}'


class State:
    def __init__(self):
        self.board = None
        self.tray = [None, None, None]
        self.bonus = None
        self.rng = 0
        self.score = 0
        self.combo = 0
        self.best_combo = 0
        self.rows = 0
        self.multi = 0           # waves that cleared two or more rows
        self.best_wave = 0       # most rows in one wave
        self.moves = 0
        self.sets = 0
        self.sand_cleared = 0
        self.obstacles = 0
        self.kinds = {}
        self.golden = 0
        self.perfect = 0
        self.bonus_moves = 0
        self.status = PLAYING
        self.reason = ''

    def copy(self):
        s = State()
        s.__dict__.update(self.__dict__)
        s.board = self.board.copy()
        s.tray = list(self.tray)
        s.kinds = dict(self.kinds)
        return s

    def tray_code(self):
        return [None if p is None else p.code() for p in self.tray]


def _pick(rng, weights):
    total = sum(weights)
    x = rng.next_int(total)
    for i, w in enumerate(weights):
        if x < w:
            return i
        x -= w
    return len(weights) - 1


def _pick_kind(rng, table):
    if not table:
        return NORMAL
    x = rng.next_int(100)
    for k in KIND_ORDER:
        p = table.get(k, 0)
        if x < p:
            return k
        x -= p
    return NORMAL


def deal(state, cfg):
    """Deals three new pieces. Uses and advances state.rng."""
    rng = Rng(state.rng)
    board = state.board
    table = specials_for(cfg, state.score)
    weights = weights_for(cfg, state.score, board.empty_count())
    pieces = []
    for _ in range(3):
        sid = _pick(rng, weights)
        colour = cfg.palette[rng.next_int(len(cfg.palette))]
        kind = _pick_kind(rng, table)
        pieces.append(Piece(sid, colour, kind))
    # Fairness: never deal a set in which nothing fits while something
    # could: the first piece becomes the largest shape that fits.
    if not any(fits_anywhere(board, p.shape) for p in pieces):
        order = sorted(range(len(SHAPES)),
                       key=lambda s: (-shape_size(s), s))
        for sid in order:
            if weights[sid] > 0 and fits_anywhere(board, sid):
                pieces[0] = Piece(sid, pieces[0].colour, pieces[0].kind)
                break
    state.rng = rng.state
    state.tray = pieces
    state.sets += 1


def new_game(cfg):
    s = State()
    if cfg.layout:
        s.board = board_from_layout(cfg.layout, cfg.lock_rows)
    else:
        s.board = Board()
    s.rng = cfg.seed
    deal(s, cfg)
    return s


def objective_value(state, obj):
    t, target, kind = obj
    if t == 'rows':
        v = state.rows
    elif t == 'score':
        v = state.score
    elif t == 'multi':
        v = state.multi
    elif t == 'special':
        v = state.kinds.get(kind, 0)
    elif t == 'obstacles':
        v = state.obstacles
    else:
        raise ValueError(t)
    return min(v, target)


def objectives_met(state, cfg):
    return bool(cfg.objectives) and all(
        objective_value(state, o) >= o[1] for o in cfg.objectives)


def any_fits(state):
    for p in state.tray + [state.bonus]:
        if p is not None and fits_anywhere(state.board, p.shape):
            return True
    return False


class Turn:
    def __init__(self):
        self.placed = []      # (id, index)
        self.revealed = None  # kind a mystery piece became
        self.phases = []      # ('settle', steps) | ('wave', Wave) | ('sticky', [idx]) | ('movers', [(id, from, to)])
        self.points = 0
        self.rows = 0
        self.dealt = False


def _resolve(state, cfg, turn, wave_index):
    b = state.board
    while wave_index < 30:
        steps = settle(b)
        if steps:
            turn.phases.append(('settle', steps))
            # A sand trap that swallowed its last grain counts as cleared.
            state.obstacles += sum(len(f) for _, f in steps)
        rows = full_rows(b)
        if not rows:
            break
        w = clear_wave(b, rows)
        w.points = wave_points(w, state.combo, wave_index)
        turn.phases.append(('wave', w))
        turn.points += w.points
        turn.rows += len(rows)
        state.score += w.points
        state.rows += len(rows)
        state.best_wave = max(state.best_wave, len(rows))
        if len(rows) >= 2:
            state.multi += 1
        state.sand_cleared += w.sand
        state.obstacles += w.obstacles
        for k, n in w.kinds.items():
            state.kinds[k] = state.kinds.get(k, 0) + n
        state.golden += w.kinds.get(GOLDEN, 0)
        wave_index += 1
    return wave_index


def end_turn_effects(state, cfg, turn, wave_index):
    b = state.board
    expired = []
    for i in range(N):
        cell = b.cells[i]
        if cell is not None and cell.is_sand and cell.kind == STICKY and cell.ttl > 0:
            ttl = cell.ttl - 1
            b.cells[i] = cell.copy(ttl=ttl, kind=STICKY if ttl > 0 else NORMAL)
            if ttl == 0:
                expired.append(i)
    if expired:
        turn.phases.append(('sticky', expired))
        wave_index = _resolve(state, cfg, turn, wave_index)
    movers = [i for i in range(N)
              if b.cells[i] is not None and b.cells[i].obstacle == MOVER]
    moved = []
    for i in movers:
        cell = b.cells[i]
        if cell is None or cell.obstacle != MOVER:
            continue
        r, c = divmod(i, W)
        d = cell.ttl
        target = None
        for dd in (d, -d):
            nc = c + dd
            if 0 <= nc < W and b.cells[r * W + nc] is None:
                target = (r * W + nc, dd)
                break
        if target is None:
            b.cells[i] = cell.copy(ttl=-d)
            continue
        t, dd = target
        b.cells[i] = None
        b.cells[t] = cell.copy(ttl=dd)
        moved.append((cell.id, i, t))
    if moved:
        turn.phases.append(('movers', moved))
        wave_index = _resolve(state, cfg, turn, wave_index)
    return wave_index


def finish_turn(state, cfg, turn):
    """Combo, perfect clear, status. Shared by placements and power-ups."""
    if turn.rows > 0:
        state.combo += 1
        state.best_combo = max(state.best_combo, state.combo)
        if state.board.sand_count() == 0:
            state.score += 1000
            turn.points += 1000
            state.perfect += 1
    else:
        state.combo = 0


def update_status(state, cfg):
    if objectives_met(state, cfg):
        state.status, state.reason = WON, 'objectives'
    elif cfg.move_limit > 0 and state.moves >= cfg.move_limit + state.bonus_moves:
        state.status, state.reason = LOST, 'moves'
    elif not any_fits(state):
        state.status, state.reason = LOST, 'space'


def place(state, cfg, slot, r0, c0):
    """Plays one piece. Mutates state; returns a Turn (or None if illegal).
    Slot 3 is the bonus piece (Extra Move power-up)."""
    if state.status != PLAYING:
        return None
    piece = state.bonus if slot == 3 else state.tray[slot]
    if piece is None or not can_place(state.board, piece.shape, r0, c0):
        return None
    b = state.board
    turn = Turn()
    kind = piece.kind
    if kind == MYSTERY:
        rng = Rng(state.rng)
        kind = MYSTERY_REVEAL[rng.next_int(len(MYSTERY_REVEAL))]
        state.rng = rng.state
        turn.revealed = kind
    for dr, dc in SHAPES[piece.shape][1]:
        i = (r0 + dr) * W + (c0 + dc)
        cid = b.new_id()
        b.cells[i] = Cell(cid, piece.colour, kind,
                          ttl=STICKY_TTL if kind == STICKY else 0)
        turn.placed.append((cid, i))
    n = len(turn.placed)
    state.score += n
    turn.points += n
    if slot == 3:
        state.bonus = None
    else:
        state.tray[slot] = None
    wave_index = _resolve(state, cfg, turn, 0)
    end_turn_effects(state, cfg, turn, wave_index)
    finish_turn(state, cfg, turn)
    state.moves += 1
    if all(p is None for p in state.tray):
        deal(state, cfg)
        turn.dealt = True
    update_status(state, cfg)
    return turn


# ---------------------------------------------------------------- power-ups

def _remove_cells(state, cfg, indices, turn, scored=True):
    """Removes cells (power-ups): sand and breakable obstacles go,
    unbreakable/locked/trap stay. Counts towards stats like a clear but
    scores only 10 per cell."""
    b = state.board
    w = Wave([])
    for i in indices:
        cell = b.cells[i]
        if cell is None:
            continue
        if not cell.is_sand and cell.obstacle in (UNBREAKABLE, LOCKED, TRAP):
            continue
        b.cells[i] = None
        w.removed.append((cell.id, i, cell.colour, cell.kind, cell.obstacle))
        if cell.is_sand:
            w.sand += 1
            w.kinds[cell.kind] = w.kinds.get(cell.kind, 0) + 1
        else:
            w.obstacles += 1
    w.points = 10 * (w.sand + w.obstacles) if scored else 0
    state.score += w.points
    turn.points += w.points
    state.sand_cleared += w.sand
    state.obstacles += w.obstacles
    for k, n in w.kinds.items():
        state.kinds[k] = state.kinds.get(k, 0) + n
    state.golden += w.kinds.get(GOLDEN, 0)
    turn.phases.append(('blast', w))
    return w


def power(state, cfg, kind, arg):
    """Applies a power-up. kind/arg:
      sweep   row            removes every cell of the row
      blast   colour         removes all sand of that colour (and rainbow)
      shaker  index          shuffles loose sand in the 3x3 area (rng)
      rowclear row           fills the row's gaps with grey sand if at most
                             3 are missing (it then clears normally)
      crusher index          removes the same-colour sand group (max 12)
      gravity -1|+1          sand slides to the left/right wall, then down
      bomb    index          removes the 3x3 area
      extra   None           a bonus single block (and +1 move limit)
    Returns a Turn, or None if it cannot be used there."""
    if state.status != PLAYING and kind != 'continue':
        return None
    b = state.board
    turn = Turn()
    if kind == 'sweep':
        idx = [arg * W + c for c in range(W)]
        if all(b.cells[i] is None for i in idx):
            return None
        _remove_cells(state, cfg, idx, turn)
    elif kind == 'blast':
        idx = [i for i in range(N) if b.cells[i] is not None and b.cells[i].is_sand
               and (b.cells[i].colour == arg or b.cells[i].kind == RAINBOW)]
        if not idx:
            return None
        _remove_cells(state, cfg, idx, turn)
    elif kind == 'bomb':
        r, c = divmod(arg, W)
        idx = [(r + dr) * W + (c + dc) for dr in (-1, 0, 1) for dc in (-1, 0, 1)
               if 0 <= r + dr < H and 0 <= c + dc < W]
        if all(b.cells[i] is None for i in idx):
            return None
        _remove_cells(state, cfg, idx, turn)
    elif kind == 'crusher':
        cell = b.cells[arg]
        if cell is None or not cell.is_sand:
            return None
        group, seen, q = [], {arg}, deque([arg])
        while q and len(group) < 12:
            i = q.popleft()
            group.append(i)
            r, c = divmod(i, W)
            for nr, nc in ((r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)):
                j = nr * W + nc
                if 0 <= nr < H and 0 <= nc < W and j not in seen:
                    t = b.cells[j]
                    if t is not None and t.is_sand and t.colour == cell.colour:
                        seen.add(j)
                        q.append(j)
        _remove_cells(state, cfg, group, turn)
    elif kind == 'shaker':
        r, c = divmod(arg, W)
        idx = [(r + dr) * W + (c + dc) for dr in (-1, 0, 1) for dc in (-1, 0, 1)
               if 0 <= r + dr < H and 0 <= c + dc < W]
        loose = [i for i in idx if movable(b, i)]
        if len(loose) < 2:
            return None
        cells = [b.cells[i] for i in loose]
        rng = Rng(state.rng)
        for k in range(len(cells) - 1, 0, -1):
            j = rng.next_int(k + 1)
            cells[k], cells[j] = cells[j], cells[k]
        state.rng = rng.state
        for i, cell in zip(loose, cells):
            b.cells[i] = cell
        turn.phases.append(('shuffle', loose))
    elif kind == 'rowclear':
        idx = [arg * W + c for c in range(W)]
        gaps = [i for i in idx if b.cells[i] is None]
        if not gaps or len(gaps) > 3:
            return None
        if any(b.cells[i] is not None and b.cells[i].obstacle == TRAP for i in idx):
            return None
        filled = []
        for i in gaps:
            nid = b.new_id()
            b.cells[i] = Cell(nid, GREY, FROZEN)
            filled.append((nid, i))
        turn.phases.append(('fill', filled))
    elif kind == 'gravity':
        steps = shift_sideways(b, arg)
        if not steps:
            return None
        turn.phases.append(('settle', steps))
        state.obstacles += sum(len(f) for _, f in steps)
    elif kind == 'continue':
        # Rewarded "Keep playing?": the bottom three rows are removed and a
        # fresh set of pieces is dealt. Only after a game ended for space.
        if state.status != LOST or state.reason != 'space':
            return None
        state.status, state.reason = PLAYING, ''
        idx = [r * W + c for r in range(H - 3, H) for c in range(W)]
        _remove_cells(state, cfg, idx, turn, scored=False)
        deal(state, cfg)
        turn.dealt = True
    elif kind == 'extra':
        if state.bonus is not None:
            return None
        state.bonus = Piece(0, cfg.palette[0], NORMAL)
        if cfg.move_limit > 0:
            state.bonus_moves += 1
        update_status(state, cfg)
        return turn
    else:
        raise ValueError(kind)
    wave_index = _resolve(state, cfg, turn, 0)
    # Grey frozen fill from Row Clear must not stay stuck if its row did not
    # clear (it always does: the row is complete by construction).
    finish_turn(state, cfg, turn)
    update_status(state, cfg)
    return turn


# ---------------------------------------------------------------- bot

def _placements(state):
    """Candidate placements for the bot: for each piece and column, the
    highest and the lowest valid row."""
    out = []
    slots = [(s, p) for s, p in enumerate(state.tray) if p is not None]
    if state.bonus is not None:
        slots.append((3, state.bonus))
    for slot, p in slots:
        for c0 in range(W):
            rows = [r0 for r0 in range(H) if can_place(state.board, p.shape, r0, c0)]
            if not rows:
                continue
            out.append((slot, rows[0], c0))
            if rows[-1] != rows[0]:
                out.append((slot, rows[-1], c0))
    return out


def evaluate(state, cfg):
    if state.status == WON:
        return 10_000_000 - state.moves * 1000
    if state.status == LOST:
        return -10_000_000
    v = 0
    for o in cfg.objectives:
        v += objective_value(state, o) * 1000 // o[1] * 20
    hs = state.board.heights()
    v -= max(hs) * 40 + sum(hs) * 4 + state.board.holes() * 60
    v += state.score // 4
    if any(o[0] == 'multi' for o in cfg.objectives):
        # Build nearly full rows so one piece can finish two at once.
        b = state.board
        for r in range(H):
            f = 0
            for c in range(W):
                cell = b.cells[r * W + c]
                if cell is not None and cell.obstacle != TRAP:
                    f += 1
            v += f * f * 2
    return v


def best_move(state, cfg):
    best, best_v = None, None
    for slot, r0, c0 in _placements(state):
        s2 = state.copy()
        place(s2, cfg, slot, r0, c0)
        v = evaluate(s2, cfg)
        if best_v is None or v > best_v:
            best, best_v = (slot, r0, c0), v
    return best


def play_bot(cfg, max_moves=200):
    s = new_game(cfg)
    log = []
    while s.status == PLAYING and s.moves < max_moves:
        m = best_move(s, cfg)
        if m is None:
            break
        place(s, cfg, *m)
        log.append(m)
    return s, log


# ---------------------------------------------------------------- layouts

OBSTACLE_LETTER = {STONE: 'S', WOOD: 'W', ICE: 'I', LOCKED: 'L',
                   UNBREAKABLE: 'U', TRAP: 'T', CRYSTAL_WALL: 'C'}
SPECIAL_LETTER = {v: k for k, v in SAND_SPECIALS.items()}


def layout_text(board):
    """The board as 10 layout strings (inverse of board_from_layout for
    settled boards: special grains get their layout colour)."""
    rows = []
    for r in range(H):
        line = ''
        for c in range(W):
            i = r * W + c
            cell = board.cells[i]
            if board.no_place[i]:
                line += 'x'
            elif cell is None:
                line += '.'
            elif cell.is_sand:
                if cell.kind == NORMAL:
                    line += str(cell.colour % 10)
                else:
                    line += SPECIAL_LETTER[cell.kind]
            elif cell.obstacle == MOVER:
                line += 'M' if cell.ttl > 0 else 'N'
            else:
                line += OBSTACLE_LETTER[cell.obstacle]
        rows.append(line)
    return rows


def make_layout(seed, fill, density=78, palette=None, obstacles=(),
                specials=(), blocked=(), lock_rows=3):
    """A random settled starting board, made only with Rng so the Dart
    code reproduces it exactly (the Daily Puzzle uses it).

    fill       rows of sand poured in from the bottom (0-7)
    density    percent chance a cell of those rows gets a grain
    obstacles  [(obstacle, count, top_row, bottom_row)] placed first, at
               random empty cells of rows top_row..bottom_row
    specials   [(kind, count)] random grains changed to that kind
    blocked    indices that are not part of the board ('x')
    """
    palette = palette or list(range(10))
    rng = Rng(seed)
    b = Board()
    for i in blocked:
        b.no_place[i] = True
    for o, count, top, bottom in obstacles:
        for _ in range(count):
            for _try in range(40):
                r = top + rng.next_int(bottom - top + 1)
                c = rng.next_int(W)
                i = r * W + c
                if b.cells[i] is None and not b.no_place[i]:
                    hp = lock_rows if o == LOCKED else OBSTACLE_HP[o]
                    ttl = (1 if rng.next_int(2) == 0 else -1) if o == MOVER else 0
                    b.cells[i] = Cell(b.new_id(), 0, NORMAL, o, hp, ttl)
                    break
    for r in range(H - 1, H - 1 - fill, -1):
        for c in range(W):
            i = r * W + c
            if b.cells[i] is None and not b.no_place[i] and rng.next_int(100) < density:
                b.cells[i] = Cell(b.new_id(), palette[rng.next_int(len(palette))])
    settle(b)
    # No row may start complete: take one grain out of each full row.
    for _ in range(N):
        rows = full_rows(b)
        if not rows:
            break
        for r in rows:
            sand = [r * W + c for c in range(W)
                    if b.cells[r * W + c] is not None and b.cells[r * W + c].is_sand]
            if sand:
                b.cells[sand[rng.next_int(len(sand))]] = None
        settle(b)
    if full_rows(b):
        # rows made only of obstacles: open one cell
        for r in full_rows(b):
            b.cells[r * W + rng.next_int(W)] = None
        settle(b)
    for k, count in specials:
        for _ in range(count):
            plain = [i for i in range(N) if b.cells[i] is not None
                     and b.cells[i].is_sand and b.cells[i].kind == NORMAL]
            if not plain:
                break
            i = plain[rng.next_int(len(plain))]
            r, c = divmod(i, W)
            b.cells[i] = b.cells[i].copy(kind=k, colour=layout_colour(r, c),
                                         ttl=STICKY_TTL if k == STICKY else 0)
    return b
