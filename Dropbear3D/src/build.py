"""Builds DROPBEAR.VZ: generates tables, art and the world, assembles, packs.

Memory plan
  $8000-$80FF  loader stub (unpacks the three blobs below, then starts the game)
  $8100-$F7FF  main RAM: engine tables, compiled scalers, some sprites, text, world, code
  $F800-$FFFF  work areas (map, texture column, depth buffer, sprite list, view buffer)
  $7800-$79FF  object list and flying pieces;  $7A00-$7FFF  more sprites
  $4000-$67FF  BennVenn SRAM bank 1 (mapper value 1): active textures, sprites
  $4000-$67FF  BennVenn SRAM bank 3 (mapper value 3): more sprites, switched in per sprite while drawing
  $B800-$FFFF  BennVenn high bank (mapper value 5): saved area states and the texture library, copied
               in and out only when you change area
"""
import math, pickle, sys
from z80tools import assemble, Z80

VIEWH = 48; NA = 1024; K = 42; DMIN = 0.25; WALL = 74.0
CLOCK = 3546900
mem = bytearray(65536); b1 = bytearray(0x2800); b3 = bytearray(0x2800); syms = {}
arena = {'main': [0x8100, 0xF800], 'b1': [0x4000, 0x6800], 'b3': [0x4000, 0x6800], 'lo': [0x7A00, 0x8000],
         'hi': [0xB800, 0x10000]}
lo = bytearray(0x600); hi = bytearray(0x4800)
used = {k: v[0] for k, v in arena.items()}

def blob(name, data, align=1, where='main'):
    p = used[where]; p = (p+align-1)//align*align
    assert p+len(data) <= arena[where][1], 'out of room in %s for %s (%d bytes)' % (where, name, len(data))
    if where == 'main': mem[p:p+len(data)] = bytes(data)
    elif where == 'b1': b1[p-0x4000:p-0x4000+len(data)] = bytes(data)
    elif where == 'lo': lo[p-0x7A00:p-0x7A00+len(data)] = bytes(data)
    elif where == 'hi': hi[p-0xB800:p-0xB800+len(data)] = bytes(data)
    else: b3[p-0x4000:p-0x4000+len(data)] = bytes(data)
    used[where] = p+len(data)
    if name: syms[name] = p
    return p
def art(name, data, align=1):
    """Sprite pixels: SRAM bank 1, then bank 3, then the spare RAM at $7A00, then main RAM. Returns (address, bank flag)."""
    for where in ('b1', 'b3', 'lo'):
        try: return blob(name, data, align, where), (0x40 if where == 'b3' else 0)
        except AssertionError: pass
    return blob(name, data, align, 'main'), 0

syms.update(MAP=0xF800, TEXBUF=0xF900, ZBUF=0xF920, VIS=0xF940, BUF=0xFA00, OBJ=0x7800, PART=0x7900)

# ---- trig, folded to one quadrant ------------------------------------------------------
act = []; dxl = []; dxh = []
for i in range(256):
    th = 2*math.pi*(i+0.5)/NA
    c = math.cos(th); act.append(min(255, int(round(c*256))))
    d = min(32767, int(round(256/c))); dxl.append(d & 255); dxh.append(d >> 8)
blob('ACT', act, 256); blob('DXLO', dxl+dxh, 256)
logd = [max(0, min(255, int(round(K*math.log2(max(i, 16)/64/DMIN))))) for i in range(1024)]
blob('LOGD', logd, 256)
HEIGHTS = list(range(1, 33)) + list(range(34, 49, 2)) + [52, 58, 66, 76, 90, 110, 140, 190, 256]
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
blob('HICOPY', [0]*16, 1, 'lo')
blob('LIVE', [0]*(512*NAREA), 1, 'hi')
libpage = {}
for nm in LIBNAMES: libpage[nm] = blob(None, flat(LIBFN[nm]()), 256, 'hi') >> 8

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
    th += [css, sky, gr, hidx_for_dist(fog) if fog else 0, solid(2), int(fog)+2 if fog else 9,
           libpage[a], libpage[b], libpage[c], libpage[cr]]
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

toad_sit = sym([ell(.5, .68, .45, .3, 3), ell(.5, .45, .32, .22, 3), ell(.3, .3, .11, .11, 3), ell(.3, .3, .07, .07, 0),
                ell(.3, .31, .03, .04, 2), ell(.5, .82, .26, .12, 1), ell(.2, .93, .12, .07, 3), rect(.36, .56, .5, .58, 2),
                ell(.24, .62, .04, .04, 1), ell(.38, .74, .035, .035, 1)])
toad_hop = sym([ell(.5, .42, .4, .27, 3), ell(.5, .27, .3, .2, 3), ell(.3, .14, .11, .11, 3), ell(.3, .14, .07, .07, 0),
                ell(.3, .15, .03, .04, 2), ell(.5, .52, .24, .12, 1), ell(.18, .74, .1, .2, 3), ell(.14, .95, .14, .05, 3),
                ell(.5, .38, .14, .06, 2)])
mag_up = sym([tri(.5, .42, .02, .02, .3, .62, 2), tri(.1, .1, .22, .38, .34, .4, 1), ell(.5, .55, .13, .28, 2),
              ell(.5, .26, .12, .12, 2), tri(.46, .3, .54, .3, .5, .46, 0), ell(.43, .22, .03, .03, 3), ell(.5, .62, .07, .1, 1)])
mag_dn = sym([tri(.5, .38, .02, .98, .3, .4, 2), tri(.1, .9, .22, .62, .34, .55, 1), ell(.5, .55, .13, .28, 2),
              ell(.5, .26, .12, .12, 2), tri(.46, .3, .54, .3, .5, .46, 0), ell(.43, .22, .03, .03, 3), ell(.5, .62, .07, .1, 1)])
