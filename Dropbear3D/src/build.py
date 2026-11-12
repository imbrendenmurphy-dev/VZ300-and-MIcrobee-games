"""Builds DROPBEAR.VZ: generates tables, art and the world, assembles, packs.

Memory plan
  $8000-$80FF  loader stub (unpacks the three blobs below, then starts the game)
  $8100-$F7FF  main RAM: engine tables, compiled scalers, some sprites, text, world, code
  $F800-$FFFF  work areas (map, texture column, depth buffer, sprite list, view buffer)
  $4000-$67FF  BennVenn SRAM bank 1 (mapper value 1): active textures and most sprites
  $4000-$67FF  BennVenn SRAM bank 3 (mapper value 3): saved area states and the texture library
"""
import math, pickle, sys
from z80tools import assemble, Z80

VIEWH = 48; NA = 1024; K = 42; DMIN = 0.25; WALL = 74.0
CLOCK = 3546900
mem = bytearray(65536); b1 = bytearray(0x2800); b3 = bytearray(0x2800); syms = {}
arena = {'main': [0x8100, 0xF800], 'b1': [0x4000, 0x6800], 'b3': [0x4000, 0x6800]}
used = {k: v[0] for k, v in arena.items()}

def blob(name, data, align=1, where='main'):
    p = used[where]; p = (p+align-1)//align*align
    assert p+len(data) <= arena[where][1], 'out of room in %s for %s (%d bytes)' % (where, name, len(data))
    if where == 'main': mem[p:p+len(data)] = bytes(data)
    elif where == 'b1': b1[p-0x4000:p-0x4000+len(data)] = bytes(data)
    else: b3[p-0x4000:p-0x4000+len(data)] = bytes(data)
    used[where] = p+len(data)
    if name: syms[name] = p
    return p
def art(name, data, align=1):
    """Art goes in SRAM bank 1 while it fits, otherwise main RAM."""
    try: return blob(name, data, align, 'b1')
    except AssertionError: return blob(name, data, align, 'main')

syms.update(MAP=0xF800, TEXBUF=0xF900, ZBUF=0xF920, VIS=0xF940, BUF=0xFA00)

# ---- trig, folded to one quadrant ------------------------------------------------------
act = []; dxl = []; dxh = []
for i in range(256):
    th = 2*math.pi*(i+0.5)/NA
    c = math.cos(th); act.append(min(255, int(round(c*256))))
    d = min(32767, int(round(256/c))); dxl.append(d & 255); dxh.append(d >> 8)
blob('ACT', act, 256); blob('DXLO', dxl+dxh, 256)
logd = [max(0, min(255, int(round(K*math.log2(max(i, 16)/64/DMIN))))) for i in range(1024)]
blob('LOGD', logd, 256)
HEIGHTS = list(range(1, 49)) + [52, 56, 60, 64, 72, 80, 88, 96, 112, 128, 144, 160, 192, 224, 256]
NH = len(HEIGHTS)
hitab = [min(range(NH), key=lambda k: abs(HEIGHTS[k]-WALL/(DMIN*2**(v/K)))) for v in range(256)]
blob('HITAB', hitab, 256)
def hidx_for_dist(d): return min(range(NH), key=lambda k: abs(HEIGHTS[k]-WALL/d))

def px(b, i): return (b >> (6-2*i)) & 3
def pack4(p): return p[0] << 6 | p[1] << 4 | p[2] << 2 | p[3]
blob('MIR', [pack4([px(b, 3), px(b, 2), px(b, 1), px(b, 0)]) for b in range(256)], 256)
blob('DARK', [pack4([px(b, i) if i % 2 == 0 else 2 for i in range(4)]) for b in range(256)], 256)

