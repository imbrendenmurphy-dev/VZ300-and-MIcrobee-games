"""Wall architecture for each wing, so no two wings look alike (even on a mono screen).

Each style gives: tiles (8 x 12 patterns), the side-wall and ceiling tiles, what
hangs under a platform, and a fill(room, r0..r1, c0..c1, colours) for a wall zone.
Style 'panel' (Docking) is the original bevelled panelling in gen.py.
"""
import math

def P(fn): return [''.join('X' if fn(x, y) else '.' for x in range(8)) for y in range(12)]
def A(*rows): return list(rows) + ['........'] * (12 - len(rows))

TILES = {}
def t(name, rows): TILES[name] = rows

# --- glasshouse (Hydroponics): arched arcade, diamond glazing, mullions, planters, vines
t('gl_d', P(lambda x, y: x == round(y * 7 / 11) or x == 7 - round(y * 7 / 11)))
t('gl_m', P(lambda x, y: x in (3, 4) or (y % 6 == 0 and x in (2, 5))))
t('gl_t', A('XXXXXXXX', 'X......X', '.X....X.', '..X..X..', '..X..X..', '...XX...',
            '...XX...', '...XX...', '...XX...', '...XX...', '...XX...', '...XX...'))
t('gl_b', A('........', '..X..X..', '.XXX.XX.', 'X.X.X.XX', '.X.XXX.X', 'XXXXXXXX',
            'X.X.X.X.', '.X.X.X.X', 'XXXXXXXX'))
t('vine', A('XXXXXXXX', '.X..X.X.', '.X..X.X.', 'XXX.X.XX', '.X.XXX..', '.X..X...',
            '....X...', '...XXX..', '....X...'))
# --- ice (Cryo): blocks in offset courses, frost flecks, rime, icicles
t('ic_a', A('XXXXXXXX', 'X.......', 'X..X....', 'X.....X.', 'X.......', 'XXXXXXXX',
            '....X...', '.X..X...', '....X..X', '....X...', '....X...', 'XXXXXXXX'))
t('ic_t', A('XXXXXXXX', 'XXXXXXXX', 'X.XX.XXX', 'X.X..X.X', '..X..X..', '..X.....',
            '.....X..'))
t('icicle', A('XXXXXXXX', 'XXX.XXX.', '.XX..XX.', '.XX..X..', '..X..X..', '..X.....',
              '..X.....'))
# --- pipework (Reactor): pipe bundles, flanges, risers, chevrons, I-beams
PIPE = ['........', 'XXXXXXXX', '....X...', '........', 'XXXXXXXX', '........',
        '........', 'XXXXXXXX', '..X.....', '........', 'XXXXXXXX', '........']
t('pp_h', PIPE)
t('pp_f', [('X' + r[1:6] + 'X' + r[7]) if i not in (0, 5, 6, 11) else '.XXXXXX.' if i in (0, 11) else r
           for i, r in enumerate(PIPE)])
t('pp_v', ['.X....X.', '.X.X..X.', '.X....X.', '.X..X.X.'] * 3)
t('pp_b', A('XXXXXXXX', '........', 'X...X...', 'XX..XX..', '.XX..XX.', '..XX..XX',
            '...X...X', '........', 'XXXXXXXX'))
t('beam', A('XXXXXXXX', 'XXXXXXXX', '...XX...', '..X..X..', '..X..X..', '...XX...',
            '...XX...', 'XXXXXXXX', 'XXXXXXXX'))
# --- observatory (Zero-G): starfield, hull ribs, portholes, thin struts
STARS = [((1, 2), (5, 7), (3, 10)), ((6, 1), (2, 5)), ((4, 3), (0, 9), (7, 11))]
for k, st in enumerate(STARS):
    t(f'sp_s{k}', P(lambda x, y, st=st: (x, y) in st))
t('sp_rib', P(lambda x, y: x == 1 + round(1.5 * math.sin(math.pi * y / 11)) or x == 3 + round(1.5 * math.sin(math.pi * y / 11))))
def porthole(qx, qy):
    def f(x, y):
        X = x + 8 * qx - 7.5; Y = (y + 12 * qy - 11.5) * 0.75
        d = math.hypot(X, Y)
        return 6.3 <= d <= 7.6 or (d < 6 and (x * 7 + y * 3 + qx * 5 + qy * 11) % 23 == 0)
    return P(f)
for qy in (0, 1):
    for qx in (0, 1):
        t(f'sp_p{qy}{qx}', porthole(qx, qy))
t('strut', A('XXXXXXXX', 'X......X', '.X....X.', '..X..X..', '...XX...', '...XX...',
             '..X..X..', '.X....X.', 'X......X'))
