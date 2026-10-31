"""The five stages of the Grand Tour: road palettes, panoramas, track layout,
scenery placement, gantries; cut into SD sections and packed as DAT files.
Each section file = chunks (map, dest, length, data) for load_dat."""
import math, os, random, struct, sys
sys.path.insert(0, os.path.dirname(__file__))
from track import Track
import sprites, pano as panomod

B = os.path.join(os.path.dirname(__file__), '..', 'build')
OUT = os.path.join(os.path.dirname(__file__), '..', 'release')
TRK = 0xB800; OBJLIST = 0xC000; GANLIST = 0xC340; SECHDR = 0xC3C0
PANO = 0xC400; SCENERY = 0xCC00
MAXSEG = 512; LOOK = 44
G_START, G_CHECK, G_SECTION, G_FINISH = 0, 1, 2, 3
L_MODE, L_CSS = 0x08, 0x10

def rep(c): return c * 0x55     # 2-bit colour -> full byte
def dith(a, b): return (a << 6) | (b << 4) | (a << 2) | b

LEGS = [
  dict(name='SUNSET COAST', css=0, time=62, traffic=4,
       hud=(rep(1), rep(2)), big=(rep(1), rep(3)), msg=(rep(1), rep(3)), gan=(rep(3), rep(1), rep(3)),
       pal=[rep(0), rep(0), rep(3), rep(2), rep(2), 0,   dith(0, 1) , dith(1, 0), rep(1), rep(2), rep(1), 1],
       tun=[rep(3), rep(3), rep(3), rep(2), rep(2), 0,   dith(3, 1), dith(1, 3), rep(1), rep(2), rep(1), 1],
       roof=(rep(3), dith(3, 1))),
  dict(name='RED CENTRE', css=0, time=60, traffic=3,
       hud=(rep(1), rep(2)), big=(rep(1), rep(3)), msg=(rep(1), rep(0)), gan=(rep(1), rep(3), rep(1)),
       pal=[rep(3), rep(3), rep(1), rep(2), rep(2), 0,   dith(3, 1), dith(1, 3), rep(0), rep(2), rep(1), 1],
       tun=[rep(3), rep(3), rep(3), rep(2), rep(2), 0,   dith(3, 2), dith(2, 3), rep(1), rep(2), rep(1), 1],
       roof=(rep(3), dith(3, 2))),
  dict(name='RAINFOREST RIDGE', css=0, time=62, traffic=4,
       hud=(rep(1), rep(2)), big=(rep(1), rep(3)), msg=(rep(1), rep(3)), gan=(rep(3), rep(1), rep(3)),
       pal=[rep(0), dith(0, 1) & 0x3C | 0x00, rep(3), rep(2), rep(2), 0, dith(0, 1), rep(0), rep(1), rep(2), rep(1), 1],
       tun=[rep(0), rep(0), rep(3), rep(2), rep(2), 0,   dith(0, 3), dith(3, 0), rep(1), rep(2), rep(1), 1],
       roof=(rep(0), dith(0, 3))),
  dict(name='SNOWY RANGE', css=1, time=64, traffic=3,
       hud=(rep(0), rep(2)), big=(rep(0), rep(3)), msg=(rep(0), rep(2)), gan=(rep(3), rep(0), rep(3)),
       pal=[rep(0), rep(0), rep(3), rep(2), rep(2), 0,   dith(0, 1), dith(1, 0), rep(1), rep(2), rep(0), 1],
       tun=[rep(3), rep(3), rep(3), rep(2), rep(2), 0,   dith(3, 2), dith(2, 3), rep(1), rep(2), rep(0), 1],
       roof=(rep(3), dith(3, 2))),
  dict(name='HARBOUR LIGHTS', css=1, time=64, traffic=5,
       hud=(rep(3), rep(2)), big=(rep(0), rep(3)), msg=(rep(3), rep(2)), gan=(rep(1), rep(3), rep(0)),
       pal=[dith(2, 1), dith(1, 2), rep(3), rep(2), rep(2), 0, dith(1, 2), dith(2, 1), rep(0), rep(2), rep(3), 1],
       tun=[rep(1), rep(1), rep(3), rep(2), rep(2), 0,   dith(1, 3), dith(3, 1), rep(0), rep(2), rep(3), 1],
       roof=(rep(1), dith(1, 3))),
]

