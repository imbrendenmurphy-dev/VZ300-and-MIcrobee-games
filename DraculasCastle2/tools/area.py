# area.py - build first-person asset blobs for each castle area + reference compositor
import math
from walls import *
from tone import pick
from objects import OBJ
import materials

AREA_BUF = 0x4800
LET = {'.': -1, 'g': 0, 'y': 1, 'b': 2, 'r': 3}

# ---------------- decor designs (u 0..1 across face, v height) ----------------
def d_door(u, v, z, f):
    if not (0.18 <= u <= 0.82): return None
    top = 1.0 + 0.2 * math.sqrt(max(0, 1 - ((u - 0.5) / 0.32) ** 2))
    if v > top: return None
    if u < 0.23 or u > 0.77 or v > top - 0.06: return ('frame', 0)
    if abs(v - 0.25) < 0.04 or abs(v - 0.8) < 0.04: return ('iron', 0)
    if abs(u - 0.62) < 0.03 and abs(v - 0.55) < 0.05: return ('iron', 0)
    pu = (u - 0.23) / 0.54 * 5
    if pu % 1 < 0.15: return ('woodd', 0)
    return ('wood', 0)

def d_gate(u, v, z, f):
    if not (0.1 <= u <= 0.9): return None
    top = 1.15 + 0.18 * math.sqrt(max(0, 1 - ((u - 0.5) / 0.4) ** 2))
    if v > top + 0.05: return None
    if u < 0.14 or u > 0.86 or v > top - 0.02: return ('iron', 0)
    if abs(v - 0.5) < 0.03 or abs(v - 1.0) < 0.03: return ('iron', 0)
    bu = (u - 0.14) / 0.72 * 7
    if bu % 1 < 0.3: return ('iron', 0)
    return ('void', 0)

def d_torch(u, v, z, f):
    if 0.46 < u < 0.54 and 0.72 < v < 0.88: return ('iron', 0)
    if 0.42 < u < 0.58 and 0.86 < v < 0.9: return ('iron', 0)
    fu = (u - 0.5) / 0.07; fv = (v - 0.9) / 0.22
    if 0 <= fv <= 1 and abs(fu) < (1 - fv) * 1.1 + 0.15 * math.sin(fv * 9):
        return ('flame', 0) if abs(fu) < 0.45 * (1 - fv) + 0.1 else ('flame', 1)
    return None

def d_portrait(u, v, z, f):
    if not (0.26 <= u <= 0.74 and 0.5 <= v <= 1.18): return None
    if u < 0.31 or u > 0.69 or v < 0.55 or v > 1.13: return ('frame', 0)
    # pale aristocratic face on dark ground
    fx = (u - 0.5) / 0.1; fy = (v - 0.92) / 0.13
    if fx * fx + fy * fy < 1:
        if abs(fy + 0.05) < 0.18 and 0.25 < abs(fx) < 0.6: return ('eyes', 0)
        return ('skin', 0)
    if v < 0.82 and abs(u - 0.5) < 0.16 + (0.82 - v) * 0.6: return ('cloth', 0)
    if v > 1.0 and abs(u - 0.5) < 0.13: return ('hair', 0)
    return ('void', 0)

def d_window(u, v, z, f):
    if not (0.3 <= u <= 0.7 and 0.45 <= v): return None
    top = 1.15 + 0.18 * math.sqrt(max(0, 1 - ((u - 0.5) / 0.2) ** 2))
    if v > top: return None
    if u < 0.33 or u > 0.67 or v < 0.48 or v > top - 0.03: return ('frame', 0)
    if abs(u - 0.5) < 0.015 or abs(v - 0.85) < 0.02: return ('frame', 0)
    pane = (int((u - 0.33) / 0.085) + int((v - 0.48) / 0.12)) % 3
    return ('glass', pane)

def d_stairs(u, v, z, f):
    if not (0.2 <= u <= 0.8): return None
    top = 1.0 + 0.18 * math.sqrt(max(0, 1 - ((u - 0.5) / 0.3) ** 2))
    if v > top: return None
    if u < 0.25 or u > 0.75 or v > top - 0.05: return ('frame', 0)
    step = int(v / 0.12)
    if (v % 0.12) < 0.03 and v < 0.6: return ('frame', 0)
    return ('void', 0)