# --- circuitry (Core): traces with pads, bus lines, chips, data stream, grid
t('ct_h', A('........', '........', 'XXXX....', '...X....', '...XXXXX', '........',
            '.XX.....', '.XX.XXXX', '........', 'XXXXX...', '....X...', '....XXXX'))
t('ct_v', ['.X.X.X..'] * 12)
t('ct_c', A('..X.....', '..X.....', '..XXXX..', '.....X..', '.XX..X..', '.XX..XXX',
            '.........'[:8], 'XXX.....', '..X.....', '..X..XX.', '..XXXXX.', '.....XX.'))
t('chip_l', A('.X.X.X.X', 'XXXXXXXX', 'X.......', 'X.XX....', 'X.......', 'X.......',
              'X.......', 'X.......', 'XXXXXXXX', '.X.X.X.X'))
t('chip_r', A('.X.X.X..', 'XXXXXXX.', '......X.', '......X.', '......X.', '..XX..X.',
              '......X.', '......X.', 'XXXXXXX.', '.X.X.X..'))
t('ct_b', A('........', '........', 'XX.XXX.X', '........', '.XXX.XX.', '........',
            'XXXXXXXX'))
t('grid', A('X...X...', 'XXXXXXXX', 'X...X...', 'X...X...', 'XXXXXXXX', 'X...X...',
            'X...X...', 'XXXXXXXX'))

# side wall, ceiling, under-platform tile for each style
FRAME = {
    'panel':   ('wall', 'hull', 'truss'),
    'glass':   ('gl_m', 'gl_t', 'vine'),
    'ice':     ('ic_a', 'ic_t', 'icicle'),
    'pipes':   ('pp_v', 'pp_h', 'beam'),
    'space':   ('sp_rib', 'sp_s1', 'strut'),
    'circuit': ('ct_v', 'ct_h', 'grid'),
}

def fill(style, room, z0, z1, light, dim, neon, rng):
    """Fill wall zone rows z0..z1, columns 2..39 (not walkways) in a style."""
    def put(r, c, n, ink): room.put(r, c, n, ink)
    h = z1 - z0 + 1
    if style == 'glass':
        for r in range(z0, z1 + 1):
            for c in range(2, 40):
                if r == z0: put(r, c, 'gl_t', light)
                elif r == z1: put(r, c, 'gl_b', neon)
                elif (c - 2) % 6 == 0: put(r, c, 'gl_m', dim)
                else: put(r, c, 'gl_d', dim)
    elif style == 'ice':
        for r in range(z0, z1 + 1):
            for c in range(2, 40):
                if r == z0: put(r, c, 'ic_t', light)
                else: put(r, c, 'ic_a', neon if r == z1 else dim)
    elif style == 'pipes':
        risers = {c for c in range(2, 40) if (c * 7 + z0) % 11 == 0}
        for r in range(z0, z1 + 1):
            for c in range(2, 40):
                if r == z1: put(r, c, 'pp_b', neon)
                elif c in risers: put(r, c, 'pp_v', light)
                elif (c - 2) % 5 == 4: put(r, c, 'pp_f', light if r == z0 else dim)
                else: put(r, c, 'pp_h', light if r == z0 else dim)
    elif style == 'space':
        for r in range(z0, z1 + 1):
            for c in range(2, 40):
                if (c - 2) % 9 == 0: put(r, c, 'sp_rib', dim)
                elif rng.random() < 0.3: put(r, c, 'empty', 0)
                else: put(r, c, f'sp_s{rng.randint(0, 2)}', light if rng.random() < 0.7 else neon)
        if h >= 2:                                   # a porthole or two
            for _ in range(rng.randint(1, 2)):
                c = rng.randint(4, 36)
                if any((c + k - 2) % 9 == 0 for k in (0, 1)): continue
                rr = rng.randint(z0, z1 - 1)
                for qy in (0, 1):
                    for qx in (0, 1): put(rr + qy, c + qx, f'sp_p{qy}{qx}', neon)
    elif style == 'circuit':
        buses = {c for c in range(2, 40) if c % 7 == 3}
        for r in range(z0, z1 + 1):
            for c in range(2, 40):
                if r == z1: put(r, c, 'ct_b', neon)
                elif c in buses: put(r, c, 'ct_v', light)
                else: put(r, c, 'ct_h' if (r + c) % 3 else 'ct_c', dim)
        if h >= 3:
            for _ in range(rng.randint(1, 3)):
                c = rng.randint(3, 37)
                if c in buses or c + 1 in buses: continue
                rr = rng.randint(z0, z1 - 1)
                put(rr, c, 'chip_l', light); put(rr, c + 1, 'chip_r', light)
    else:
        raise ValueError(style)