snake_up = sym([ell(.5, .84, .46, .15, 3), ell(.5, .84, .3, .07, 1), ell(.5, .68, .32, .11, 3), ell(.5, .68, .18, .05, 1),
                rect(.42, .26, .58, .66, 3), rect(.42, .4, .58, .44, 1), ell(.5, .22, .16, .12, 3),
                ell(.42, .2, .035, .035, 0), rect(.49, .33, .51, .42, 2)])
snake_hit = sym([ell(.5, .84, .46, .15, 3), ell(.5, .84, .3, .07, 1), ell(.5, .68, .32, .11, 3), ell(.5, .68, .18, .05, 1),
                 rect(.42, .45, .58, .66, 3), ell(.5, .4, .19, .14, 3), ell(.5, .45, .1, .06, 2),
                 rect(.44, .41, .46, .48, 0), ell(.4, .35, .035, .035, 0)])
def legs(dy):
    return [tri(.44, .44, .02, .14+dy, .07, .1+dy, 3), tri(.43, .5, .0, .42+dy, .03, .36+dy, 3),
            tri(.43, .56, .02, .74-dy, .06, .68-dy, 3), tri(.44, .62, .08, .98-dy, .14, .95-dy, 3)]
spider_a = sym(legs(0) + [ell(.5, .5, .15, .17, 3), ell(.5, .72, .12, .15, 3), ell(.5, .72, .05, .07, 2),
                          ell(.45, .42, .025, .025, 1), ell(.48, .5, .02, .02, 1)])
spider_b = sym(legs(.08) + [ell(.5, .5, .15, .17, 3), ell(.5, .72, .12, .15, 3), ell(.5, .72, .05, .07, 2),
                            ell(.45, .42, .025, .025, 1), ell(.48, .5, .02, .02, 1)])
dingo_common = [tri(.3, .02, .2, .25, .42, .18, 3), ell(.5, .3, .26, .2, 3), ell(.5, .62, .24, .2, 3), ell(.5, .64, .1, .14, 0),
                rect(.32, .7, .42, .97, 3), ell(.37, .97, .07, .03, 0), ell(.38, .26, .04, .04, 1)]
dingo_run = sym(dingo_common + [ell(.5, .4, .12, .1, 0), ell(.5, .35, .05, .04, 2)])
dingo_bite = sym(dingo_common + [ell(.5, .42, .13, .12, 0), ell(.5, .35, .05, .04, 2), ell(.5, .46, .09, .06, 2),
                                 rect(.43, .42, .45, .47, 0)])
d_drum = sym([rect(.08, .12, .92, 1.0, 3), rect(.08, .35, .92, .4, 2), rect(.08, .7, .92, .75, 2), ell(.5, .12, .42, .1, 1)])
d_lamp = sym([rect(.46, 0, .54, .55, 2), tri(.5, .45, .05, .85, .95, .85, 3), ell(.5, .9, .16, .1, 1)])
d_shrub = sym([ell(.5, .62, .48, .38, 0), ell(.3, .45, .22, .25, 0), ell(.5, .3, .25, .25, 0), ell(.35, .5, .04, .04, 1),
               ell(.5, .3, .04, .04, 1), ell(.42, .76, .05, .05, 1), ell(.12, .7, .04, .04, 1)])
d_termite = sym([tri(.5, .0, .1, 1.0, .9, 1.0, 3), ell(.5, .12, .12, .14, 3), ell(.38, .5, .14, .2, 3), ell(.3, .82, .18, .2, 3),
                 ell(.45, .62, .04, .05, 2), ell(.42, .3, .03, .04, 2), ell(.28, .85, .04, .05, 2)])
d_cart = sym([rect(.06, .28, .94, .78, 3), rect(.0, .22, 1.0, .3, 2), ell(.35, .22, .16, .1, 1), ell(.5, .17, .14, .09, 1),
              rect(.2, .45, .24, .7, 2), ell(.25, .86, .12, .12, 2), ell(.25, .86, .04, .04, 1)])
d_stump = sym([rect(.25, .28, .75, 1.0, 3), ell(.5, .28, .25, .08, 1), tri(.25, .72, .02, 1.0, .3, 1.0, 3),
               rect(.38, .4, .41, .92, 2), ell(.5, .28, .1, .03, 3)])
d_reeds = sym([rect(.13, .32, .17, 1.0, 3), rect(.3, .12, .34, 1.0, 3), rect(.45, .25, .49, 1.0, 3),
               ell(.32, .16, .045, .11, 2), ell(.15, .36, .04, .09, 2), tri(.25, 1.0, .05, .5, .3, .9, 1)])
d_bones = sym([ell(.5, .42, .22, .27, 0), rect(.38, .62, .62, .74, 0), ell(.41, .4, .065, .075, 2),
               tri(.5, .5, .46, .58, .54, .58, 2), rect(.43, .66, .45, .74, 2), ell(.22, .88, .22, .06, 0), ell(.04, .88, .05, .08, 0)])

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
        a, bank = art(None, data); table += [wb | bank | (0 if mirror else 0x80), hh, a & 255, a >> 8]; tot += len(data)
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
def ladder(maxh):
    out = []; hh = 2
    while hh < maxh: out.append(hh); hh = max(hh+1, round(hh*1.33))
    return out + [maxh]
