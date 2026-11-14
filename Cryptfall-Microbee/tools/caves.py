"""Compile caves/*.txt into build/CAVES.DAT (VIBED BY BPM 2026).

The game reads the number of caves from the file and loads one at a time,
so adding a crypt is adding a text file here and rebuilding: no game code
changes.  Files are taken in name order.  (Most of the crypts in caves/ are
written out by tools/paint.py from the designs in tools/crypts/, but the
text file is what gets compiled and it can be edited by hand.)

    name:  THE FIRST GRAVE            (up to 24 characters)
    hint:  DIG FOR GEMS...            (up to 40; shown as the crypt opens)
    quota: 8        gems needed to open the gate (up to 255)
    time:  120      seconds
    gem:   10 20    points a gem, and points a gem once the gate is open
                    (rubies count double, emeralds triple)
    magic: 20       seconds the enchanted grate stays awake
    slow:  40       seconds before the slime starts to spread fast
    slmax: 60       slime cells at which it turns to stone
    bonus: 1        a bonus room (failing it costs no life)
    theme: dirt1=BROWN wall1=RED block2=BLUE ...     the cave's colours
    ; solve: ...    the crypt's solution for the tests (see tools/bot.py)
    map:
    ####...         25-64 wide, 15-32 high, steel (# or %) all round

    .  ,  :  ;   the four earths            W  V  A   brick, cobble, colonnade (rounded)
    B  N  H      stone blocks (flat)        #  %      steel (nothing breaks it)
    o  boulder   q  slab (never rolls)      u  urn (breaks open on a gem)   T  powder keg
    *  gem       r  ruby                    e  emerald
    c  cracked wall     m  enchanted grate  s  slime        D  locked door   y  key
    g  ghost     b  bat     k K  knight (across, up and down)     z  skull (hunts Mort)
    $  chalice   C  crown   +  ward         h  hourglass    v  heart
    P  Mort's way in    X  the gate    (space) empty
"""
import os
import sys
import glob

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import tiles as TL

COL = dict(BLACK=0, RED=1, GREEN=2, BROWN=3, BLUE=4, MAGENTA=5, CYAN=6, GREY=7, DGREY=8, BRED=9, BGREEN=10,
           YELLOW=11, BBLUE=12, BMAGENTA=13, BCYAN=14, WHITE=15)
CH = TL.CH
MAXW, MAXH, MINW, MINH = 64, 32, 25, 15
# pictures a tile can turn into, which the cave must then carry too
IMPLIES = {'BAT': ['GEM'], 'URN': ['GEM'], 'SLIME': ['GEM', 'BOULDER'], 'MAGIC': ['GEM', 'BOULDER']}


def parse(path):
    c = dict(name='', hint='', quota=0, time=120, gem=(10, 20), magic=20, slow=40, slmax=80, bonus=0, theme={}, rows=[])
    inmap = False
    for line in open(path).read().split('\n'):
        if inmap:
            if line.strip('\r') != '' or c['rows']:
                c['rows'].append(line.rstrip('\r'))
            continue
        if not line.strip() or line.lstrip().startswith(';'):
            continue
        k, _, v = line.partition(':')
        k, v = k.strip().lower(), v.strip()
        if k == 'map':
            inmap = True
        elif k in ('name', 'hint'):
            c[k] = v.upper()
        elif k == 'gem':
            a = v.split()
            c['gem'] = (int(a[0]), int(a[1]) if len(a) > 1 else int(a[0]))
        elif k == 'theme':
            for kv in v.split():
                a, b = kv.split('=')
                c['theme'][a.lower()] = COL[b.upper()]
        elif k in c:
            c[k] = int(v)
        else:
            raise SystemExit('%s: unknown setting %r' % (path, k))
    while c['rows'] and not c['rows'][-1].strip():
        c['rows'].pop()
    return c


