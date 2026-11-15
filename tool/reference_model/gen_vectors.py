"""Writes test/fixtures/reference_vectors.json: the Python model's results
for random numbers, layouts, whole bot games (every turn) and power-ups.
test/core/reference_test.dart replays them with the Dart engine and
requires identical results, so the two implementations cannot drift.

    cd tool/reference_model && python3 gen_vectors.py
"""
import json
import os

from core import (CRYSTAL, CRYSTAL_WALL, DEFAULT_WEIGHTS, EXPLOSIVE, FROZEN,
                  GENTLE_WEIGHTS, GOLDEN, HEAVY, ICE, KIND_NAMES, LOCKED,
                  MAGNETIC, MOVER, MYSTERY, PLAYING, RAINBOW, STICKY, STONE,
                  TRAP, UNBREAKABLE, VOLCANIC, WOOD, Config, Rng, best_move,
                  hash_string, layout_text, make_layout, new_game, place,
                  power)
from content import CLASSIC_PALETTE


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))


def state_dict(s):
    return {
        'board': s.board.encode(),
        'tray': [None if p is None else p.code() for p in s.tray],
        'bonus': None if s.bonus is None else s.bonus.code(),
        'rng': s.rng,
        'score': s.score,
        'combo': s.combo,
        'bestCombo': s.best_combo,
        'rows': s.rows,
        'multi': s.multi,
        'bestWave': s.best_wave,
        'moves': s.moves,
        'sets': s.sets,
        'sand': s.sand_cleared,
        'obstacles': s.obstacles,
        'golden': s.golden,
        'perfect': s.perfect,
        'kinds': {str(k): v for k, v in sorted(s.kinds.items())},
        'status': s.status,
        'reason': s.reason,
    }


def cfg_dict(cfg):
    return {
        'seed': cfg.seed,
        'layout': cfg.layout,
        'lockRows': cfg.lock_rows,
        'objectives': [[o[0], o[1], o[2]] for o in cfg.objectives],
        'moveLimit': cfg.move_limit,
        'weights': 'gentle' if cfg.weights is GENTLE_WEIGHTS else 'default',
        'palette': cfg.palette,
        'specials': {str(k): v for k, v in sorted(cfg.specials.items())},
        'schedule': cfg.schedule,
    }


def game_vector(name, cfg, moves=30):
    s = new_game(cfg)
    turns = []
    for _ in range(moves):
        if s.status != PLAYING:
            break
        m = best_move(s, cfg)
        if m is None:
            break
        t = place(s, cfg, *m)
        turns.append({'move': list(m), 'points': t.points, 'rows': t.rows,
                      'phases': [p[0] for p in t.phases],
                      'revealed': t.revealed, 'state': state_dict(s)})
    return {'name': name, 'config': cfg_dict(cfg),
            'start': state_dict(new_game(cfg)), 'turns': turns}