NEW = {}
for nm, f0, f1, frac, asp in (('TOAD', toad_sit, toad_hop, .24, 1.3), ('MAG', mag_up, mag_dn, .26, 1.5),
                              ('SNAKE', snake_up, snake_hit, .3, 1.35), ('SPIDER', spider_a, spider_b, .26, 1.7),
                              ('DINGO', dingo_run, dingo_bite, .5, .9)):
    L = ladder(min(40, round(frac*78)))
    NEW[nm] = (frameset('SPR_'+nm+'0', f0, L, asp), frameset('SPR_'+nm+'1', f1, L, asp), L, frac)
DEC = {}
for nm, fn, frac, asp in (('DRUM', d_drum, .45, .7), ('LAMP', d_lamp, .34, .55), ('SHRUB', d_shrub, .45, 1.0),
                          ('TERMITE', d_termite, .7, .55), ('CART', d_cart, .42, 1.25), ('STUMP', d_stump, .5, .75),
                          ('REEDS', d_reeds, .5, .9), ('BONES', d_bones, .28, 1.2)):
    L = ladder(min(40, round(frac*78)))
    DEC[nm] = (frameset('SPR_'+nm, fn, L, asp), L, frac)
def sizetab(name, ladder, frac):
    return blob(name, [min(range(len(ladder)), key=lambda j: abs(ladder[j]-frac*hh)) for hh in HEIGHTS])
SB = sizetab('SZ_BEAR', BEAR_L, 0.62); SBOSS = sizetab('SZ_BOSS', BEAR_L, 0.95)
SBAT = sizetab('SZ_BAT', BAT_L, 0.3); SBUN = sizetab('SZ_BUN', BIG_L, 0.7); SYOW = sizetab('SZ_YOW', BIG_L, 1.0)
SI = sizetab('SZ_ITEM', ITEM_L, 0.28)
for nm, (a0, a1, L, frac) in NEW.items(): NEW[nm] = (a0, a1, sizetab('SZ_'+nm, L, frac))
for nm, (a0, L, frac) in DEC.items(): DEC[nm] = (a0, sizetab('SZ_'+nm, L, frac))

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
 '/': "..# ..# .#. #.. #..", ',': "... ... ... .#. #..", '?': "##. ..# .#. ... .#."}
CHARS = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!-+.:'/,?"
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

page('PG_TITLE', [centre(32, "VIBED BY BPM 2026"), (40, 1, "W S  WALK     A D    TURN"),
                  (46, 1, "Q E  STRAFE   SPACE  FIRE"), (52, 1, "HOLD M FOR THE MAP"), centre(58, "PRESS FIRE")])
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
              ('MSG_K4', "BUNYIP BEATEN!"), ('MSG_K5', "YOWIE DOWN!"), ('MSG_K6', "TOAD SQUASHED!"),
              ('MSG_K7', "MAGPIE DOWN!"), ('MSG_DEMO', "DEMO. PRESS FIRE"), ('MSG_K8', "SNAKE GONE!"), ('MSG_K9', "SPIDER SPLAT!"), ('MSG_K10', "DINGO DOWN!")):
    assert len(s) <= 16
    blob(nm, enc(s.ljust(16)))

# creature, pickup and furniture types: size table, frame 0, frame 1, hp, speed, bite, flags, kill message,
# burst colours (four 2-bit colours), burst size
# flags: 1 boss (opens gates when beaten), 2 moves in bursts, 4 speeds up when hurt, 8 flies,
#        16 hangs from the ceiling, 32 blocks the way
def cols(*c): return c[0] | c[1] << 2 | c[2] << 4 | c[3] << 6
N = NEW; D = DEC
TYPES = [(SB, BW, BB, 2, 13, 8, 0, 'MSG_K1', cols(0, 0, 1, 3), 22), (SBAT, VU, VD, 1, 17, 4, 8, 'MSG_K2', cols(3, 3, 2, 1), 14),
         (SBOSS, BW, BB, 18, 9, 15, 1, 'MSG_K3', cols(0, 0, 1, 3), 32), (SBUN, UW, UB, 24, 24, 15, 3, 'MSG_K4', cols(1, 1, 3, 0), 32),
         (SYOW, YW, YB, 24, 7, 18, 5, 'MSG_K5', cols(0, 0, 3, 1), 32),
         (N['TOAD'][2], N['TOAD'][0], N['TOAD'][1], 1, 22, 4, 2, 'MSG_K6', cols(3, 3, 1, 0), 14),
         (N['MAG'][2], N['MAG'][0], N['MAG'][1], 1, 20, 5, 8, 'MSG_K7', cols(2, 1, 2, 1), 14),
         (N['SNAKE'][2], N['SNAKE'][0], N['SNAKE'][1], 2, 8, 9, 0, 'MSG_K8', cols(3, 1, 3, 1), 16),
         (N['SPIDER'][2], N['SPIDER'][0], N['SPIDER'][1], 1, 18, 5, 0, 'MSG_K9', cols(3, 3, 2, 1), 14),
         (N['DINGO'][2], N['DINGO'][0], N['DINGO'][1], 3, 18, 8, 0, 'MSG_K10', cols(3, 0, 3, 1), 20),
         (SI, IH, IH, 0, 0, 0, 0, 'MSG_BLANK', 0, 0), (SI, IA, IA, 0, 0, 0, 0, 'MSG_BLANK', 0, 0), (SI, IK, IK, 0, 0, 0, 0, 'MSG_BLANK', 0, 0),
         (SI, IO, IO, 0, 0, 0, 0, 'MSG_BLANK', 0, 0), (SI, IM, IM, 0, 0, 0, 0, 'MSG_BLANK', 0, 0)]
for nm, fl in (('DRUM', 32), ('LAMP', 16), ('SHRUB', 32), ('TERMITE', 32), ('CART', 32), ('STUMP', 32), ('REEDS', 0), ('BONES', 0)):
    TYPES.append((D[nm][1], D[nm][0], D[nm][0], 0, 0, 0, fl, 'MSG_BLANK', 0, 0))