def d_plaque(u, v, z, f):
    if 0.3 < u < 0.7 and 0.7 < v < 0.95:
        if u < 0.33 or u > 0.67 or v < 0.73 or v > 0.92: return ('frame', 0)
        if (int(u * 40) + int(v * 30)) % 3 == 0 and 0.75 < v < 0.9: return ('void', 0)
        return ('plaque', 0)
    return None

DECORS = {'door': d_door, 'gate': d_gate, 'torch': d_torch, 'portrait': d_portrait,
          'window': d_window, 'stairs': d_stairs, 'plaque': d_plaque}

# extra ramps every material needs for decor
G, Y, B, R = 0, 1, 2, 3
DECOR_RAMPS = {
    'frame': [(Y, R, .5), (R, R, 0), (R, B, .5), (B, B, 0), (B, B, 0)],
    'iron':  [(Y, B, .5), (Y, B, .75), (B, B, 0), (B, B, 0)],
    'wood':  [(R, R, 0), (R, B, .25), (R, B, .5), (B, B, 0)],
    'woodd': [(R, B, .5), (R, B, .75), (B, B, 0), (B, B, 0)],
    'void':  [(B, B, 0), (B, B, 0)],
    'flame': [(Y, Y, 0), (R, R, 0)],
    'skin':  [(Y, Y, 0), (Y, B, .25), (Y, B, .5), (B, B, 0)],
    'eyes':  [(R, R, 0), (R, B, .5), (B, B, 0)],
    'cloth': [(R, B, .25), (R, B, .5), (B, B, 0), (B, B, 0)],
    'hair':  [(B, B, 0), (B, B, 0)],
    'glass': [(G, B, .5), (R, B, .25), (Y, B, .5), (B, B, 0)],
    'plaque': [(Y, Y, 0), (Y, R, .5), (R, B, .5), (B, B, 0)],
}
# glass uses idx = pane colour (no fog shift beyond ramp end) -> handled by shade clamp

# ---------------- area definitions ----------------
class AreaDef:
    def __init__(self, name, mat, decors, objects, bgdir):
        self.name = name; self.mat = mat; self.decors = decors; self.objects = objects; self.bgdir = bgdir

AREAS = [
    AreaDef('grounds', materials.Grounds(), ['gate', 'door', 'torch'], ['bones', 'grave', 'keeper', 'chest', 'chest_open', 'angel'], [1, 0, 0, 0]),
    AreaDef('hall', materials.Hall(), ['door', 'torch', 'portrait', 'window', 'plaque'], ['armour', 'chest', 'chest_open', 'angel', 'bones', 'gargoyle'], [0, 0, 0, 0]),
]

# ---------------- encoding ----------------
def masked_sprite(pix):
    """pix: dict (x,y)->c (0..3). returns bytes: xb, y, wb, h, then (mask,data) pairs"""
    if not pix: return None
    xs = [p[0] for p in pix]; ys = [p[1] for p in pix]
    xb0 = min(xs) // 4; xb1 = max(xs) // 4 + 1; y0 = min(ys); y1 = max(ys) + 1
    out = bytearray([xb0, y0, xb1 - xb0, y1 - y0])
    for y in range(y0, y1):
        for xb in range(xb0, xb1):
            m = 0; dt = 0
            for i in range(4):
                c = pix.get((xb * 4 + i, y))
                m <<= 2; dt <<= 2
                if c is None: m |= 3
                else: dt |= c
            out += bytes([m, dt])
    return bytes(out)