def main():
    out = {}
    rng = Rng(12345)
    out['rng'] = {'seed': 12345, 'u32': [rng.next_u32() for _ in range(8)],
                  'int100': [Rng(99).next_int(100) for _ in range(1)]}
    r = Rng(7)
    out['rng']['int10'] = [r.next_int(10) for _ in range(20)]
    out['hash'] = {s: hash_string(s) for s in
                   ['', 'a', 'sbm-daily-2026-11-15', 'sbm-level-1-0']}

    layouts = []
    params = [
        (1, 3, 78, None, [], [], ()),
        (2, 4, 70, [6, 9, 2], [(STONE, 3, 5, 9)], [(CRYSTAL, 2)], ()),
        (3, 5, 86, None, [(ICE, 2, 4, 9), (WOOD, 2, 4, 9)], [(FROZEN, 4)], ()),
        (4, 4, 72, None, [(TRAP, 2, 5, 9), (LOCKED, 1, 5, 9)],
         [(STICKY, 2)], ()),
        (5, 3, 74, None, [(MOVER, 2, 4, 7), (UNBREAKABLE, 1, 6, 9),
                          (CRYSTAL_WALL, 1, 6, 9)], [(MAGNETIC, 1)],
         (0, 1, 8, 9, 10, 19)),
        (6, 6, 80, CLASSIC_PALETTE, [], [(EXPLOSIVE, 1), (VOLCANIC, 1),
                                          (RAINBOW, 1), (GOLDEN, 1),
                                          (HEAVY, 1)], ()),
    ]
    for seed, fill, dens, pal, obs, spec, blocked in params:
        b = make_layout(seed, fill, dens, pal, obs, spec, blocked, 4)
        layouts.append({
            'seed': seed, 'fill': fill, 'density': dens, 'palette': pal,
            'obstacles': [[o, n, t, bt] for o, n, t, bt in obs],
            'specials': [[k, n] for k, n in spec], 'blocked': list(blocked),
            'lockRows': 4, 'rows': layout_text(b), 'encoded': b.encode()})
    out['layouts'] = layouts

    games = []
    games.append(game_vector('classic', Config(
        mode='classic', seed=2024, palette=CLASSIC_PALETTE,
        schedule='classic'), moves=40))
    games.append(game_vector('endless', Config(
        mode='endless', seed=77, palette=CLASSIC_PALETTE,
        schedule='endless'), moves=40))
    every = {k: 8 for k in (HEAVY, STICKY, EXPLOSIVE, RAINBOW, FROZEN,
                            CRYSTAL, GOLDEN, MAGNETIC, VOLCANIC, MYSTERY)}
    every_layout = layout_text(make_layout(
        31, 5, 80, None,
        [(STONE, 2, 4, 9), (WOOD, 1, 4, 9), (ICE, 1, 4, 9), (LOCKED, 1, 4, 9),
         (UNBREAKABLE, 1, 4, 9), (TRAP, 1, 4, 9), (CRYSTAL_WALL, 1, 4, 9),
         (MOVER, 1, 3, 6)],
        [(FROZEN, 2), (STICKY, 1), (EXPLOSIVE, 1)], (), 3))
    games.append(game_vector('everything', Config(
        mode='level', seed=4242, layout=every_layout, specials=every,
        objectives=[('rows', 40, 0)], move_limit=35), moves=35))
    games.append(game_vector('gentle', Config(
        mode='level', seed=5, weights=GENTLE_WEIGHTS,
        objectives=[('multi', 3, 0)], palette=[6, 9, 2]), moves=25))
    out['games'] = games

    # Power-ups, each applied to the same mid-game position.
    base_cfg = Config(mode='level', seed=99, layout=every_layout,
                      specials=every, objectives=[('rows', 99, 0)])
    s0 = new_game(base_cfg)
    for _ in range(6):
        place(s0, base_cfg, *best_move(s0, base_cfg))
    powers = []
    b0 = s0.board
    colour = next(c.colour for c in b0.cells if c is not None and c.is_sand)
    gap_row = next((r for r in range(9, -1, -1)
                    if 1 <= sum(1 for c in range(10) if b0.cells[r * 10 + c] is None) <= 3),
                   9)
    for kind, arg in [('sweep', 9), ('sweep', 0), ('blast', colour),
                      ('blast', 10), ('shaker', 85), ('rowclear', gap_row),
                      ('rowclear', 0), ('crusher', 95),
                      ('gravity', -1), ('gravity', 1), ('bomb', 84),
                      ('extra', None)]:
        s = s0.copy()
        t = power(s, base_cfg, kind, arg)
        powers.append({'kind': kind, 'arg': arg, 'ok': t is not None,
                       'points': None if t is None else t.points,
                       'state': state_dict(s)})
    out['powers'] = {'config': cfg_dict(base_cfg), 'moves': 6,
                     'before': state_dict(s0), 'results': powers}
    out['kindNames'] = KIND_NAMES

    os.makedirs(os.path.join(ROOT, 'test', 'fixtures'), exist_ok=True)
    with open(os.path.join(ROOT, 'test', 'fixtures', 'reference_vectors.json'),
              'w') as f:
        json.dump(out, f, indent=1)
    print('games', [len(g['turns']) for g in games],
          'powers ok', [p['ok'] for p in powers])


if __name__ == '__main__':
    main()