tt = []
for st, f0, f1, hp, sp, bite, fl, msg, pc, pn in TYPES:
    m = syms[msg]
    tt += [st & 255, st >> 8, f0 & 255, f0 >> 8, f1 & 255, f1 >> 8, hp, sp, bite, fl, m & 255, m >> 8, pc, pn]
blob('TYPES', tt)
syms.update(NENEMY=10, T_HEALTH=11, T_AMMO=12, T_KEY=13, T_OPAL=14, T_MAP=15, DECOR=16)
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
    a, bank = art(None, out); return blob(name, [6 | 0x80 | bank, hh, a & 255, a >> 8])
gunrec('GUN0', GUN); syms['GUNH'] = len(GUN)
gunrec('GUN1', [("".join(f if f != '.' else g for f, g in zip(FLASH[y], GUN[y])) if y < len(FLASH) else GUN[y]) for y in range(len(GUN))])

# ---- the world ---------------------------------------------------------------------------------
# '#' wall A, 'C' wall B, 'W' wall C, 'D' door, 'X' way out, 'L' locked door, 'S' switch, 'G' gate,
# '%' cracked wall (secret), '.' floor, 'P' start
# b bear, v bat, B Big Fella, U Bunyip, Y Yowie, t toad, g magpie, n snake, s spider, d dingo
# h Vegemite, a ammo, k key, o opal, m map
# furniture: r drum, l lamp, j shrub, q termite mound, c mine cart, u stump, e reeds, x bones
AREAS = [
 dict(name="THE HOMESTEAD", theme='STATION', known=1, exits=[1], rows=[
  "################",
  "#P...#..lo#.g..#",
  "#....#....#.b..#",
  "#....D....D..r.#",
  "#.ra.#.t..#....#",
  "###D####%###D###",
  "#....#..o..#..g#",
  "#.CC.#.....#.h.#",
  "#.CC.#######...#",
  "#l...D....l....#",
  "#.b..#..CCC..b.#",
  "#..t.#..C.C....#",
  "#WWWW#..r.t....#",
  "#..o%....g...r.#",
  "#...#....b.....X",
  "################"]),
 dict(name="THE BUSH TRACK", theme='BUSH', known=1, exits=[0, 2, 3], rows=[
  "################",
  "#...q.#..j...g.#",
  "X.....#..v.....#",
  "#.....D.....CC.#",
  "#..C.b#.n...CC.#",
  "#..C..###D######",
  "#j......#.b..q.#",
  "##.###..#......X",
  "#....#..%..o...#",
  "#.o.n#..#.gh...#",
  "#....#..########",
  "#.a..D....n....#",
  "###L###..v..CC.#",
  "X.....#.....CC.#",
  "#....b#.qb..o.j#",
  "################"]),
 dict(name="GUM TREE MAZE", theme='BUSH', known=0, exits=[1], rows=[
  "################",
  "#m#.....#..g..o#",
  "#.#.###.#.###..#",
  "#.#.#...#...#..#",
  "#...#.#####.#.##",
  "###.#.#.n.#.#..#",
  "#...#...#.#.##.#",
  "X.###.#.#.#....#",
  "#.....#.#.####.#",
  "####.##.#..n.#.#",
  "#..#.#..####.#.#",
  "#.##.#.##..#.#.#",
  "#.#..#.n..##.#.#",
  "#.#.#####.#..#.#",
  "#o..g.v...#k.b.#",
  "################"]),
 dict(name="THE OLD MINE", theme='MINE', known=0, exits=[1, 4], rows=[
  "################",
  "#..l.WW..c.#...#",
  "X....WW..b.#.o.#",
  "#......s...#.l.#",
  "#.WW...WW..##D##",
  "#.WW.b.WW..s...#",
  "#..r.......WW..#",
  "####D#####.WW..#",
  "#..l.#.....v...#",
  "#.m..#..WWWGWWWW",
  "#s...#..W.b.s.h#",
  "#..b.#..W......#",
  "#....#..W.WWWW.#",
  "##S###..W.W..%.#",
  "#a..s...W.Wo.W.X",
  "################"]),
 dict(name="BIG FELLA'S DEN", theme='MINE', known=1, exits=[3, 5], rows=[
  "################",
  "#.....#..l..l..#",
  "X..a..D........#",
  "#.....#..W..W..#",
  "#.h...#.x....x.#",
  "###D###...B....#",
  "#.s...#........#",
  "#..o..#..W..W..#",
  "#...c.#.s....s.#",
  "#.....#######G##",
  "#.b...#.....#..#",
  "#...s.#..o..#..#",
  "#.....%.....#..#",
  "#.c...#..x..#..#",
  "#..a..#.....#..X",
  "################"]),
 dict(name="THE BILLABONG", theme='SWAMP', known=0, exits=[4, 6], rows=[
  "################",
  "#....te#..v....#",
  "X..CC..#.CC.uCC#",
  "#..CC..D.CC..t.#",
  "#....v.#....b..#",
  "#......###L#####",
  "##D#####.......#",
  "#e...n.#.CC.v..#",
  "#.CC...#.CC...u#",
  "#.CC.b.#.b.WWt.#",
  "#..t...#...WW.o#",
  "#.k..m.#.t.....#",
  "####%###.n.....#",
  "#.o.h..#e......#",
  "#......#..a....X",
  "################"]),
 dict(name="BUNYIP'S POOL", theme='SWAMP', known=1, exits=[5, 7], rows=[
  "################",
  "#....e#e.....e.#",
  "X.....D...CC...#",
  "#..h..#...CC.t.#",
  "#.....#.t......#",
  "#..a..#.CC..U..#",
  "##D####.CC.....#",
  "#..n..#......u.#",
  "#.o...#.u.CC...#",
  "#....n#...CC.t.#",
  "#..v..#........#",
  "#e....######G###",
  "#.....#.v.t...o#",
  "#..a.t#...e....#",
  "#.....#........X",
  "################"]),
 dict(name="THE RIDGE", theme='RIDGE', known=0, exits=[6, 8], rows=[
  "################",
  "#.....#.v...#.o#",
  "X.###.#.###.#..#",
  "#.#x..#...#.#L##",
  "#.#.#####n#....#",
  "#.#..b..#.####n#",
  "#.#####.#..d.#.#",
  "#m....#...k..#.#",
  "#####G###S######",
  "#......j....d..#",
  "#.WW.qb...WW...#",
  "#.WW......WWj..#",
  "#...d..v.x.....#",
  "#..a....n..h...#",
  "#..x.......o...X",
  "################"]),
 dict(name="YOWIE'S LAIR", theme='LAIR', known=1, exits=[7, 255], rows=[
  "################",
  "#.....#..l...l.#",
  "X..h..D.u....d.#",
  "#.....#..WW....#",
  "#..a..#..WW.Y..#",
  "###D###x.......#",
  "#.....#....WW.x#",
  "#..o.d#.s..WW..#",
  "#.....D......s.#",
  "#.b...#######G##",
  "#..s..#..x....v#",
  "#..a..#.u.....o#",
  "#.....#.......h#",
  "#.d...#..l.....#",
  "#..v..#........X",
  "################"])]