def rect_bytes(pix, x0, x1, y0, y1, fill=2):
    out = bytearray()
    for y in range(y0, y1):
        for xb in range(x0 // 4, x1 // 4):
            v = 0
            for i in range(4):
                v = (v << 2) | (pix.get((xb * 4 + i, y), fill) & 3)
            out.append(v)
    return bytes(out)

def obj_sprite(name, d):
    art = OBJ[name]; h = len(art); w = len(art[0])
    scale = {1: 1.0, 2: 27.2 / 42.67, 3: 19.43 / 42.67}[d]
    floor = {1: 42, 2: 36, 3: 33}[d]
    nw = max(1, int(round(w * scale))); nh = max(1, int(round(h * scale)))
    pix = {}
    x0 = CX - nw // 2
    for y in range(nh):
        for x in range(nw):
            sx = min(w - 1, int((x + 0.5) / scale)); sy = min(h - 1, int((y + 0.5) / scale))
            c = LET[art[sy][sx]]
            if c < 0: continue
            px, py = x0 + x, floor - nh + y
            if d >= 2 and c != 2:
                # distance darkening
                if d == 3 and (px + py) & 1: c = 2
                if d == 2 and (px & 1) and (py & 1): c = 2
            pix[(px, py)] = c
    return pix

def build_area(ad, verbose=False):
    """returns (part1, part2, ref): part1 -> bank 3 @ $4000, part2 -> bank 1 @ $4000"""
    mat = ad.mat
    mat.ramps = dict(mat.ramps); mat.ramps.update(DECOR_RAMPS)
    BASE = 0x4000
    BASE2 = 0xC800       # part 2 lives in main RAM (the DOS keeps SRAM bank 1)
    p1 = bytearray(12)
    def put16(buf, off, v): buf[off] = v & 255; buf[off + 1] = v >> 8
    ref = {'bg': {}, 'walls': {}, 'decor': {}, 'obj': {}}
    for v in sorted(set(ad.bgdir)):
        pix = render_background(mat, None, variant=v)
        ref['bg'][v] = (BASE + len(p1), pix)
        for y in range(VH):
            for xb in range(20):
                b = 0
                for i in range(4): b = (b << 2) | pix[y][xb * 4 + i]
                p1.append(b)
    for i in range(4): put16(p1, i * 2, ref['bg'][ad.bgdir[i]][0])
    ref['bg'] = {v: pix for v, (a_, pix) in ref['bg'].items()}
    for ki, kind in enumerate('AB'):
        mat.kind = kind
        put16(p1, 8 + ki * 2, BASE + len(p1))
        toff = len(p1); p1 += bytes(18)
        sides = {}; fronts = {}
        for si, slot in enumerate(SIDE_SLOTS):
            pix = render_side(mat, None, *slot); sides[slot] = pix
            put16(p1, toff + si * 2, BASE + len(p1)); p1 += masked_sprite(pix)
        for fi, d in enumerate((1, 2, 3)):
            pix = render_front(mat, None, d); fronts[d] = pix
            y0, y1 = face_rows(d)
            put16(p1, toff + 12 + fi * 2, BASE + len(p1))
            p1 += rect_bytes(pix, CX - WB[d] // 2, CX + WB[d] // 2, y0, y1)
        ref['walls'][kind] = (sides, fronts)
    p2 = bytearray(4)
    put16(p2, 0, BASE2 + len(p2))
    dt = len(p2); p2 += bytes(12 * len(ad.decors))
    mat.kind = 'A'
    for di, name in enumerate(ad.decors):
        fn = DECORS[name]; spr = {}
        for fi, d in enumerate((1, 2, 3)):
            pix = render_front(mat, None, d, decor=fn, only_decor=True); spr[('f', d)] = pix
            if pix: put16(p2, dt + di * 12 + fi * 2, BASE2 + len(p2)); p2 += masked_sprite(pix)
        for si, slot in enumerate(((0, -1), (1, -1), (2, -1))):
            pix = render_side(mat, None, *slot, decor=fn, only_decor=True); spr[('s', slot[0])] = pix
            if pix: put16(p2, dt + di * 12 + 6 + si * 2, BASE2 + len(p2)); p2 += masked_sprite(pix)
        ref['decor'][di + 1] = spr
    put16(p2, 2, BASE2 + len(p2))
    ot = len(p2); p2 += bytes(6 * len(ad.objects))
    for oi, name in enumerate(ad.objects):
        spr = {}
        for fi, d in enumerate((1, 2, 3)):
            pix = obj_sprite(name, d); spr[d] = pix
            put16(p2, ot + oi * 6 + fi * 2, BASE2 + len(p2)); p2 += masked_sprite(pix)
        ref['obj'][oi + 1] = spr
    assert len(p1) <= 0x1C00 and len(p2) <= 0x2000, (len(p1), len(p2))
    if verbose: print(ad.name, 'part1', len(p1), 'part2', len(p2))
    return bytes(p1), bytes(p2), ref

# ---------------- reference compositor (mirrors the Z80 renderer) ----------------
FRONT_LAT = {1: (-1, 1, 0), 2: (-1, 1, 0), 3: (-2, 2, -1, 1, 0)}
def compose(ref, view, bgv=0, objs=None):
    """view: dict (d,l) -> ('A'|'B', decor_id) for solid cells ; objs: dict d -> obj id (l=0)"""
    pix = [row[:] for row in ref['bg'][bgv]]
    def put(x, y, c):
        if 0 <= x < VW and 0 <= y < VH: pix[y][x] = c
    for d in (3, 2, 1, 0):
        for l in (-2, 2, -1, 1, 0):
            cell = view.get((d, l))
            if cell:
                kind, dec = cell
                sides, fronts = ref['walls'][kind]
                if d >= 1 and l in FRONT_LAT[d]:
                    for (x, y), c in fronts[d].items(): put(x + l * WB[d], y, c)
                    if dec and dec in ref['decor'] and ref['decor'][dec][('f', d)]:
                        spr = ref['decor'][dec][('f', d)]
                        xs = [p[0] + l * WB[d] for p in spr]
                        if min(xs) >= 0 and max(xs) < VW:
                            for (x, y), c in spr.items(): put(x + l * WB[d], y, c)
                if l != 0 and (d, -abs(l)) in sides:
                    for (x, y), c in sides[(d, -abs(l))].items(): put(x if l < 0 else VW - 1 - x, y, c)
                    if dec and dec in ref['decor'] and abs(l) == 1 and d <= 2 and ref['decor'][dec][('s', d)]:
                        for (x, y), c in ref['decor'][dec][('s', d)].items(): put(x if l < 0 else VW - 1 - x, y, c)
            elif l == 0 and d >= 1 and objs and objs.get(d):
                for (x, y), c in ref['obj'][objs[d]][d].items(): put(x, y, c)
    return pix

if __name__ == '__main__':
    from gfx import show
    from PIL import Image
    for ad in AREAS:
        p1, p2, ref = build_area(ad, True)
        views = [
            ({(0, -1): ('A', 0), (0, 1): ('A', 0), (1, -1): ('A', 4), (1, 1): ('B', 0), (2, -1): ('A', 0), (2, 1): ('A', 0), (3, 0): ('B', 1)}, {2: 1}),
            ({(0, -1): ('B', 3), (0, 1): ('A', 0), (1, 0): ('B', 2)}, {}),
            ({(0, -1): ('A', 0), (0, 1): ('A', 0), (1, -1): ('A', 0), (1, 1): ('A', 0), (2, -1): ('B', 0), (2, 1): ('B', 0), (3, 0): ('A', 1)}, {1: 3}),
            ({(0, -1): ('A', 0), (1, -1): ('A', 0), (2, -1): ('A', 0), (3, -1): ('A', 0), (3, -2): ('A', 0), (2, -2): ('A', 0), (0, 1): ('A', 0)}, {3: 2}),
        ]
        ims = [show(compose(ref, v, max(ref['bg'])) if i == 3 else compose(ref, v, 0, o), 0, 4) for i, (v, o) in enumerate(views)]
        ims[3] = show(compose(ref, views[3][0], max(ref['bg']), views[3][1]), 0, 4)
        W = Image.new('RGB', (ims[0].width * 2 + 8, ims[0].height * 2 + 8))
        for i, im in enumerate(ims): W.paste(im, ((i % 2) * (im.width + 8), (i // 2) * (im.height + 8)))
        W.save('/home/claude/dc2/shots/area_%s.png' % ad.name)