def check(c, path):
    rows = c['rows']
    h = len(rows)
    w = max(len(r) for r in rows)

    def err(m):
        raise SystemExit('%s: %s' % (os.path.basename(path), m))
    if not (MINW <= w <= MAXW and MINH <= h <= MAXH):
        err('the map must be %d-%d wide and %d-%d high, to scroll both ways (it is %d x %d)' % (MINW, MAXW, MINH, MAXH, w, h))
    rows = [r.ljust(w) for r in rows]
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch not in CH:
                err('row %d column %d: unknown character %r' % (y + 1, x + 1, ch))
            if (y in (0, h - 1) or x in (0, w - 1)) and ch not in '#%X':
                err('row %d column %d: the border must be steel' % (y + 1, x + 1))
    flat = ''.join(rows)
    if flat.count('P') != 1 or flat.count('X') != 1:
        err('needs exactly one P and one X')
    if len(c['name']) > 24 or len(c['hint']) > 40:
        err('name (24) or hint (40) too long')
    if not c['name']:
        err('no name')
    if not 0 <= c['quota'] <= 255:
        err('quota 0-255')
    # the pictures it needs
    arts = list(TL.ALWAYS)
    for ch in sorted(set(flat)):
        n, _, art, _ = TL.TILES[CH[ch]]
        for a in [art] + IMPLIES.get(art, []):
            if a and a not in arts:
                arts.append(a)
    if len(arts) > TL.MAX_SLOTS:
        err('uses %d different pictures; a cave can carry %d' % (len(arts), TL.MAX_SLOTS))
    for k in c['theme']:
        if k not in TL.THEME:
            err('theme: unknown name %r' % k)
    c['w'], c['h'], c['rows'], c['arts'] = w, h, rows, arts
    c['gems'] = sum(flat.count(x) for x in '*re')
    return c


def record(c):
    r = bytearray(256 + 32 * 64)
    r[0], r[1], r[2] = c['w'], c['h'], c['quota']
    r[3:5] = c['time'].to_bytes(2, 'little')
    r[5] = int(str(c['gem'][0] // 10), 16)
    r[6] = int(str(c['gem'][1] // 10), 16)
    r[7], r[8], r[9], r[10] = c['magic'], c['slow'], c['bonus'], c['slmax']
    sl = bytes(TL.ART[a] for a in c['arts']) + b'\xff'
    r[16:16 + len(sl)] = sl
    th = bytearray()
    for k, col in c['theme'].items():
        n = TL.THEME[k]
        for t in [n] + TL.THEME_ALSO.get(n, []):
            th += bytes([TL.T[t], col])
    th.append(0xFF)
    assert len(th) <= 80
    r[48:48 + len(th)] = th
    r[128:152] = c['name'].ljust(24).encode('ascii')
    r[152:192] = c['hint'].ljust(40).encode('ascii')
    for y in range(c['h']):
        for x in range(c['w']):
            r[256 + y * 64 + x] = CH[c['rows'][y][x]]
    return bytes(r)


def load_all(src=None):
    out = []
    for p in sorted(glob.glob(os.path.join(src or os.path.join(ROOT, 'caves'), '*.txt'))):
        out.append((p, check(parse(p), p)))
    return out


def build(quiet=False, src=None, out=None):
    caves = load_all(src)
    head = bytearray(128)
    head[0:16] = b'CRYPTFALL-CAVES2'
    head[16:18] = len(caves).to_bytes(2, 'little')
    data = bytes(head) + b''.join(record(c) for _, c in caves)
    open(out or os.path.join(ROOT, 'build', 'CAVES.DAT'), 'wb').write(data)
    if not quiet:
        print('caves: %d (%d bytes)' % (len(caves), len(data)))
        for i, (p, c) in enumerate(caves):
            print('  %2d %-24s %2dx%2d  gems %3d need %3d  time %3d  pictures %2d%s' % (
                i + 1, c['name'], c['w'], c['h'], c['gems'], c['quota'], c['time'], len(c['arts']), '  BONUS' if c['bonus'] else ''))
    return caves


if __name__ == '__main__':
    build()