assert len(AREAS) == NAREA
CELL = {'#': 1, 'C': 2, 'D': 3, 'X': 4, 'W': 5, 'L': 6, 'S': 7, 'G': 9, '%': 10}
OBJC = {'b': 1, 'v': 2, 'B': 3, 'U': 4, 'Y': 5, 't': 6, 'g': 7, 'n': 8, 's': 9, 'd': 10,
        'h': 11, 'a': 12, 'k': 13, 'o': 14, 'm': 15,
        'r': 16, 'l': 17, 'j': 18, 'q': 19, 'c': 20, 'u': 21, 'e': 22, 'x': 23}
SOLIDDEC = {16, 18, 19, 20, 21}
DIRS = {(1, 0): 0, (0, 1): 1, (-1, 0): 2, (0, -1): 3}
WORLD = []
for ai, A in enumerate(AREAS):
    rows = A['rows']; assert len(rows) == 16 and all(len(r) == 16 for r in rows), A['name']
    grid = [[CELL.get(ch, 0) for ch in r] for r in rows]
    for i in range(16):
        for (x, y) in ((i, 0), (i, 15), (0, i), (15, i)): assert grid[y][x] in (1, 2, 4, 5), (A['name'], x, y)
    objs = [(OBJC[ch], x, y) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch in OBJC]
    assert len(objs) <= 32, A['name']
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
        if t <= 10 and max(abs(x-ent[0]), abs(y-ent[1])) <= 3:
            problems.append('%s: creature %d at %d,%d too close to the way in at %d,%d' % (AREAS[tgt]['name'], t, x, y, *ent))
for t, x, y in WORLD[0]['objs']:
    if t <= 10 and max(abs(x-1), abs(y-1)) <= 3: problems.append('start: creature at %d,%d' % (x, y))
# furniture must not cut anything off: everything stays reachable with blocking furniture in place
for ai, A in enumerate(AREAS):
    W = WORLD[ai]; g = W['grid']
    solid = {(x, y) for t, x, y in W['objs'] if t in SOLIDDEC}
    starts = [ent for (a0, c), (t, ent, f) in EXITS.items() if t == ai] + ([(1, 1)] if ai == 0 else [])
    seen = set(starts); todo = list(starts)
    while todo:
        x, y = todo.pop()
        for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
            if (nx, ny) not in seen and g[ny][nx] in (0, 3, 6, 9, 10) and (nx, ny) not in solid:
                seen.add((nx, ny)); todo.append((nx, ny))
    for t, x, y in W['objs']:
        if t < 16 and (x, y) not in seen: problems.append('%s: thing %d at %d,%d cut off' % (A['name'], t, x, y))
    for y in range(16):
        for x in range(16):
            if g[y][x] in (4, 7) and not any(n in seen for n in ((x+1, y), (x-1, y), (x, y+1), (x, y-1))):
                problems.append('%s: exit or switch at %d,%d cut off' % (A['name'], x, y))
if problems: raise SystemExit('\n'.join(sorted(set(problems))))
syms['NAREA'] = NAREA
(sx, sy), = [(x, y) for y, r in enumerate(AREAS[0]['rows']) for x, ch in enumerate(r) if ch == 'P']
syms['STARTCELL'] = sy*16+sx; syms['STARTANG'] = 0
NOPALS = sum(1 for W in WORLD for o in W['objs'] if o[0] == 14)
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

def gtune(seq):
    out = []
    for n in seq:
        if n == '-': out += [0, 0, 0]
        else: f = freq(n); out += [count(f) & 255, count(f) >> 8, 4]
    return out + [0xFF, 0xFF]
blob('GTUNE', gtune(['E4', '-', '-', 'E4', 'G4', 'E4', '-', '-', 'D4', '-', '-', 'D4', 'F4', 'D4', '-', '-',
                     'E4', '-', '-', 'E4', 'G4', 'A4', '-', '-', 'B4', '-', 'A4', '-', 'G4', '-', '-', '-']))