# ------------------------------------------------------------------ track layouts
def deco(t, start, end, leg, r):
    """roadside scenery + chevrons on the outside of bends"""
    S = sprites.LEG_SCENERY[leg]
    idx = {n: i for i, n in enumerate(S)}
    s = start
    while s < end:
        if t.flag[s] & 1 == 0:
            c = t.curv[s]
            if abs(c) >= 25 and s % 4 == 0 and 'chevl' in idx:
                # chevrons on the outside: bend right (+) -> left side, pointing right
                side = -1 if c > 0 else 1
                t.obj(s, idx['chevr' if c > 0 else 'chevl'], side * 82)
            elif s % 7 == 0:
                side = 1 if r.random() < 0.5 else -1
                pick = r.random()
                big = [n for n in S if n in sprites.SOLID and not n.startswith('chev')]
                small = [n for n in S if n not in sprites.SOLID]
                nm = r.choice(big) if pick < 0.6 and big else (r.choice(small) if small else S[0])
                if nm == 'lighthouse' and r.random() < 0.85: nm = 'palm'
                if nm == 'tower' and r.random() < 0.3: nm = 'lamp'
                x = 105 + r.randint(0, 40)
                if nm in ('lamp', 'lampr'):
                    nm = 'lamp' if side > 0 else 'lampr'; x = 90
                t.obj(s, idx[nm], side * x)
                if r.random() < 0.25:
                    nm2 = r.choice(small or big)
                    t.obj(s, idx[nm2], -side * (110 + r.randint(0, 30)))
            if s % 60 == 30 and 'sign' in idx:
                t.obj(s, idx['sign'], (1 if (s // 60) % 2 else -1) * 125)
        s += 1

def leg_track(leg):
    r = random.Random(1000 + leg)
    t = Track(LEGS[leg]['name'])
    t.S(3); t.G(G_START); t.S(9)
    if leg == 0:      # coast: sweeping bends, a headland tunnel, cliff-top crests
        t.S(30); t.C(50, 22); t.S(20); t.H(50, 1600, -18); t.C(40, -34)
        t.H(40, -1600); t.S(20); t.C(60, 40); t.S(16)
        t.G(G_CHECK)
        t.C(30, -20); t.H(30, 900); t.T(50, 0); t.H(30, -900); t.C(50, 30)
        t.S(30); t.C(40, -45); t.C(40, 45); t.S(20)
        sec1 = len(t.curv); t.G(G_SECTION)
        t.S(20); t.H(60, 2400, 12); t.H(40, -1200); t.C(40, -50); t.H(30, -1200)
        t.S(40); t.C(70, 26); t.C(30, -30); t.S(20); t.H(40, 1500, 20)
        t.H(40, -1500, -20); t.S(30); t.C(50, 38); t.S(14)
        sec2 = len(t.curv); t.G(G_SECTION)
        t.S(30); t.C(40, -28); t.T(40, 18); t.S(20); t.C(60, -40); t.H(50, 1800)
        t.H(30, -1800, 30); t.S(40); t.C(30, 20); t.C(30, -20); t.S(40)
        t.G(G_FINISH)
    elif leg == 1:    # outback: long straights, dips, the odd sharp kink
        t.S(60); t.H(30, 700); t.H(30, -700); t.S(50); t.C(30, 30); t.S(60)
        t.H(25, -500); t.H(25, 500); t.S(40); t.C(40, -35); t.S(30)
        t.G(G_CHECK)
        t.S(50); t.H(20, 600); t.H(20, -600); t.H(20, 600); t.H(20, -600)
        t.S(40); t.C(30, 50); t.S(40)
        sec1 = len(t.curv); t.G(G_SECTION)
        t.S(70); t.C(40, -25); t.S(50); t.H(40, 1400); t.H(40, -1400); t.S(60)
        t.C(30, 40); t.C(30, -40); t.S(60)
        sec2 = len(t.curv); t.G(G_SECTION)
        t.S(40); t.H(30, -800); t.H(30, 800); t.S(80); t.C(50, 30); t.S(60)
        t.H(30, 900); t.H(30, -900); t.S(40)
        t.G(G_FINISH)
    elif leg == 2:    # ridge: twisty, blind crests
        t.S(20); t.C(30, 40); t.C(30, -40); t.H(30, 1200, 30); t.H(30, -1200, -30)
        t.C(40, 55); t.S(10); t.C(40, -55); t.H(40, 1600); t.C(30, 30)
        t.G(G_CHECK)
        t.H(40, -1600, -30); t.C(30, 45); t.C(30, -45); t.S(20); t.T(30, 20)
        t.C(40, -40); t.S(20)
        sec1 = len(t.curv); t.G(G_SECTION)
        t.H(30, 1400, 40); t.H(30, -1400, -40); t.C(40, 60); t.S(10); t.C(40, -60)
        t.S(20); t.H(60, 2000, 20); t.H(40, -2000, -25); t.C(40, 35); t.S(30)
        sec2 = len(t.curv); t.G(G_SECTION)
        t.C(30, -45); t.C(30, 45); t.H(40, 1500); t.H(30, -1500, 35); t.S(30)
        t.C(60, -30); t.S(40)
        t.G(G_FINISH)
    elif leg == 3:    # alpine pass: hairpin-ish bends, tunnels
        t.S(20); t.H(50, 2400, 25); t.C(30, -55); t.T(40, 0); t.C(40, 50)
        t.H(40, 1800, -30); t.S(20)
        t.G(G_CHECK)
        t.C(30, 65); t.S(10); t.C(30, -65); t.T(50, -15); t.H(40, -2400, 20); t.S(20)
        sec1 = len(t.curv); t.G(G_SECTION)
        t.C(40, 40); t.H(40, 2000, -35); t.S(20); t.T(40, 25); t.C(30, -60)
        t.H(40, -2000); t.S(30); t.C(40, 45); t.S(20)
        sec2 = len(t.curv); t.G(G_SECTION)
        t.H(50, 1200, -20); t.C(30, 60); t.T(40, 0); t.H(40, -2600, 30); t.S(30)
        t.C(40, -40); t.S(40)
        t.G(G_FINISH)
    else:             # city at night: wide bends, tunnels, the bridge crest
        t.S(40); t.C(40, -25); t.S(30); t.T(50, 15); t.S(20); t.C(40, 35); t.S(30)
        t.G(G_CHECK)
        t.H(40, 1800); t.H(40, -1800); t.S(30); t.C(40, -40); t.S(20); t.T(40, -10)
        sec1 = len(t.curv); t.G(G_SECTION)
        t.S(30); t.C(50, 30); t.S(30); t.H(50, 2200, 10); t.H(50, -2200, -10)
        t.S(30); t.C(40, -45); t.T(40, 0); t.S(20)
        sec2 = len(t.curv); t.G(G_SECTION)
        t.C(40, 40); t.S(40); t.C(40, -30); t.H(30, 900); t.H(30, -900); t.S(60)
        t.G(G_FINISH)
    t.S(50)
    deco(t, 0, len(t.curv) - 1, leg, r)
    return t

GAN_TIME = {G_START: 0, G_CHECK: 12, G_SECTION: 30, G_FINISH: 0}

def leg_sections(leg):
    t = leg_track(leg)
    n = len(t.curv)
    gants = sorted((g, G_CHECK if k == G_SECTION else k) for g, k in t.gantries)
    # cut into sections of <= MAXSEG-LOOK segments at checkpoint gantries,
    # adding gantries where a stretch has none
    fin = max(g for g, k in gants if k == G_FINISH)
    cuts = [0]
    while fin + LOOK - cuts[-1] > MAXSEG:
        s0 = cuts[-1]
        cand = [g for g, k in gants if k == G_CHECK and s0 + 120 <= g <= s0 + MAXSEG - LOOK]
        if cand: c = max(cand)
        else:
            c = s0 + MAXSEG - LOOK
            gants.append((c, G_CHECK)); gants.sort()
        cuts.append(c)
    gants = [(g, G_SECTION if g in cuts[1:] else k) for g, k in gants]
    t.gantries = gants
    # time: what a good driver (~8.2 segments/s) needs for the stretch ahead
    tim = {}
    for i, c in enumerate(cuts):
        nxt = cuts[i + 1] if i + 1 < len(cuts) else fin
        tim[c] = min(99, int(math.ceil((nxt - c) / 7.2)) + (6 if i == 0 else 3))
    t.sec_time = tim
    secs = []
    for i, s0 in enumerate(cuts):
        s1 = min(n, s0 + MAXSEG)
        nxt = cuts[i + 1] if i + 1 < len(cuts) else None
        if nxt is not None: assert nxt - s0 <= MAXSEG - LOOK, (leg, i, nxt - s0)
        curv = t.curv[s0:s1]; alt = t.alt[s0:s1]; flag = t.flag[s0:s1]
        pad = MAXSEG - len(curv)
        curv += [0] * pad; alt += [alt[-1]] * pad; flag += [0] * pad
        objs = sorted([(s - s0, ty, x) for s, ty, x in t.objs if s0 <= s < s1 - 1])
        objs = objs[:208]
        ob = bytearray()
        for s, ty, x in objs: ob += struct.pack('<HBb', s, ty, max(-127, min(127, x)))
        ob += b'\xff\xff\x00\x00'
        gl = bytearray()
        for g, k in gants:
            if s0 < g < s1 or (i == 0 and g == s0):
                tm = t.sec_time.get(g, GAN_TIME[k]) if k == G_SECTION else GAN_TIME[k]
                gl += struct.pack('<HBB', g - s0, k, tm)
        gl += b'\xff\xff\x00\x00'
        if i == 0: t.start_time = t.sec_time[0]
        trk = bytes(c & 255 for c in curv) + bytes(a & 255 for a in alt) + \
              bytes((a >> 8) & 255 for a in alt) + bytes(flag)
        secs.append((s0, nxt, trk, bytes(ob), bytes(gl)))
    return t, secs

def sec_header(leg, nxt_rel, start_time):
    L = LEGS[leg]
    _, solid = sprites.scenery(leg)
    h = bytearray()
    h += bytes([start_time, L['traffic'], L['roof'][0], L['roof'][1]])
    h += solid
    h += struct.pack('<H', nxt_rel if nxt_rel is not None else 0xFFFF)
    h += bytes([L_MODE | (L_CSS if L['css'] else 0)])
    h += bytes([L['hud'][0], L['hud'][1], L['big'][0], L['big'][1], L['msg'][0], L['msg'][1]])
    h += bytes(L['gan'])
    h += bytes(L['pal']) + bytes(L['tun'])
    assert len(h) <= 64, len(h)
    return bytes(h) + bytes(64 - len(h))

def chunk(mp, dest, data):
    return struct.pack('<BHH', mp, dest, len(data)) + data

def build():
    os.makedirs(OUT, exist_ok=True)
    report = []
    for leg in range(5):
        t, secs = leg_sections(leg)
        scen, _ = sprites.scenery(leg)
        pn = panomod.leg_pano(leg)
        for i, (s0, nxt, trk, ob, gl) in enumerate(secs):
            d = chunk(7, TRK, trk) + chunk(7, OBJLIST, ob) + chunk(7, GANLIST, gl)
            d += chunk(7, SECHDR, sec_header(leg, None if nxt is None else nxt - s0, t.start_time))
            if i == 0:
                d += chunk(7, PANO, pn) + chunk(7, SCENERY, scen)
            d += b'\x00'
            name = 'RL%d%s.DAT' % (leg + 1, chr(65 + i))
            open(os.path.join(OUT, name), 'wb').write(d)
            report.append('%s %5d bytes  segs %d-%d objs %d' % (name, len(d), s0, s0 + MAXSEG, (len(ob) - 4) // 4))
        report.append('  leg %d total %d segments' % (leg + 1, len(t.curv)))
    return report

if __name__ == '__main__':
    for l in build(): print(l)