# ---- textures: 16 columns x 16 rows, each texel one screen byte -------------------------
def solid(c): return c*0x55
def dith(a, b): return a << 6 | b << 4 | a << 2 | b
def px4(a, b, c, d): return a << 6 | b << 4 | c << 2 | d
def blank(v): return [[v]*16 for _ in range(16)]
def h(u, v, m): return (u*7 + v*13 + (u*v) % 5) % m
def t_brick():
    t = blank(solid(3))
    for u in range(16):
        for v in range(16):
            if v % 4 == 3: t[u][v] = solid(1)
            elif (u + (4 if (v//4) % 2 else 0)) % 8 == 7: t[u][v] = px4(3, 3, 3, 1)
            elif h(u, v, 9) == 0: t[u][v] = px4(3, 2, 3, 3)
    return t
def t_crate():
    t = blank(solid(1))
    for u in range(16):
        for v in range(16):
            if u in (0, 15) or v in (0, 15) or u == v or u == 15-v: t[u][v] = solid(3)
            elif u in (1, 14) or v in (1, 14): t[u][v] = dith(3, 1)
    return t
def t_iron():
    t = blank(0)
    for u in range(16):
        for v in range(16):
            t[u][v] = px4(0, 0, 2, 0) if u % 2 else px4(2, 0, 0, 0)
            if v in (1, 14) and u % 4 == 1: t[u][v] = solid(3)
            if v in (0, 15): t[u][v] = solid(2)
    return t
def t_hedge():
    t = blank(solid(0))
    for u in range(16):
        for v in range(16):
            r = h(u, v, 11)
            if r < 2: t[u][v] = px4(0, 1, 0, 0) if r else px4(0, 0, 1, 0)
            elif r < 5: t[u][v] = px4(2, 0, 0, 2) if r % 2 else px4(0, 2, 0, 0)
            if v == 15: t[u][v] = dith(0, 2)
    return t
def t_bark():
    t = blank(solid(1))
    for u in range(16):
        for v in range(16):
            if (u + v//6) % 4 == 0: t[u][v] = solid(3)
            elif (u + v//6) % 4 == 2: t[u][v] = dith(1, 3)
            if h(u, v, 13) == 0: t[u][v] = solid(0)
    return t
def t_cliff():
    t = blank(dith(2, 3))
    for u in range(16):
        for v in range(16):
            if (u + v) % 7 == 0 or (u - v) % 11 == 0: t[u][v] = solid(2)
            elif h(u, v, 7) == 0: t[u][v] = solid(3)
    return t
def t_minerock():
    t = blank(dith(2, 3))
    for u in range(16):
        for v in range(16):
            if (v + u//3) % 6 == 0: t[u][v] = solid(2)
            elif h(u, v, 9) == 0: t[u][v] = px4(3, 3, 2, 3)
    return t
def t_timber():
    t = blank(solid(1))
    for u in range(16):
        for v in range(16):
            if v % 4 == 3: t[u][v] = solid(3)
            elif u in (0, 1, 14, 15): t[u][v] = dith(3, 1) if u in (1, 14) else solid(3)
            elif h(u, v, 6) == 0: t[u][v] = px4(1, 3, 1, 1)
    return t
def t_ore():
    t = t_minerock()
    for u, v in ((3, 4), (4, 4), (10, 9), (11, 9), (6, 12), (12, 2), (2, 11)):
        t[u][v] = px4(2, 1, 1, 2); t[u][v+1] = px4(3, 0, 1, 3)
    return t
def t_mud():
    t = blank(solid(3))
    for u in range(16):
        for v in range(16):
            if h(u, v, 5) == 0: t[u][v] = dith(3, 2)
            if v > 11 and (u + v) % 3 == 0: t[u][v] = solid(2)
            if v < 2: t[u][v] = dith(1, 3)
    return t
def t_reeds():
    t = blank(dith(0, 1))
    for u in range(16):
        stalk = (u*5) % 7
        for v in range(16):
            if stalk < 3: t[u][v] = px4(0, 3, 0, 3) if stalk else px4(3, 0, 3, 0)
            if stalk == 0 and 2 <= v <= 5: t[u][v] = solid(2)
            if v > 12: t[u][v] = solid(1)
    return t
def t_sand():
    t = blank(solid(3))
    for u in range(16):
        for v in range(16):
            w = (v + (u//8)) % 8
            t[u][v] = [solid(3), solid(3), solid(3), dith(1, 3), solid(1), solid(1), dith(3, 1), solid(3)][w]
            if h(u, v, 17) == 0: t[u][v] = px4(3, 2, 3, 3)
    return t
def t_bones():
    t = blank(dith(2, 3))
    for u in range(16):
        for v in range(16):
            if v in (4, 11) and 2 <= u <= 13: t[u][v] = solid(0)
            if v in (3, 5, 10, 12) and u in (2, 3, 12, 13): t[u][v] = solid(0)
            if 6 <= u <= 9 and 6 <= v <= 9: t[u][v] = solid(0) if (u, v) not in ((7, 7), (8, 7)) else solid(2)
    return t
def cracked(fn, col):
    t = fn()
    for v in range(16):
        u = 7 + (1 if v % 6 in (2, 3, 4) else 0) - (1 if v % 6 == 0 else 0)
        t[u][v] = solid(col)
        if v % 5 == 2: t[u+1][v] = px4(col, col, 0, 0) if col else px4(2, 2, 0, 0)
    return t
def t_door():
    t = blank(solid(2))
    for u in range(16):
        for v in range(16):
            if v in (0, 15) or u in (0, 15): t[u][v] = solid(3)
            elif u % 4 == 0: t[u][v] = px4(3, 2, 2, 2)
            elif 11 <= u <= 12 and 7 <= v <= 9: t[u][v] = solid(1)
    return t
def t_exit():
    t = blank(solid(1))
    for u in range(16):
        for v in range(16):
            if v in (0, 1, 14, 15) or u in (0, 15): t[u][v] = solid(3)
            elif 3 <= v <= 12 and abs(v-7.5) <= (u-2)*0.75 and u <= 9: t[u][v] = solid(2)
            elif 6 <= v <= 9 and 9 < u <= 13: t[u][v] = solid(2)
    return t
def t_locked():
    t = blank(solid(3))
    for u in range(16):
        for v in range(16):
            if v in (0, 15) or u in (0, 15): t[u][v] = solid(2)
            elif 5 <= u <= 10 and 8 <= v <= 12: t[u][v] = solid(1)
            elif u in (6, 9) and 4 <= v <= 7: t[u][v] = solid(1)
            elif u in (7, 8) and v == 4: t[u][v] = solid(1)
    t[7][10] = t[8][10] = solid(2)
    return t
def t_switch(on):
    t = blank(solid(2))
    for u in range(16):
        for v in range(16):
            if u in (0, 15) or v in (0, 15): t[u][v] = solid(3)
            elif 4 <= u <= 11 and 4 <= v <= 11: t[u][v] = solid(0)
    for v in (range(3, 8) if on else range(8, 13)): t[7][v] = t[8][v] = solid(1 if on else 3)
    for u in (6, 7, 8, 9): t[u][3 if on else 12] = solid(1 if on else 3)
    return t
def t_gate():
    t = blank(solid(2))
    for u in range(16):
        for v in range(16):
            if u % 3 == 1 or v in (1, 2, 13, 14): t[u][v] = solid(3)
            if u % 3 == 1 and v in (0, 15): t[u][v] = solid(1)
    return t
def flat(t): return [t[u][v] for u in range(16) for v in range(16)]

# library (bank 3): every theme wall; copied four at a time into bank 1 on entering an area
LIBNAMES = ['brick', 'crate', 'iron', 'brick_c', 'hedge', 'bark', 'cliff', 'hedge_c', 'minerock', 'timber', 'ore',
            'minerock_c', 'mud', 'reeds', 'mud_c', 'sand', 'sand_c', 'bones', 'cliff_c']
LIBFN = dict(brick=t_brick, crate=t_crate, iron=t_iron, brick_c=lambda: cracked(t_brick, 2), hedge=t_hedge,
             bark=t_bark, cliff=t_cliff, hedge_c=lambda: cracked(t_hedge, 2), minerock=t_minerock, timber=t_timber,
             ore=t_ore, minerock_c=lambda: cracked(t_minerock, 1), mud=t_mud, reeds=t_reeds,
             mud_c=lambda: cracked(t_mud, 2), sand=t_sand, sand_c=lambda: cracked(t_sand, 2), bones=t_bones,
             cliff_c=lambda: cracked(t_cliff, 1))
NAREA = 9
blob('LIVE', [0]*(384*NAREA), 1, 'b3')
libpage = {}
for nm in LIBNAMES: libpage[nm] = blob(None, flat(LIBFN[nm]()), 256, 'b3') >> 8

# active slots and shared textures (bank 1)
blob('ACTTEX', [0]*1024, 256, 'b1')
act = syms['ACTTEX'] >> 8
shared = {}
for nm, fn in (('door', t_door), ('exit', t_exit), ('locked', t_locked), ('sw0', lambda: t_switch(0)),
               ('sw1', lambda: t_switch(1)), ('gate', t_gate)):
    shared[nm] = blob(None, flat(fn()), 256, 'b1') >> 8
# cell value 1..10 -> texture page
blob('TTEX', [act, act+1, shared['door'], shared['exit'], act+2, shared['locked'], shared['sw0'], shared['sw1'],
              shared['gate'], act+3])

# ---- themes: latch, sky, ground, fog distance, fog colour, four library textures ---------
THEMES = [  # name: css, sky, ground, fog cells (0 none), A, B, C, crack
    ('STATION', 0x18, solid(1), solid(0), 0, 'brick', 'crate', 'iron', 'brick_c'),
    ('BUSH', 0x08, solid(2), solid(1), 0, 'hedge', 'bark', 'cliff', 'hedge_c'),
    ('MINE', 0x08, solid(2), solid(3), 5.0, 'minerock', 'timber', 'ore', 'minerock_c'),
    ('SWAMP', 0x18, solid(2), solid(1), 7.0, 'mud', 'reeds', 'bark', 'mud_c'),
    ('RIDGE', 0x08, solid(2), solid(1), 0, 'sand', 'cliff', 'bones', 'sand_c'),
    ('LAIR', 0x18, solid(2), solid(3), 5.5, 'cliff', 'bones', 'sand', 'cliff_c')]
TH = {}
th = []
for i, (nm, css, sky, gr, fog, a, b, c, cr) in enumerate(THEMES):
    TH[nm] = i
    th += [css, sky, gr, hidx_for_dist(fog) if fog else 0, solid(2), libpage[a], libpage[b], libpage[c], libpage[cr]]
blob('THEMES', th)

# ---- unrolled helpers ---------------------------------------------------------------------
FILL = blob('FILL', [0x71, 0x19]*VIEWH + [0xC9])
blob('mul816', [0x21, 0, 0] + [0x29, 0x17, 0x30, 0x03, 0x19, 0xCE, 0x00]*8 + [0xC9])
blob('BLIT4', [0xED, 0xA0]*128 + [0xC9])
blob('DARKCOPY', [0x4E, 0x0A, 0x12, 0x2C, 0x1C]*16 + [0xC9])
SPRMAX = 48
SPRUNR = blob('SPRUNR', [0xD1, 0x7E, 0xA3, 0xB2, 0x77, 0x09]*SPRMAX + [0xC3, 0, 0])
syms['SPREND'] = SPRUNR + 6*SPRMAX

# ---- compiled wall scalers --------------------------------------------------------------
recs = []
for k, hh in enumerate(HEIGHTS):
    if hh <= VIEWH:
        top = (VIEWH-hh)//2; n = hh
        rows = [min(15, int((y+0.5)*16/hh)) for y in range(n)]
    else:
        top = 0; n = VIEWH
        rows = [max(0, min(15, int(math.floor(8+(y-(VIEWH/2-0.5))*16/hh)))) for y in range(n)]
    code = []; prev = None
    for v in rows:
        if v != prev: code += [0x3A, (syms['TEXBUF']+v) & 255, syms['TEXBUF'] >> 8]; prev = v
        code += [0x77, 0x19]
    sc = blob(None, code+[0xC9])
    for a in (FILL+(VIEWH-top)*2, sc, FILL+(top+n)*2, FILL+(VIEWH-n)*2): recs += [a & 255, a >> 8]
blob('REC', recs)
blob('BOT', [min(VIEWH, VIEWH//2 + (hh+1)//2) for hh in HEIGHTS])
FOV2 = math.radians(30); cols = []
for i in range(32):
    t = math.atan((i+0.5-16)/16*math.tan(FOV2))
    off = int(round(t*NA/(2*math.pi))) & 0xFFFF
    cols += [off & 255, off >> 8, int(round(-K*math.log2(math.cos(t))))]
blob('COLS', cols)

# ---- sprites ---------------------------------------------------------------------------------
def ell(cx, cy, rx, ry, col): return lambda u, v: col if ((u-cx)/rx)**2+((v-cy)/ry)**2 <= 1 else None
def rect(x0, y0, x1, y1, col): return lambda u, v: col if x0 <= u <= x1 and y0 <= v <= y1 else None
def tri(ax, ay, bx, by, cx, cy, col):
    def f(u, v):
        d1 = (u-bx)*(ay-by)-(ax-bx)*(v-by); d2 = (u-cx)*(by-cy)-(bx-cx)*(v-cy); d3 = (u-ax)*(cy-ay)-(cx-ax)*(v-ay)
        neg = d1 < 0 or d2 < 0 or d3 < 0; pos = d1 > 0 or d2 > 0 or d3 > 0
        return None if (neg and pos) else col
    return f
CLEAR = -1
def paint(layers):
    def f(u, v):
        out = None
        for L in layers:
            c = L(u, v)
            if c is not None: out = None if c == CLEAR else c
        return out
    return f
def sym(layers):
    """mirror every layer so the shape is exactly symmetric"""
    f = paint(layers)
    return lambda u, v: f(min(u, 1-u), v)

bear_common = [ell(.2, .13, .13, .12, 0), ell(.2, .13, .07, .065, 1),
               ell(.33, .92, .13, .08, 0), ell(.27, .96, .06, .035, 3),
               ell(.5, .68, .27, .27, 0), ell(.5, .72, .15, .17, 1)]
bear_walk = sym(bear_common + [
    ell(.2, .62, .09, .17, 0), ell(.2, .80, .07, .04, 3),
    ell(.5, .33, .29, .23, 0), ell(.38, .28, .06, .055, 2), ell(.38, .29, .03, .03, 1), ell(.5, .39, .075, .10, 2),
    rect(.43, .50, .47, .57, 1)])
bear_bite = sym(bear_common + [
    ell(.11, .42, .09, .18, 0), ell(.11, .24, .08, .045, 3),
    ell(.5, .33, .29, .23, 0), ell(.38, .25, .07, .04, 3),
    ell(.5, .33, .06, .05, 3), ell(.5, .46, .14, .09, 3),
    rect(.39, .39, .44, .47, 1), rect(.45, .49, .48, .54, 1)])
bat_up = sym([tri(.5, .45, .02, .0, .3, .75, 3), tri(.06, .05, .12, .45, .3, .35, 2),
              ell(.5, .55, .14, .3, 3), ell(.5, .3, .12, .12, 3), tri(.38, .22, .44, .05, .47, .22, 3),
              ell(.45, .3, .03, .035, 1), ell(.5, .62, .07, .15, 0)])
bat_dn = sym([tri(.5, .35, .02, .95, .32, .4, 3), tri(.08, .85, .15, .55, .3, .5, 2),
              ell(.5, .55, .14, .3, 3), ell(.5, .3, .12, .12, 3), tri(.38, .22, .44, .05, .47, .22, 3),
              ell(.45, .3, .03, .035, 1), ell(.5, .62, .07, .15, 0)])
bunyip_common = [ell(.5, .62, .46, .32, 1), ell(.25, .55, .08, .1, 3), ell(.68, .75, .07, .06, 3), ell(.32, .82, .06, .05, 3),
                 ell(.2, .93, .12, .07, 1), ell(.2, .97, .1, .03, 3),
                 rect(.36, .02, .4, .2, 1), ell(.38, .08, .08, .08, 0), ell(.38, .09, .04, .04, 3)]
bunyip_walk = sym(bunyip_common + [ell(.5, .5, .22, .06, 2), rect(.32, .44, .36, .5, 0), rect(.44, .44, .48, .52, 0)])
bunyip_bite = sym(bunyip_common + [ell(.5, .5, .3, .18, 2), rect(.24, .34, .29, .44, 0), rect(.36, .32, .41, .44, 0),
                                   rect(.3, .56, .35, .66, 0), rect(.43, .58, .48, .68, 0), ell(.5, .55, .1, .06, 3)])
yowie_common = [ell(.5, .45, .3, .28, 0), ell(.5, .17, .2, .17, 0), ell(.5, .2, .12, .1, 3),
                ell(.43, .17, .035, .03, 1), ell(.5, .27, .06, .025, 2),
                rect(.3, .6, .45, .9, 0), ell(.36, .95, .11, .05, 3), ell(.5, .5, .15, .17, 1)]
yowie_walk = sym(yowie_common + [ell(.17, .55, .09, .25, 0), ell(.15, .8, .08, .06, 3)])
yowie_bite = sym(yowie_common + [ell(.15, .25, .09, .22, 0), ell(.12, .06, .08, .06, 3), ell(.5, .27, .08, .05, 2),
                                 rect(.44, .24, .47, .28, 0)])
item_health = sym([rect(.15, .28, .85, 1.0, 3), rect(.15, .45, .85, .80, 1), rect(.30, .56, .70, .68, 3),
                   rect(.22, .06, .78, .28, 2)])
item_ammo = sym([rect(.05, .40, .95, 1.0, 2), rect(.05, .58, .95, .74, 1), rect(.18, .08, .30, .40, 3), rect(.44, .08, .56, .40, 3)])
item_key = paint([ell(.26, .5, .24, .36, 1), ell(.26, .5, .11, .17, CLEAR), rect(.45, .40, .97, .60, 1),
                  rect(.68, .60, .78, .90, 1), rect(.86, .60, .96, .82, 1)])
item_opal = sym([tri(.5, .0, .0, .45, .5, 1.0, 1), tri(.5, .0, .25, .22, .5, .45, 0), tri(.5, .45, .2, .5, .5, .85, 3),
                 ell(.5, .45, .08, .08, 0)])
item_map = sym([rect(.1, .15, .9, .85, 0), ell(.1, .5, .1, .4, 3), rect(.25, .3, .45, .36, 2), rect(.25, .48, .75, .54, 2),
                rect(.25, .66, .6, .72, 2)])

sprite_bytes = {}
def prescale(fn, hh, wpx, mirror):
    wb = max(1, math.ceil((wpx+2)/4)); W = wb*4; pad = (W-wpx)/2
    g = [[(fn((x+0.5-pad)/wpx, (y+0.5)/hh) if 0 <= (x+0.5-pad)/wpx <= 1 else None) for x in range(W)] for y in range(hh)]
    if mirror:
        for y in range(hh):
            for x in range(W//2, W): g[y][x] = g[y][W-1-x]
    o = [r[:] for r in g]
    for y in range(hh):
        for x in range(W):
            if g[y][x] is None and any(0 <= y+dy < hh and 0 <= x+dx < W and g[y+dy][x+dx] is not None
                                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))): o[y][x] = 2
    keep = (wb+1)//2 if mirror else wb
    out = []
    for bx in range(keep):
        for y in range(hh):
            m = 0; d = 0
            for c in o[y][bx*4:bx*4+4]:
                m = m << 2 | (3 if c is None else 0); d = d << 2 | (0 if c is None else c)
            out += [m, d]
    return wb, out, o
PREVIEW = {}
def frameset(name, fn, ladder, aspect, mirror=True):
    table = []; tot = 0
    for hh in ladder:
        wb, data, grid = prescale(fn, hh, max(2, round(hh*aspect)), mirror)
        a = art(None, data); table += [wb | (0 if mirror else 0x80), hh, a & 255, a >> 8]; tot += len(data)
    PREVIEW[name] = grid
    sprite_bytes[name] = tot
    return blob(name, table)
BEAR_L = [3, 4, 6, 8, 11, 14, 18, 23, 29, 36, 44]
BIG_L = [4, 6, 8, 11, 14, 18, 23, 29, 36, 44]
BAT_L = [2, 3, 4, 6, 8, 10, 13, 16, 20, 25]
ITEM_L = [2, 3, 4, 6, 8, 11, 14, 18]
BW = frameset('SPR_WALK', bear_walk, BEAR_L, 1.125)
BB = frameset('SPR_BITE', bear_bite, BEAR_L, 1.125)
YW = frameset('SPR_YOW0', yowie_walk, BIG_L, 0.8)
YB = frameset('SPR_YOW1', yowie_bite, BIG_L, 0.8)
UW = frameset('SPR_BUN0', bunyip_walk, BIG_L, 1.4)
UB = frameset('SPR_BUN1', bunyip_bite, BIG_L, 1.4)
VU = frameset('SPR_BAT0', bat_up, BAT_L, 1.6)
VD = frameset('SPR_BAT1', bat_dn, BAT_L, 1.6)
IH = frameset('SPR_HEALTH', item_health, ITEM_L, 1.1)
IA = frameset('SPR_AMMO', item_ammo, ITEM_L, 1.4)
IK = frameset('SPR_KEY', item_key, ITEM_L, 1.8, mirror=False)
IO = frameset('SPR_OPAL', item_opal, ITEM_L, 0.8)
IM = frameset('SPR_MAPI', item_map, ITEM_L, 1.3)
def sizetab(name, ladder, frac):
    return blob(name, [min(range(len(ladder)), key=lambda j: abs(ladder[j]-frac*hh)) for hh in HEIGHTS])
SB = sizetab('SZ_BEAR', BEAR_L, 0.62); SBOSS = sizetab('SZ_BOSS', BEAR_L, 0.95)
SBAT = sizetab('SZ_BAT', BAT_L, 0.3); SBUN = sizetab('SZ_BUN', BIG_L, 0.7); SYOW = sizetab('SZ_YOW', BIG_L, 1.0)
SI = sizetab('SZ_ITEM', ITEM_L, 0.28)

# ---- text --------------------------------------------------------------------------------------
GLYPHS = {
 ' ': "... ... ... ... ...", 'A': ".#. #.# ### #.# #.#", 'B': "##. #.# ##. #.# ##.", 'C': ".## #.. #.. #.. .##",
 'D': "##. #.# #.# #.# ##.", 'E': "### #.. ##. #.. ###", 'F': "### #.. ##. #.. #..", 'G': ".## #.. #.# #.# .##",
 'H': "#.# #.# ### #.# #.#", 'I': "### .#. .#. .#. ###", 'J': "..# ..# ..# #.# .#.", 'K': "#.# #.# ##. #.# #.#",
 'L': "#.. #.. #.. #.. ###", 'M': "#.# ### ### #.# #.#", 'N': "##. #.# #.# #.# #.#", 'O': "### #.# #.# #.# ###",
 'P': "### #.# ### #.. #..", 'Q': "### #.# #.# ### ..#", 'R': "### #.# ##. #.# #.#", 'S': ".## #.. .#. ..# ##.",
 'T': "### .#. .#. .#. .#.", 'U': "#.# #.# #.# #.# ###", 'V': "#.# #.# #.# #.# .#.", 'W': "#.# #.# ### ### #.#",
 'X': "#.# #.# .#. #.# #.#", 'Y': "#.# #.# .#. .#. .#.", 'Z': "### ..# .#. #.. ###",
 '0': ".#. #.# #.# #.# .#.", '1': ".#. ##. .#. .#. ###", '2': "##. ..# .#. #.. ###", '3': "##. ..# .#. ..# ##.",
 '4': "#.# #.# ### ..# ..#", '5': "### #.. ##. ..# ##.", '6': ".## #.. ### #.# ###", '7': "### ..# .#. .#. .#.",
 '8': "### #.# ### #.# ###", '9': "### #.# ### ..# ##.", '!': ".#. .#. .#. ... .#.", '-': "... ... ### ... ...",
 '+': "... .#. ### .#. ...", '.': "... ... ... ... .#.", ':': "... .#. ... .#. ...", "'": ".#. .#. ... ... ...",
 '/': "..# ..# .#. #.. #..", ',': "... ... ... .#. #.."}
CHARS = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!-+.:'/,"
font = []
for ch in CHARS:
    for r in GLYPHS[ch].split(): font.append(sum((1 if c == '#' else 2) << (6-2*i) for i, c in enumerate(r)) | 2)
    font.append(0xAA)
blob('FONT', font)
def enc(s): return [CHARS.index(c) for c in s] + [0xFF]
def page(name, lines):
    out = []
    for row, col, s in lines:
        assert col+len(s) <= 32, s
        a = 0x7000+row*32+col; out += [a & 255, a >> 8] + enc(s)
    return blob(name, out+[0, 0])
def centre(row, s): return (row, (32-len(s))//2, s)
LOGOTXT = "DROPBEAR 3D"; LW = len(LOGOTXT)*8; LH = 12
lg = [[2]*LW for _ in range(LH)]
for pas, col in ((1, 3), (0, 1)):
    for ci, ch in enumerate(LOGOTXT):
        for ry, r in enumerate(GLYPHS[ch].split()):
            for rx, c in enumerate(r):
                if c == '#':
                    for yy in range(2):
                        for xx in range(2):
                            x = ci*8+rx*2+xx+pas; y = ry*2+yy+pas
                            if x < LW and y < LH: lg[y][x] = col
blob('LOGO', [sum(lg[y][x*4+i] << (6-2*i) for i in range(4)) for y in range(LH) for x in range(LW//4)])
syms['LOGOW'] = LW//4; syms['LOGOH'] = LH
page('PG_TITLE', [centre(18, "VIBED BY BPM 2026"), (27, 16, "W S    WALK"), (34, 16, "A D    TURN"),
                  (41, 16, "Q E    STRAFE"), (48, 16, "SPACE  FIRE"), (57, 16, "PRESS FIRE!")])
page('PG_INTRO', [centre(3, "G'DAY, RANGER!"), centre(12, "DROP BEARS HAVE OVERRUN THE"),
                  centre(18, "OUTBACK. FIGHT THROUGH NINE"), centre(24, "AREAS, BEAT THE BIG THREE"),
                  centre(30, "AND GET BACK TO YOUR UTE."), centre(39, "KEYS OPEN LOCKED DOORS. BUMP"),
                  centre(45, "SWITCHES. CRACKED WALLS HIDE"), centre(51, "OPALS. HOLD M FOR THE MAP."),
                  centre(58, "PRESS FIRE")])
page('PG_HUD', [(50, 0, "HP"), (50, 15, "AMMO"), (50, 24, "KEY"), (57, 0, "OPALS")])
page('PG_DEAD', [centre(12, "OUCH!"), centre(24, "THE DROP BEARS GOT YOU."), centre(34, "HAVE ANOTHER GO, MATE."),
                 centre(54, "PRESS FIRE")])
for nm, s in (('MSG_NOMAP', "NO MAP HERE YET"), ('MSG_SECRET', "SECRET FOUND!"), ('MSG_DOOR', "DOOR OPENS"),
              ('MSG_UNLOCK', "UNLOCKED!"), ('MSG_NEEDKEY', "NEED A KEY!"), ('MSG_GATE', "A GATE OPENS!"),
              ('MSG_MAP', "GOT MAP! HOLD M"), ('MSG_KEY', "GOT A KEY!"), ('MSG_OPAL', "OPAL! BEAUTY!"),
              ('MSG_HEALTH', "VEGEMITE! +25"), ('MSG_AMMO', "AMMO +15"), ('MSG_OUCH', "OUCH!"), ('MSG_BLANK', ""),
              ('MSG_K1', "GOT ONE!"), ('MSG_K2', "BAT DOWN!"), ('MSG_K3', "BIG FELLA DOWN!"),
              ('MSG_K4', "BUNYIP BEATEN!"), ('MSG_K5', "YOWIE DOWN!")):
    assert len(s) <= 16
    blob(nm, enc(s.ljust(16)))

# creature and pickup types: size table, frame 0, frame 1, hp, speed, bite, flags, kill message
# flags: 1 boss (opens gates when beaten), 2 charges in bursts, 4 speeds up when hurt, 8 flies
TYPES = [(SB, BW, BB, 2, 12, 7, 0, 'MSG_K1'), (SBAT, VU, VD, 1, 16, 4, 8, 'MSG_K2'),
         (SBOSS, BW, BB, 12, 8, 14, 1, 'MSG_K3'), (SBUN, UW, UB, 16, 22, 14, 3, 'MSG_K4'),
         (SYOW, YW, YB, 20, 7, 16, 5, 'MSG_K5'),
         (SI, IH, IH, 0, 0, 0, 0, 'MSG_BLANK'), (SI, IA, IA, 0, 0, 0, 0, 'MSG_BLANK'), (SI, IK, IK, 0, 0, 0, 0, 'MSG_BLANK'),
         (SI, IO, IO, 0, 0, 0, 0, 'MSG_BLANK'), (SI, IM, IM, 0, 0, 0, 0, 'MSG_BLANK')]
tt = []
for st, f0, f1, hp, sp, bite, fl, msg in TYPES:
    m = syms[msg]; tt += [st & 255, st >> 8, f0 & 255, f0 >> 8, f1 & 255, f1 >> 8, hp, sp, bite, fl, m & 255, m >> 8]
blob('TYPES', tt)
syms['NENEMY'] = 5
syms['TBEAR0'] = BW + 9*4; syms['TBEAR1'] = BB + 9*4

GUN = ["..........3333..........", "..........3113..........", ".........222222.........", ".........212222.........",
       ".........212222.........", ".........212222.........", "........22122222........", "........22122222........",
       ".......2221222222.......", "......222212222222......", ".....22222222222222.....", "....2223333333333222....",
       "....2223111111113222....", "...222233333333332222...", "...222222222222222222...", "..22222222222222222222.."]
FLASH = ["........1..33..1........", ".........131131.........", "......1.13311331.1......", ".......1331111331.......",
         "........33111133........", ".........331133........."]
def gunrec(name, artrows):
    hh = len(artrows); out = []
    for bx in range(6):
        for y in range(hh):
            m = 0; d = 0
            for ch in artrows[y][bx*4:bx*4+4]:
                m = m << 2 | (3 if ch == '.' else 0); d = d << 2 | (0 if ch == '.' else int(ch))
            out += [m, d]
    a = art(None, out); return blob(name, [6 | 0x80, hh, a & 255, a >> 8])
gunrec('GUN0', GUN); syms['GUNH'] = len(GUN)
gunrec('GUN1', [("".join(f if f != '.' else g for f, g in zip(FLASH[y], GUN[y])) if y < len(FLASH) else GUN[y]) for y in range(len(GUN))])

# ---- the world ---------------------------------------------------------------------------------
# '#' wall A, 'C' wall B, 'W' wall C, 'D' door, 'X' way out, 'L' locked door, 'S' switch, 'G' gate,
# '%' cracked wall (secret), '.' floor, 'P' start
# b bear, v bat, B Big Fella, U Bunyip, Y Yowie, h Vegemite, a ammo, k key, o opal, m map
AREAS = [
 dict(name="THE HOMESTEAD", theme='STATION', known=1, exits=[1], rows=[
  "################",
  "#P...#...o#....#",
  "#....#....#.b..#",
  "#....D....D....#",
  "#..a.#....#....#",
  "###D####%###D###",
  "#....#..o..#...#",
  "#.CC.#.....#.h.#",
  "#.CC.#######...#",
  "#....D.........#",
  "#.b..#..CCC..b.#",
  "#....#..C.C....#",
  "#WWWW#.........#",
  "#..o%..........#",
  "#...#....b.....X",
  "################"]),
 dict(name="THE BUSH TRACK", theme='BUSH', known=1, exits=[0, 2, 3], rows=[
  "################",
  "#.....#........#",
  "X.....#..v.....#",
  "#.....D.....CC.#",
  "#..C.b#.....CC.#",
  "#..C..###D######",
  "#.......#.b....#",
  "##.###..#......X",
  "#....#..%..o...#",
  "#.o..#..#..h...#",
  "#....#..########",
  "#.a..D.........#",
  "###L###..v..CC.#",
  "X.....#.....CC.#",
  "#....b#..b..o..#",
  "################"]),
 dict(name="GUM TREE MAZE", theme='BUSH', known=0, exits=[1], rows=[
  "################",
  "#m#.....#.....o#",
  "#.#.###.#.###..#",
  "#.#.#...#...#..#",
  "#...#.#####.#.##",
  "###.#.#...#.#..#",
  "#...#...#.#.##.#",
  "X.###.#.#.#....#",
  "#.....#.#.####.#",
  "####.##.#....#.#",
  "#..#.#..####.#.#",
  "#.##.#.##..#.#.#",
  "#.#..#....##.#.#",
  "#.#.#####.#..#.#",
  "#o....v...#k.b.#",
  "################"]),
 dict(name="THE OLD MINE", theme='MINE', known=0, exits=[1, 4], rows=[
  "################",
  "#....WW....#...#",
  "X....WW..b.#.o.#",
  "#..........#...#",
  "#.WW...WW..##D##",
  "#.WW.b.WW......#",
  "#..........WW..#",
  "####D#####.WW..#",
  "#....#.....v...#",
  "#.m..#..WWWGWWWW",
  "#....#..W.b...h#",
  "#..b.#..W......#",
  "#....#..W.WWWW.#",
  "##S###..W.W..%.#",
  "#a......W.Wo.W.X",
  "################"]),
 dict(name="BIG FELLA'S DEN", theme='MINE', known=1, exits=[3, 5], rows=[
  "################",
  "#.....#........#",
  "X..a..D........#",
  "#.....#..W..W..#",
  "#.h...#........#",
  "###D###...B....#",
  "#.....#........#",
  "#..o..#..W..W..#",
  "#.....#........#",
  "#.....#######G##",
  "#.b...#.....#..#",
  "#.....#..o..#..#",
  "#.....%.....#..#",
  "#.....#.....#..#",
  "#..a..#.....#..X",
  "################"]),
 dict(name="THE BILLABONG", theme='SWAMP', known=0, exits=[4, 6], rows=[
  "################",
  "#......#..v....#",
  "X..CC..#.CC..CC#",
  "#..CC..D.CC....#",
  "#....v.#....b..#",
  "#......###L#####",
  "##D#####.......#",
  "#......#.CC.v..#",
  "#.CC...#.CC....#",
  "#.CC.b.#.b.WW..#",
  "#......#...WW.o#",
  "#.k..m.#.......#",
  "####%###.......#",
  "#.o.h..#.......#",
  "#......#..a....X",
  "################"]),
 dict(name="BUNYIP'S POOL", theme='SWAMP', known=1, exits=[5, 7], rows=[
  "################",
  "#.....#........#",
  "X.....D...CC...#",
  "#..h..#...CC...#",
  "#.....#........#",
  "#..a..#.CC..U..#",
  "##D####.CC.....#",
  "#.....#........#",
  "#.o...#...CC...#",
  "#.....#...CC...#",
  "#..v..#........#",
  "#.....######G###",
  "#.....#.v.....o#",
  "#..a..#........#",
  "#.....#........X",
  "################"]),
 dict(name="THE RIDGE", theme='RIDGE', known=0, exits=[6, 8], rows=[
  "################",
  "#.....#.v...#.o#",
  "X.###.#.###.#..#",
  "#.#...#...#.#L##",
  "#.#.#####.#....#",
  "#.#..b..#.####.#",
  "#.#####.#....#.#",
  "#m....#...k..#.#",
  "#####G###S######",
  "#..............#",
  "#.WW..b...WW...#",
  "#.WW......WW...#",
  "#......v.......#",
  "#..a.......h...#",
  "#..........o...X",
  "################"]),
 dict(name="YOWIE'S LAIR", theme='LAIR', known=1, exits=[7, 255], rows=[
  "################",
  "#.....#........#",
  "X..h..D........#",
  "#.....#..WW....#",
  "#..a..#..WW.Y..#",
  "###D###........#",
  "#.....#....WW..#",
  "#..o..#....WW..#",
  "#.....D........#",
  "#.b...#######G##",
  "#.....#.......v#",
  "#..a..#.......o#",
  "#.....#.......h#",
  "#.....#........#",
  "#..v..#........X",
  "################"])]
assert len(AREAS) == NAREA
CELL = {'#': 1, 'C': 2, 'D': 3, 'X': 4, 'W': 5, 'L': 6, 'S': 7, 'G': 9, '%': 10}
OBJC = {'b': 1, 'v': 2, 'B': 3, 'U': 4, 'Y': 5, 'h': 6, 'a': 7, 'k': 8, 'o': 9, 'm': 10}
DIRS = {(1, 0): 0, (0, 1): 1, (-1, 0): 2, (0, -1): 3}
WORLD = []
for ai, A in enumerate(AREAS):
    rows = A['rows']; assert len(rows) == 16 and all(len(r) == 16 for r in rows), A['name']
    grid = [[CELL.get(ch, 0) for ch in r] for r in rows]
    for i in range(16):
        for (x, y) in ((i, 0), (i, 15), (0, i), (15, i)): assert grid[y][x] in (1, 2, 4, 5), (A['name'], x, y)
    objs = [(OBJC[ch], x, y) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch in OBJC]
    assert len(objs) <= 16, A['name']
    xs = [(x, y) for y in range(16) for x in range(16) if rows[y][x] == 'X']
    assert len(xs) == len(A['exits']), A['name']
    WORLD.append(dict(grid=grid, objs=objs, xs=xs, rows=rows))
def entry_for(area, cell):
    x, y = cell; g = WORLD[area]['grid']
    for (dx, dy), f in DIRS.items():
        if 0 <= x+dx < 16 and 0 <= y+dy < 16 and g[y+dy][x+dx] == 0 and AREAS[area]['rows'][y+dy][x+dx] not in OBJC:
            return (x+dx, y+dy), f
    raise SystemExit('no floor beside exit %s in %s' % (cell, AREAS[area]['name']))
recaddr = []; EXITS = {}
for ai, A in enumerate(AREAS):
    W = WORLD[ai]
    ex = []
    for (x, y), tgt in zip(W['xs'], A['exits']):
        if tgt == 255:
            ex += [y*16+x, 255, 0, 0]; EXITS[(ai, (x, y))] = (255, None, None); continue
        back = [c for c, t in zip(WORLD[tgt]['xs'], AREAS[tgt]['exits']) if t == ai]
        assert len(back) == 1, (A['name'], tgt)
        (cx, cy), face = entry_for(tgt, back[0])
        ex += [y*16+x, tgt, cy*16+cx, face]; EXITS[(ai, (x, y))] = (tgt, (cx, cy), face)
    data = [TH[A['theme']], A['known']] + enc(A['name'].ljust(16)) + [len(W['xs'])] + ex + [len(W['objs'])]
    for o in W['objs']: data += list(o)
    flatg = [c for r in W['grid'] for c in r]
    data += [flatg[i] << 4 | flatg[i+1] for i in range(0, 256, 2)]
    recaddr.append(blob(None, data))
blob('ATAB', sum(([a & 255, a >> 8] for a in recaddr), []))
# no creature waiting right at a way in: you get a moment to look around first
problems = []
for (ai, cell), (tgt, ent, face) in EXITS.items():
    if tgt == 255: continue
    for t, x, y in WORLD[tgt]['objs']:
        if t <= 5 and max(abs(x-ent[0]), abs(y-ent[1])) <= 3:
            problems.append('%s: creature %d at %d,%d too close to the way in at %d,%d' % (AREAS[tgt]['name'], t, x, y, *ent))
for t, x, y in WORLD[0]['objs']:
    if t <= 5 and max(abs(x-1), abs(y-1)) <= 3: problems.append('start: creature at %d,%d' % (x, y))
if problems: raise SystemExit('\n'.join(sorted(set(problems))))
syms['NAREA'] = NAREA
(sx, sy), = [(x, y) for y, r in enumerate(AREAS[0]['rows']) for x, ch in enumerate(r) if ch == 'P']
syms['STARTCELL'] = sy*16+sx; syms['STARTANG'] = 0
NOPALS = sum(1 for W in WORLD for o in W['objs'] if o[0] == 9)
page('PG_WIN', [centre(6, "YOU BEAUTY!"), centre(17, "THE YOWIE IS DOWN AND THE"), centre(23, "UTE ROARS OFF HOME."),
                (33, 5, "OPALS FOUND:    OF %d" % NOPALS), centre(45, "VIBED BY BPM 2026"), centre(56, "PRESS FIRE")])
syms['WINNUM'] = 0x7000+33*32+5+13

# ---- music ---------------------------------------------------------------------------------------
NOTE = {n: 440*2**((i-9)/12) for i, n in enumerate(['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'])}
def freq(n): return NOTE[n[:-1]]*2**(int(n[-1])-4)
def count(f): return max(4, int(round((CLOCK/(2*f)-130)/26)))
def ttune(seq):
    out = []
    for n, ms, gap in seq:
        if n == '-': out += [0, 0, 0, gap]
        else: f = freq(n); out += [count(f) & 255, count(f) >> 8, min(255, max(2, int(round(f*2*ms/1000)))), gap]
    return out + [0xFF, 0xFF]
riff = [('E3', 110, 12), ('E3', 110, 12), ('G3', 110, 12), ('E3', 110, 30), ('A3', 110, 12), ('G3', 110, 12), ('E3', 150, 40),
        ('E3', 110, 12), ('E3', 110, 12), ('G3', 110, 12), ('A3', 110, 30), ('B3', 110, 12), ('A3', 110, 12), ('G3', 150, 40),
        ('E3', 110, 12), ('E3', 110, 12), ('G3', 110, 12), ('E3', 110, 30), ('D3', 110, 12), ('D3', 110, 12), ('E3', 220, 60),
        ('-', 0, 40)]
blob('TTUNE', ttune(riff))
def gtune(seq):
    out = []
    for n in seq:
        if n == '-': out += [0, 0, 0]
        else: f = freq(n); out += [count(f) & 255, count(f) >> 8, 4]
    return out + [0xFF, 0xFF]
blob('GTUNE', gtune(['E4', '-', '-', 'E4', 'G4', 'E4', '-', '-', 'D4', '-', '-', 'D4', 'F4', 'D4', '-', '-',
                     'E4', '-', '-', 'E4', 'G4', 'A4', '-', '-', 'B4', '-', 'A4', '-', 'G4', '-', '-', '-']))

# ---- assemble ---------------------------------------------------------------------------------------
syms['CODEORG'] = used['main']
for k in list(syms):
    if isinstance(syms[k], int) and (k.isupper() or k.startswith('SPR')): syms[k+'_HI'] = syms[k] >> 8
syms['ZBUF_LO'] = syms['ZBUF'] & 255
code = assemble(open('dropbear.asm').read(), syms)
for a, v in code.items(): mem[a] = v
codeend = syms['codeend']; IMGEND = (codeend+255) & 0xFF00
assert IMGEND <= 0xF800, 'main RAM overflow: code ends %04X' % codeend
mem[syms['SPREND']+1] = syms['ds_ret'] & 255; mem[syms['SPREND']+2] = syms['ds_ret'] >> 8
image = bytes(mem[0x8100:IMGEND]); img1 = bytes(b1[:used['b1']-0x4000]); img3 = bytes(b3[:used['b3']-0x4000])

# ---- pack: literal runs (0..127 = n+1 bytes) or copies ($81..$FF = length-3, then 16-bit distance); $80 ends
def pack(data):
    out = bytearray(); i = 0; n = len(data); lit = bytearray(); table = {}; worst = 0
    def flush():
        nonlocal lit
        while lit:
            chunk = lit[:128]; out.append(len(chunk)-1); out.extend(chunk); lit = lit[128:]
    while i < n:
        best = 0; bd = 0
        if i+3 <= n:
            for p in reversed(table.get(data[i:i+3], [])[-64:]):
                l = 3
                while l < 130 and i+l < n and data[p+l] == data[i+l]: l += 1
                if l > best: best = l; bd = i-p
                if l == 130: break
        if best >= 4:
            flush(); out.append(0x80 | (best-3)); out += bytes([bd & 255, bd >> 8])
            for j in range(i, i+best):
                if j+3 <= n: table.setdefault(data[j:j+3], []).append(j)
            i += best
        else:
            if i+3 <= n: table.setdefault(data[i:i+3], []).append(i)
            lit.append(data[i]); i += 1
        worst = max(worst, i-len(out)-len(lit))
    flush(); out.append(0x80)
    return bytes(out), worst
pm, worst = pack(image); p1, _ = pack(img1); p3, _ = pack(img3)
STUB = """
        org $8000
        di
        ld sp,$FFF0
        ld a,3
        out ($37),a
        ld hl,PK3
        ld de,$4000
        call unpk
        ld a,1
        out ($37),a
        ld hl,PK1
        ld de,$4000
        call unpk
        ld hl,PKM+PKLEN-1
        ld de,$F9FF
        ld bc,PKLEN
        lddr
        inc de
        ex de,hl
        ld de,$8100
        call unpk
        jp START
unpk:   ld a,(hl)
        inc hl
        or a
        jp m,dpm
        ld c,a
        ld b,0
        inc bc
        ldir
        jr unpk
dpm:    and $7F
        ret z
        add a,3
        ld c,a
        ld b,0
        ld a,(hl)
        inc hl
        push hl
        ld h,(hl)
        ld l,a
        ld a,e
        sub l
        ld l,a
        ld a,d
        sbc a,h
        ld h,a
        ldir
        pop hl
        inc hl
        jr unpk
PKM:
"""
ss = dict(PKLEN=len(pm), START=syms['start'])
tmp = dict(ss, PK1=0, PK3=0); assemble(STUB, tmp)
ss['PK1'] = tmp['PKM']+len(pm); ss['PK3'] = ss['PK1']+len(p1)
stub = assemble(STUB, ss)
body = bytes(stub[a] for a in range(0x8000, ss['PKM'])) + pm + p1 + p3
assert ss['PKM'] <= 0x8100
assert 0x8000+len(body) < 0xFA00
# while unpacking the main image from the top of RAM, writes must never catch up with unread input
assert (0xFA00-len(pm)) - 0x8100 > worst + 8, 'unpack would overwrite its own input'
vz = b'VZF0' + b'DROPBEAR'.ljust(17, b'\0') + bytes([0xF1, 0x00, 0x80]) + body
open('DROPBEAR.VZ', 'wb').write(vz)
pickle.dump(dict(syms=syms, image=image, img1=img1, img3=img3, body=body, IMGEND=IMGEND, world=WORLD,
                 areas=[dict(name=A['name'], exits=A['exits'], theme=A['theme']) for A in AREAS], exits=EXITS,
                 nopals=NOPALS, preview=PREVIEW, heights=HEIGHTS), open('image.pkl', 'wb'))
if __name__ == '__main__':
    print('main RAM: data %04X-%04X, code %04X-%04X (%d bytes), %d bytes free' %
          (0x8100, syms['CODEORG'], syms['CODEORG'], codeend, codeend-syms['CODEORG'], 0xF800-codeend))
    print('SRAM bank 1 used to %04X (%d free), bank 3 used to %04X (%d free)' %
          (used['b1'], 0x6800-used['b1'], used['b3'], 0x6800-used['b3']))
    print('sprites: ' + ', '.join('%s %d' % (k[4:], v) for k, v in sprite_bytes.items()))
    print('packed: main %d, bank1 %d, bank3 %d; file %d bytes, loads 8000-%04X; %d opals in the world' %
          (len(pm), len(p1), len(p3), len(vz), 0x8000+len(body)-1, NOPALS))