# ---- the title logo: chunky bevelled metal letters on an arch, with slime drips (lives in the high bank) ----
BIG = {
 'D': ["#########..", "##########.", "###....####", "###.....###", "###.....###", "###.....###", "###.....###", "###....####", "##########.", "#########.."],
 'R': ["#########..", "##########.", "###....####", "###.....###", "###....####", "#########..", "###...###..", "###....###.", "###.....###", "###.....###"],
 'O': ["..#######..", ".#########.", "####...####", "###.....###", "###.....###", "###.....###", "###.....###", "####...####", ".#########.", "..#######.."],
 'P': ["#########..", "##########.", "###....####", "###.....###", "###....####", "##########.", "#########..", "###........", "###........", "###........"],
 'B': ["#########..", "##########.", "###....####", "###....###.", "#########..", "##########.", "###.....###", "###....####", "##########.", "#########.."],
 'E': ["###########", "###########", "###........", "###........", "########...", "########...", "###........", "###........", "###########", "###########"],
 'A': ["...#####...", ".#########.", "####...####", "###.....###", "###.....###", "###########", "###########", "###.....###", "###.....###", "###.....###"]}
SMALL = {
 '3': ["######.", "#######", ".....##", "..####.", "..####.", ".....##", "#######", "######."],
 'D': ["######.", "#######", "##...##", "##...##", "##...##", "##...##", "#######", "######."]}
LGH = 30
def make_logo():
    W = 128; L = [[0]*W for _ in range(LGH)]
    word = "DROPBEAR"; gw = 11; gap = 2; width = len(word)*gw+(len(word)-1)*gap; ox = (W-width)//2
    base = 15                                       # bottom row of the big letters
    for k, ch in enumerate(word):
        x0 = ox + k*(gw+gap)
        for x in range(gw):
            X = x0+x; sc = 1 + 0.55*((X-63.5)/(width/2))**2   # taller towards the ends
            hgt = int(round(10*sc))
            for yy in range(hgt):
                sy = 9 - int(yy/sc)
                if 0 <= sy < 10 and BIG[ch][sy][x] == '#': L[base-yy][X] = 1
    sw = 7; sox = (W-(2*sw+2))//2
    for k, ch in enumerate("3D"):
        for y, row in enumerate(SMALL[ch]):
            for x, c in enumerate(row):
                if c == '#': L[19+y][sox+k*(sw+2)+x] = 2
    pic = [[2]*W for _ in range(LGH)]
    for y in range(LGH):                               # extrusion, down and to the right
        for x in range(W):
            if L[y][x]:
                for dx, dy in ((1, 1), (1, 2), (0, 2)):
                    if y+dy < LGH and x+dx < W and not L[y+dy][x+dx]: pic[y+dy][x+dx] = 0
    for y in range(LGH):
        for x in range(W):
            v = L[y][x]
            if not v: continue
            edge = y < 2 or not L[y-1][x] or not L[y-2][x]
            if v == 1: pic[y][x] = 1 if edge else 3
            else: pic[y][x] = 3 if edge else 1
    for k in (0, 2, 5, 7):                             # slime drips
        X = ox + k*(gw+gap) + (2 if k % 2 else 8)
        bot = max(y for y in range(LGH) if L[y][X])
        for y in range(bot+3, bot+3+2+(k % 3)): pic[y][X] = 0
    return [sum(pic[y][x*4+i] << (6-2*i) for i in range(4)) for y in range(LGH) for x in range(32)], pic
logo_bytes, LOGO_PIC = make_logo()
blob('LOGO2', logo_bytes, 1, 'hi'); syms['LOGOLEN'] = len(logo_bytes)

# ---- title music: three channels, slow and ominous, with a cheeky ending ----
SR = 3546900/134.4
def per(f): return max(2, min(255, round(SR/(2*f))))
N = {'A1': 55.0, 'Bb1': 58.27, 'E2': 82.41, 'G#2': 103.83, 'A2': 110.0, 'Bb2': 116.54, 'B2': 123.47, 'C3': 130.81,
     'Db3': 138.59, 'D#3': 155.56, 'E3': 164.81, 'F3': 174.61, 'F#3': 185.0, 'G3': 196.0, 'G#3': 207.65, 'A3': 220.0,
     'Bb3': 233.08}
BEAT = 0.5
v_bass = []; v_mid = []; v_top = []
for bar in range(20):                          # heartbeat: dum-dum ... dum-dum
    t = bar*2; v_bass += [(t, .25, 'A1'), (t+.5, .25, 'A1')]
for k in range(8): v_bass.append((40+k*.5, .25, 'A1' if k % 2 == 0 else 'Bb1'))
for k, n in enumerate(['A2', 'Bb2', 'A2', 'G#2']): v_mid.append((8+k*4, 3.5, n))
for k, n in enumerate(['C3', 'Db3', 'C3', 'B2']): v_mid.append((24+k*4, 3.5, n))
for k, n in enumerate(['E3', 'F3', 'E3', 'D#3', 'A3', 'G#3', 'G3', 'F#3']): v_top.append((24+k*2, 1.75, n))
v_mid.append((40, 3.8, 'E3')); v_top.append((40, 3.8, 'Bb3'))          # the stinger: a tritone
v_top += [(45, .55, 'Bb2'), (45.7, .55, 'A2'), (46.4, 1.6, 'G#2')]      # ...and a sad trombone
v_bass.append((46.4, 1.6, 'E2'))
END = 48.5; STEP = 1/20
def at(voice, t):
    for t0, d, n in voice:
        if t0 <= t < t0+d: return n
    return None
rows = []
t = 0.0
while t < END-1e-9:
    key = (at(v_top, t), at(v_mid, t), at(v_bass, t))
    if rows and rows[-1][0] == key: rows[-1][1] += STEP
    else: rows.append([key, STEP])
    t += STEP
mus = []
for (a, m, bs), d in rows:
    for n in (a, m, bs): mus += [per(N[n]) if n else 0, 0x21 if n else 0]
    loops = round(d*BEAT*SR); mus += [loops & 255, loops >> 8]
    assert loops < 0xFF00
mus += [0, 0, 0, 0, 0, 0, 0, 0xFF]
assert len(mus) <= 1024, len(mus)
blob('MUSIC', mus, 1, 'hi'); syms['MUSLEN'] = len(mus)

# ---- the gallery: each local introduces itself (built for its working copy at ACTTEX) ----
GAL = [('SPR_WALK', 'SPR_BITE', 0x08, "DROP BEAR", "I DROP OUT OF TREES.", "MOSTLY ON PURPOSE.", ('C5', 'E5', 'G5')),
       ('SPR_BAT0', 'SPR_BAT1', 0x18, "FRUIT BAT", "I ONLY CAME FOR THE MANGOES.", "THE BITING JUST HAPPENS.", ('E5', 'G5', 'B5')),
       ('SPR_TOAD0', 'SPR_TOAD1', 0x18, "CANE TOAD", "NOBODY INVITED ME.", "I STAYED ANYWAY.", ('G4', 'C5', 'E5')),
       ('SPR_MAG0', 'SPR_MAG1', 0x18, "MAGPIE", "I SWOOP. I MISS. I SWOOP AGAIN.", "IT'S A SPRING THING.", ('A5', 'C6', 'E6')),
       ('SPR_SNAKE0', 'SPR_SNAKE1', 0x08, "SNAKE", "SLOW, BUT GRUMPY ABOUT IT.", "PLEASE DON'T STEP ON ME.", ('D5', 'F5', 'A5')),
       ('SPR_SPIDER0', 'SPR_SPIDER1', 0x08, "HUNTSMAN", "I'M TOTALLY HARMLESS.", "WHY IS EVERYONE SCREAMING?", ('F5', 'A5', 'C6')),
       ('SPR_DINGO0', 'SPR_DINGO1', 0x08, "DINGO", "I ATE YOUR SANDWICH.", "AND I'D DO IT AGAIN.", ('C5', 'D#5', 'G5')),
       ('SPR_BITE', 'SPR_WALK', 0x08, "BIG FELLA", "I'M NOT FAT.", "I'M BIG BONED.", ('C4', 'D#4', 'F#4')),
       ('SPR_BUN1', 'SPR_BUN0', 0x18, "THE BUNYIP", "MOSTLY TEETH.", "SOME FEELINGS.", ('D4', 'F4', 'G#4')),
       ('SPR_YOW1', 'SPR_YOW0', 0x18, "THE YOWIE", "BLURRY IN EVERY PHOTO.", "THIS IS MY GOOD SIDE.", ('E4', 'G4', 'A#4'))]
NOTE2 = {n: 440*2**((i-9)/12) for i, n in enumerate(['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'])}
def nf(n): return NOTE2[n[:-1]]*2**(int(n[-1])-4)
LADN = {'SPR_WALK': len(BEAR_L), 'SPR_BITE': len(BEAR_L), 'SPR_BAT0': len(BAT_L), 'SPR_BAT1': len(BAT_L),
        'SPR_BUN0': len(BIG_L), 'SPR_BUN1': len(BIG_L), 'SPR_YOW0': len(BIG_L), 'SPR_YOW1': len(BIG_L)}
for nm in ('TOAD', 'MAG', 'SNAKE', 'SPIDER', 'DINGO'):
    nl = (syms['SPR_'+nm+'1']-syms['SPR_'+nm+'0'])//4 if False else None
GBASE = syms['ACTTEX']; ent = []; pages = []
poff = GBASE + 17*len(GAL) + 2
def lastrec(nm):
    t = syms[nm]; n = 0
    while mem[t+n*4+1] and n < 20:
        n += 1
        if t+n*4 >= used['main'] or mem[t+n*4+1] <= mem[t+(n-1)*4+1]: break
    return t+(n-1)*4
for f0, f1, css, name, c1, c2, notes in GAL:
    r0 = lastrec(f0); r1 = lastrec(f1)
    w = mem[r0] & 0x3F; hgt = mem[r0+1]
    pg = []
    for row, col, s_ in (centre(47, name), centre(53, c1), centre(59, c2)):
        assert col+len(s_) <= 32, s_
        a = 0x7000+row*32+col; pg += [a & 255, a >> 8] + enc(s_)
    pg += [0, 0]
    e = [r0 & 255, r0 >> 8, r1 & 255, r1 >> 8, 0x00 if name == 'MAGPIE' else 0xAA, 0, poff & 255, poff >> 8, 45-hgt, (32-w)//2, css]
    for n in notes:
        f = nf(n); c = max(4, min(255, round((CLOCK/(2*f)-130)/26))); e += [c, min(255, round(f*2*0.09))]
    ent += e; pages += pg; poff += len(pg)
gal = ent + [0, 0] + pages
assert len(gal) <= 1024, len(gal)
blob('GALL', gal, 1, 'hi'); syms['GALLLEN'] = len(gal)

# ---- where the demo starts in each area ----
dt = []
for ai in range(NAREA):
    if ai == 0: cell, face = syms['STARTCELL'], syms['STARTANG']
    else:
        (ent_, face), = [(e2, f2) for (a0, c), (t, e2, f2) in EXITS.items() if t == ai][:1]
        cell = ent_[1]*16+ent_[0]
    dt += [cell, face]
blob('DEMOTAB', dt); syms['DEMOLEN'] = 420

# ---- assemble ---------------------------------------------------------------------------------------
syms['CODEORG'] = used['main']
for k in list(syms):
    if isinstance(syms[k], int) and (k.isupper() or k.startswith('SPR')): syms[k+'_HI'] = syms[k] >> 8
syms['ZBUF_LO'] = syms['ZBUF'] & 255
code = assemble(open('dropbear.asm').read(), syms)
for a, v in code.items():
    if 0x7A00 <= a < 0x8000: lo[a-0x7A00] = v
    else: mem[a] = v
assert syms['codeend'] < 0x10000 and max(a for a in code if a < 0x7A00 or a >= 0x8000) < 0xF800
codeend = syms['codeend']; IMGEND = (codeend+255) & 0xFF00
assert IMGEND <= 0xF800, 'main RAM overflow: code ends %04X' % codeend
mem[syms['SPREND']+1] = syms['ds_ret'] & 255; mem[syms['SPREND']+2] = syms['ds_ret'] >> 8
image = bytes(mem[0x8100:IMGEND]); img1 = bytes(b1[:used['b1']-0x4000]); img3 = bytes(b3[:max(1, used['b3']-0x4000)])
imglo = bytes(lo[:used['lo']-0x7A00]); LIBADDR = syms['LIVE']+512*NAREA; imghi = bytes(hi[LIBADDR-0xB800:used['hi']-0xB800])

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
pm, worst = pack(image); p1, _ = pack(img1); p3, _ = pack(img3); plo, _ = pack(imglo); ph, _ = pack(imghi)
STUB = """
        org $8000
        di
        ld sp,$79F0
        ld a,1
        out ($37),a
        ld a,($B800)            ; is there a high bank? it must keep its own data at $B800
        ld b,a
        ld a,5
        out ($37),a
        ld a,b
        cpl
        ld ($B800),a
        ld a,1
        out ($37),a
        ld a,($B800)
        cp b
        jr nz,nomem
        ld a,($4000)            ; and a second bank at $4000
        ld b,a
        ld a,3
        out ($37),a
        ld a,b
        cpl
        ld ($4000),a
        ld a,1
        out ($37),a
        ld a,($4000)
        cp b
        jr nz,nomem
        ld a,5
        out ($37),a
        ld hl,PKH
        ld de,LIBADDR
        call unpk
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
        ld hl,PKLO
        ld de,$7A00
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
nomem:  xor a
        ld ($6800),a
        ld hl,$7000
        ld de,$7001
        ld bc,511
        ld (hl),$20
        ldir
        ld hl,NOMSG
        ld de,$7000+7*32+4
nm1:    ld a,(hl)
        or a
nm2:    jr z,nm2
        ld (de),a
        inc hl
        inc de
        jr nm1
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
NOMSG:  db NOMSGBYTES
PKH:
"""

msg = "NEEDS BENNVENN 128K RAM"
ss = dict(PKLEN=len(pm), START=syms['start'], LIBADDR=LIBADDR)
STUB = STUB.replace('NOMSGBYTES', ','.join(str(ord(c)-64 if c.isalpha() else ord(c)) for c in msg) + ',0')
tmp = dict(ss, PK1=0, PK3=0, PKLO=0, PKM=0); assemble(STUB, tmp)
ss['PKM'] = tmp['PKH']+len(ph); ss['PK1'] = ss['PKM']+len(pm); ss['PK3'] = ss['PK1']+len(p1); ss['PKLO'] = ss['PK3']+len(p3)
stub = assemble(STUB, ss)
body = bytes(stub[a] for a in range(0x8000, ss['PKH'])) + ph + pm + p1 + p3 + plo
assert ss['PKH'] <= 0x8100 and ss['PKM'] <= 0xB800, 'high-bank data must load below $B800'
assert 0x8000+len(body) < 0xFA00
# while unpacking the main image from the top of RAM, writes must never catch up with unread input
assert (0xFA00-len(pm)) - 0x8100 > worst + 8, 'unpack would overwrite its own input'
vz = b'VZF0' + b'DROPBEAR'.ljust(17, b'\0') + bytes([0xF1, 0x00, 0x80]) + body
open('DROPBEAR.VZ', 'wb').write(vz)
pickle.dump(dict(syms=syms, image=image, img1=img1, img3=img3, imglo=imglo, imghi=imghi, LIBADDR=LIBADDR, body=body, IMGEND=IMGEND, world=WORLD,
                 areas=[dict(name=A['name'], exits=A['exits'], theme=A['theme']) for A in AREAS], exits=EXITS,
                 nopals=NOPALS, preview=PREVIEW, heights=HEIGHTS), open('image.pkl', 'wb'))
if __name__ == '__main__':
    print('main RAM: data %04X-%04X, code %04X-%04X (%d bytes), %d bytes free' %
          (0x8100, syms['CODEORG'], syms['CODEORG'], codeend, codeend-syms['CODEORG'], 0xF800-codeend))
    print('SRAM bank 1 used to %04X (%d free), bank 3 to %04X (%d free), $7A00 area to %04X (%d free), high bank to %04X (%d free)' %
          (used['b1'], 0x6800-used['b1'], used['b3'], 0x6800-used['b3'], used['lo'], 0x8000-used['lo'], used['hi'], 0x10000-used['hi']))
    print('sprites: ' + ', '.join('%s %d' % (k[4:], v) for k, v in sprite_bytes.items()))
    print('packed: main %d, bank1 %d, bank3 %d, lo %d, high %d; file %d bytes, loads 8000-%04X; %d opals in the world' %
          (len(pm), len(p1), len(p3), len(plo), len(ph), len(vz), 0x8000+len(body)-1, NOPALS))
