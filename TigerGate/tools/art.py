#!/usr/bin/env python3
# TIGER GATE art: drawing helpers, fighters, stages, scenes, title
import math, random
from PIL import Image, ImageDraw
G, Y, B, R = 0, 1, 2, 3
FW, MW = 52, 112            # far / mid image widths in bytes
PAL = [(0x30, 0xD2, 0), (0xF0, 0xF0, 0x70), (0x30, 0x28, 0xC8), (0xD0, 0x20, 0x20)]

class Cv:
    def __init__(s, w, h, c=B):
        s.w = w; s.h = h
        s.im = Image.new('P', (w, h), c); s.d = ImageDraw.Draw(s.im)
    def copy(s):
        c = Cv(s.w, s.h); c.im = s.im.copy(); c.d = ImageDraw.Draw(c.im); return c
    def rect(s, x0, y0, x1, y1, c):
        if x1 >= x0 and y1 >= y0: s.d.rectangle([x0, y0, x1, y1], fill=c)
    def poly(s, pts, c): s.d.polygon([(float(a), float(b)) for a, b in pts], fill=c)
    def ell(s, cx, cy, rx, ry, c): s.d.ellipse([cx-rx, cy-ry, cx+rx, cy+ry], fill=c)
    def line(s, pts, c, w=1): s.d.line([(float(a), float(b)) for a, b in pts], fill=c, width=w)
    def px(s, x, y, c):
        x = int(math.floor(x)); y = int(math.floor(y))
        if 0 <= x < s.w and 0 <= y < s.h: s.im.putpixel((x, y), c)
    def get(s, x, y):
        if 0 <= x < s.w and 0 <= y < s.h: return s.im.getpixel((x, y))
        return None
    def rows(s):
        d = list(s.im.getdata()); return [d[i*s.w:(i+1)*s.w] for i in range(s.h)]
    def blit(s, spr, x, y, col=None):
        for r, row in enumerate(spr):
            for c, v in enumerate(row):
                if v: s.px(x+c, y+r, col if col is not None else v)

def packrow(row): return [row[i] << 6 | row[i+1] << 4 | row[i+2] << 2 | row[i+3] for i in range(0, len(row), 4)]
def packrows(rows): return bytes(b for r in rows for b in packrow(r))

# ---------------------------------------------------------------- scenery parts
def peak(cv, cx, top, base, hw, col=G, cap=Y, shade=B, seed=0, capfrac=0.32):
    rnd = random.Random(seed*131+cx)
    L = []; Rt = []
    n = 10
    for i in range(n+1):
        t = i/n; y = top+(base-top)*t
        L.append((cx-hw*t+rnd.uniform(-1.4, 1.4)*t, y)); Rt.append((cx+hw*t+rnd.uniform(-1.4, 1.4)*t, y))
    cv.poly(L+Rt[::-1], col)
    if shade is not None:
        for k in range(3):
            t0 = 0.3+0.2*k
            x0 = cx+hw*t0*0.85; y0 = top+(base-top)*t0
            cv.line([(x0, y0), (x0-hw*0.25, y0+(base-top)*0.22)], shade)
    if cap is not None:
        yb = top+(base-top)*capfrac; xl = cx-hw*capfrac; xr = cx+hw*capfrac
        zz = [(xl+(xr-xl)*i/6, yb+(1.5 if i % 2 else -0.5)) for i in range(7)]
        cv.poly([(cx, top)]+zz[::-1], cap)

def ridge(cv, y0, amp, col, x0=0, x1=None, seed=1, f=(9.0, 3.7), base=None):
    x1 = x1 if x1 is not None else cv.w
    base = base if base is not None else cv.h
    pts = [(x0, base)]
    for x in range(x0, x1+1):
        pts.append((x, y0-amp*(0.6*math.sin(x/f[0]+seed)+0.4*math.sin(x/f[1]+seed*2))))
    pts.append((x1, base))
    cv.poly(pts, col)

def cloud(cv, x, y, w, col=Y, under=B):
    for i in range(int(w/5)+1):
        cv.ell(x+i*5, y+(1 if i % 2 else 0), 4, 2, col)
    cv.ell(x+w/2, y-2, w/4+1, 2.5, col)
    if under is not None:
        cv.line([(x+1, y+2), (x+w-1, y+2)], under)

def pagoda(cv, cx, base, tiers=3, w=16, th=5, body=R, roof=Y):
    y = base
    for i in range(tiers):
        bw = w-i*4
        cv.rect(cx-bw//2+2, y-th+2, cx+bw//2-2, y, body)
        rw = bw//2+3; ry = y-th+2
        cv.poly([(cx-rw, ry), (cx+rw, ry), (cx+rw-3, ry-2), (cx-rw+3, ry-2)], roof)
        cv.px(cx-rw-1, ry-1, roof); cv.px(cx+rw+1, ry-1, roof)
        y = ry-2
    cv.line([(cx, y), (cx, y-3)], roof)

def foliage(cv, x0, y0, x1, y1, col=G, hi=Y, holes=B, seed=0, dens=12, rx=(3, 7), ry=(1.5, 3.5), hip=0.5, specks=2.0):
    rnd = random.Random(seed)
    n = max(2, int((x1-x0)*(y1-y0)/dens))
    for i in range(n):
        cv.ell(rnd.uniform(x0, x1), rnd.uniform(y0, y1), rnd.uniform(*rx), rnd.uniform(*ry), col)
    for i in range(int(n*specks)):
        x = rnd.uniform(x0, x1); y = rnd.uniform(y0, y1)
        if cv.get(int(x), int(y)) == col:
            if hi is not None and rnd.random() < hip:
                cv.px(x, y, hi); cv.px(x+1, y, hi)
            elif holes is not None:
                cv.px(x, y, holes)

def cherry(cv, x, base, h, spread, seed=3):
    rnd = random.Random(seed)
    trunk = [(x, base), (x+3, base-h*0.35), (x, base-h*0.65), (x+4, base-h)]
    cv.line(trunk, Y, 4); cv.line([(p[0]+2, p[1]) for p in trunk], B, 1)
    for i in range(5):
        t = 0.45+0.12*i; px_ = x+2; py_ = base-h*t
        d = -1 if i % 2 else 1
        cv.line([(px_, py_), (px_+d*spread*0.6, py_-h*0.25)], Y, 2)
    foliage(cv, x-spread, base-h-7, x+spread, base-h*0.45, col=R, hi=Y, holes=B, seed=seed, dens=10, hip=0.35)

def toro(cv, x, base, lit=True):
    cv.rect(x-3, base-1, x+3, base, Y)
    cv.rect(x-1, base-5, x+1, base-2, Y)
    cv.rect(x-3, base-6, x+3, base-6, Y)
    cv.rect(x-2, base-9, x+2, base-7, Y)
    cv.rect(x-1, base-8, x+1, base-8, R if lit else B)
    cv.poly([(x-4, base-10), (x+4, base-10), (x+2, base-12), (x-2, base-12)], Y)
    cv.px(x, base-13, Y)

def hlantern(cv, x, top, glow):
    cv.rect(x-1, top, x+1, top, Y)
    cv.ell(x, top+3.5, 3, 2.6, R)
    cv.line([(x, top+1), (x, top+6)], Y if glow else B)
    if glow: cv.px(x-1, top+3, Y); cv.px(x+1, top+4, Y)
    cv.rect(x-1, top+6, x+1, top+6, Y)
    cv.px(x, top+7, Y)

def torii(cv, x, base, w, h, col=R):
    cv.rect(x+2, base-h, x+3, base, col); cv.rect(x+w-3, base-h, x+w-2, base, col)
    cv.rect(x, base-h, x+w, base-h+1, col)
    cv.px(x-1, base-h, col); cv.px(x+w+1, base-h, col)
    cv.rect(x+1, base-h+3, x+w-1, base-h+3, col)

def pillar(cv, x, top, base, w=6, col=R, trim=Y):
    cv.rect(x, top, x+w-1, base, col)
    cv.rect(x+1, top, x+1, base, trim)
    cv.rect(x-1, top, x+w, top+1, trim)
    cv.rect(x-1, base-1, x+w, base, trim)

def roof(cv, x0, x1, y, h, col=Y, edge=R, under=B):
    # curved temple roof: wide eave with upturned tips
    cv.poly([(x0, y+h), (x1, y+h), (x1-4, y+2), (x0+4, y+2)], col)
    cv.rect(x0+6, y, x1-6, y+1, edge)
    for x in range(int(x0)+3, int(x1)-2, 2):
        cv.line([(x, y+3), (x, y+h-1)], edge)
    cv.line([(x0-2, y+h-2), (x0, y+h)], col); cv.line([(x1+2, y+h-2), (x1, y+h)], col)
    cv.line([(x0+1, y+h+1), (x1-1, y+h+1)], under)

# ---------------------------------------------------------------- floors
def mkfloor(tex):
    yh = 34.0; out = []
    for p in range(4):
        cam = p/4; img = [[B]*128 for _ in range(14)]
        for r in range(14):
            y = 44+r+0.5; ppu = 16*(y-yh)/(55.5-yh)
            for x in range(128):
                wx = (x+0.5-64)/ppu+cam
                img[r][x] = tex(wx, ppu, r, x)
        out.append(img)
    return out
def near(wx, ppu, k=1.0, off=0.0):
    v = wx*k+off; f = v-math.floor(v); return min(f, 1-f)*ppu/k < 0.5
SEAMS = (3, 7, 12)
def band(r): return sum(1 for s in SEAMS if r > s)
def t_tiles(curb):
    def t(wx, ppu, r, x):
        if r == 0: return curb
        if r == 1: return B
        if r in SEAMS or near(wx, ppu): return B
        return Y
    return t
def t_planks(wx, ppu, r, x):
    if r == 0: return R
    if r == 1: return Y
    if r % 3 == 2: return B
    if near(wx, ppu, 1.0, 0.5*((r//3) % 2)): return B
    return Y
def t_boards(wx, ppu, r, x):
    if r == 0: return R
    if r == 1: return B
    if near(wx, ppu, 2.0): return B
    if r == 9 and near(wx, ppu, 1.0, 0.25): return B
    return Y
def t_rock(wx, ppu, r, x):
    f = wx-math.floor(wx); k = math.floor(wx)
    if r == 0: return G
    if r >= 12:
        edge = 12+(1 if math.sin(f*6.28*3) > 0.2 else 0)
        return Y if r <= edge and f > 0.1 else B
    cr = 0.3+0.15*math.sin(r*0.9+3*f)
    if abs(f-cr)*ppu < 0.6: return B
    if r in (5, 9) and (0.45 < f < 0.85): return B
    return Y
def t_slabs(wx, ppu, r, x):
    if r == 0: return R
    if r == 1: return B
    if r in SEAMS: return B
    if near(wx, ppu, 1.0, 0.5*(band(r) % 2)): return B
    return Y
def t_checker(wx, ppu, r, x):
    if r == 0: return Y
    if r == 1: return R
    if near(wx, ppu): return R
    if r in SEAMS: return R
    return Y if (math.floor(wx)+band(r)) % 2 == 0 else B

# ---------------------------------------------------------------- fighters
W, H = 32, 24
def dv(a):
    r = math.radians(a); return (math.sin(r), math.cos(r))
def add(p, v, k): return (p[0]+v[0]*k, p[1]+v[1]*k)
def segd(px, py, a, b):
    dx = b[0]-a[0]; dy = b[1]-a[1]; L = dx*dx+dy*dy
    t = 0 if L == 0 else max(0, min(1, ((px-a[0])*dx+(py-a[1])*dy)/L))
    return math.hypot(px-a[0]-t*dx, py-a[1]-t*dy)
TH, SH, TO, UA, FA = 16, 17, 19, 10, 10

def pose(style, hipx, lean, fl, bl, fa, ba, hipy=None, head=0):
    gi = style['gi']; trim = style['trim']; bulk = style.get('bulk', 0); hat = style.get('hat')
    def leg(hip, t, s):
        k = add(hip, dv(t), TH); return k, add(k, dv(s), SH)
    if hipy is None:
        hipy = 68.5-max(leg((0, 0), *fl)[1][1], leg((0, 0), *bl)[1][1])
    hip = (hipx, hipy)
    tv = (math.sin(math.radians(lean)), -math.cos(math.radians(lean)))
    sh = add(hip, tv, TO)
    hv = (math.sin(math.radians(lean+head)), -math.cos(math.radians(lean+head)))
    hc = add(sh, hv, 7.5)
    parts = []
    def cap(a, b, r, c): parts.append(('cap', a, b, r, c))
    def ell(c0, rx, ry, c): parts.append(('ell', c0, rx, ry, c))
    def arm(an):
        e = add(sh, dv(an[0]), UA); w = add(e, dv(an[1]), FA)
        cap(sh, e, 2.3+bulk/2, gi); cap(e, w, 2.1+bulk/3, gi); ell(w, 2.8+bulk/3, 2.8, style.get('hand', gi))
    def legp(an):
        k, a = leg(hip, *an); cap(hip, k, 3.0+bulk/2, gi); cap(k, a, 2.6+bulk/3, gi)
        fd = dv(an[1]) if an[1] > 45 else (1, 0)
        cap(a, add(a, fd, 3.5), 2.0, style.get('foot', gi))
        return k
    if hat == 'kabuto':                         # flowing cape behind
        back = (-tv[1], tv[0])
        parts.append(('tri', add(sh, (-1, 0), 4), add(hip, (-1, 0), 12), add(hip, (1, 0), -2), gi))
        parts.append(('tri', add(sh, (-1, 0), 4), add(hip, (-1, 0), 12), add(add(hip, (-1, 0), 9), (0, 1), 14), gi))
        cap(add(add(hip, (-1, 0), 12), (0, 1), 0), add(add(hip, (-1, 0), 9), (0, 1), 14), 1.0, trim)
    arm(ba); kb = legp(bl)
    cap(hip, sh, 4.6+bulk, gi)
    kf = legp(fl)
    if hat == 'bald':                           # monk's robe skirt
        parts.append(('tri', add(hip, (1, 0), -6), add(hip, (1, 0), 6), add(kf, (1, 0), 3), gi))
        parts.append(('tri', add(hip, (1, 0), -6), add(kb, (1, 0), -3), add(kf, (1, 0), 3), gi))
        cap(add(kb, (1, 0), -3), add(kf, (1, 0), 3), 1.0, trim)
    ell(add(hip, tv, 1.5), 5.2+bulk, 2.4, trim)
    if hat == 'helm':
        ell(sh, 6.6, 2.4, Y)
        ell(hc, 4.8, 5.8, gi); ell((hc[0]+2.4, hc[1]+1.6), 2.4, 2.6, Y)
        cap((hc[0]-1.5, hc[1]-5), (hc[0]-5, hc[1]-10.5), 1.5, Y)
        cap((hc[0]+1.5, hc[1]-5), (hc[0]+5, hc[1]-10.5), 1.5, Y)
    elif hat == 'kasa':
        ell(hc, 4.6, 5.6, Y)
        parts.append(('tri', (hc[0]-10, hc[1]-1.0), (hc[0]+10, hc[1]-1.0), (hc[0], hc[1]-9.5), Y))
        cap((hc[0]-8, hc[1]-0.2), (hc[0]+8, hc[1]-0.2), 1.3, gi)
    elif hat == 'bald':
        ell(hc, 4.4, 5.8, Y)
        for k in range(5): ell(add(sh, (math.cos(k), 1), 2+k*0.8), 0.9, 0.9, trim)
    elif hat == 'hood':
        ell(hc, 4.8, 6.2, gi)
        cap((hc[0]-0.5, hc[1]-0.6), (hc[0]+4.2, hc[1]-0.6), 1.2, Y)
        cap((hc[0]-4, hc[1]-2), (hc[0]-11, hc[1]+3), 1.4, gi)
    elif hat == 'oni':
        ell(sh, 7.5, 2.6, Y)
        ell(hc, 5.4, 6.2, gi)
        cap((hc[0]-2.5, hc[1]-5), (hc[0]-4.5, hc[1]-10), 1.4, Y)
        cap((hc[0]+2.5, hc[1]-5), (hc[0]+4.5, hc[1]-10), 1.4, Y)
        cap((hc[0]+1, hc[1]-1.5), (hc[0]+4.5, hc[1]-1.5), 0.9, Y)
        cap((hc[0], hc[1]+3), (hc[0]+4.5, hc[1]+3), 0.9, Y)
    elif hat == 'kabuto':
        ell(hc, 4.8, 5.8, gi)
        cap((hc[0]-5.5, hc[1]-1), (hc[0]+5.5, hc[1]-1), 1.2, Y)
        cap((hc[0], hc[1]-5), (hc[0]-6, hc[1]-12), 1.2, Y)
        cap((hc[0], hc[1]-5), (hc[0]+6, hc[1]-12), 1.2, Y)
        cap((hc[0]+0.5, hc[1]+1.5), (hc[0]+4.2, hc[1]+1.5), 0.9, Y)
    elif hat == 'old':
        ell(hc, 4.6, 6.0, Y)
        cap((hc[0]+3, hc[1]+2), (hc[0]+2, hc[1]+9), 1.6, Y)
        ell((hc[0]-0.5, hc[1]-4), 3.4, 2.4, Y)
    else:
        ell(hc, 4.6, 6.0, gi)
        parts.append(('band', hc, 4.6, 6.0, trim))
        cap((hc[0]-4.5, hc[1]-2), (hc[0]-10, hc[1]-0.5), 1.6, trim)
        ell((hc[0]-0.5, hc[1]-5.6), 3.4, 1.7, B)
    arm(fa)
    return parts

def tri_in(p, a, b, c):
    def s(p, q, r): return (p[0]-r[0])*(q[1]-r[1])-(q[0]-r[0])*(p[1]-r[1])
    d1 = s(p, a, b); d2 = s(p, b, c); d3 = s(p, c, a)
    return not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0))

def render(parts, w=W, h=H, ux=2.0, uy=3.0, ox=0.0, oy=0.0):
    img = [[0]*w for _ in range(h)]
    for py in range(h):
        for px in range(w):
            u = ox+ux*px+ux/2; v = oy+uy*py+uy/2
            for p in parts:
                k = p[0]
                if k == 'cap':
                    if segd(u, v, p[1], p[2]) <= p[3]: img[py][px] = p[4]
                elif k == 'ell':
                    if ((u-p[1][0])/p[2])**2+((v-p[1][1])/p[3])**2 <= 1: img[py][px] = p[4]
                elif k == 'band':
                    if ((u-p[1][0])/p[2])**2+((v-p[1][1])/p[3])**2 <= 1 and abs(v-(p[1][1]-2.0)) < uy/2: img[py][px] = p[4]
                elif k == 'tri':
                    if tri_in((u, v), p[1], p[2], p[3]): img[py][px] = p[4]
    return img

def outline(img, col=B):
    h = len(img); w = len(img[0])
    out = [row[:] for row in img]
    for y in range(h):
        for x in range(w):
            if img[y][x] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx = x+dx; yy = y+dy
                    if 0 <= xx < w and 0 <= yy < h and img[yy][xx] not in (0, col):
                        out[y][x] = col; break
    return out

ST = (42, 0); SB = (-30, -34)
POSES = [
 ('STAND', dict(hipx=18, lean=2, fl=(4, 0), bl=(-4, 0), fa=(8, 14), ba=(-6, 4))),
 ('RUN1', dict(hipx=18, lean=14, fl=(42, 12), bl=(-32, -58), fa=(-42, 25), ba=(48, 105))),
 ('RUN2', dict(hipx=18, lean=14, fl=(8, 0), bl=(22, -68), fa=(0, 48), ba=(8, 60))),
 ('RUN3', dict(hipx=18, lean=14, fl=(-32, -58), bl=(42, 12), fa=(48, 105), ba=(-42, 25))),
 ('RUN4', dict(hipx=18, lean=14, fl=(22, -68), bl=(8, 0), fa=(8, 60), ba=(0, 48))),
 ('FIGHT1', dict(hipx=20, lean=-4, fl=(40, 0), bl=(-28, -34), fa=(42, 118), ba=(8, 105))),
 ('FIGHT2', dict(hipx=20, lean=-2, fl=(46, 0), bl=(-30, -40), fa=(46, 116), ba=(10, 108))),
 ('STEP', dict(hipx=20, lean=-3, fl=(18, 0), bl=(-14, -16), fa=(42, 118), ba=(8, 105))),
 ('PWIND', dict(hipx=19, lean=-8, fl=ST, bl=SB, fa=(-35, 80), ba=(40, 115))),
 ('PH', dict(hipx=22, lean=8, fl=ST, bl=SB, fa=(112, 112), ba=(-10, 80))),
 ('PM', dict(hipx=22, lean=10, fl=ST, bl=SB, fa=(90, 90), ba=(-10, 80))),
 ('PL', dict(hipx=22, lean=18, fl=(46, 0), bl=(-32, -36), fa=(62, 62), ba=(-10, 80))),
 ('KWIND', dict(hipx=18, lean=-10, fl=(85, 5), bl=(-6, -6), fa=(30, 115), ba=(-5, 100))),
 ('KH', dict(hipx=19, lean=-28, fl=(118, 118), bl=(-10, -10), fa=(10, 100), ba=(-40, 40))),
 ('KM', dict(hipx=19, lean=-20, fl=(92, 92), bl=(-8, -8), fa=(10, 100), ba=(-40, 40))),
 ('KL', dict(hipx=19, lean=-10, fl=(58, 58), bl=(-6, -6), fa=(20, 110), ba=(-30, 60))),
 ('HIT', dict(hipx=18, lean=-24, fl=(28, 6), bl=(-30, -24), fa=(95, 140), ba=(-70, -30), head=-15)),
 ('FALL1', dict(hipx=30, hipy=52, lean=-60, fl=(75, 35), bl=(65, 50), fa=(-100, -120), ba=(-80, -60))),
 ('FALL2', dict(hipx=32, hipy=66, lean=-88, fl=(115, 45), bl=(92, 88), fa=(100, 100), ba=(85, 85))),
 ('BOW', dict(hipx=16, lean=62, fl=(3, 0), bl=(-3, 0), fa=(30, 25), ba=(20, 15))),
 ('GUARD', dict(hipx=19, lean=-10, fl=ST, bl=SB, fa=(55, 172), ba=(35, 165))),
]
def frames(style): return [outline(render(pose(style, **kw))) for _, kw in POSES]
def pidx(name): return [p[0] for p in POSES].index(name)
def mirror(img): return [row[::-1] for row in img]

HERO = dict(gi=Y, trim=R)
STYLES = {
 'keeper': dict(gi=R, trim=Y, hat='kasa'),
 'guard': dict(gi=R, trim=Y, hat='helm', bulk=0.7),
 'monk': dict(gi=R, trim=Y, hat='bald'),
 'scout': dict(gi=R, trim=Y, hat='hood', bulk=-0.5),
 'oni': dict(gi=R, trim=Y, hat='oni', bulk=1.6),
 'kuro': dict(gi=R, trim=Y, hat='kabuto', bulk=0.3),
}
OLD = dict(gi=Y, trim=B, hat='old')

# ---------------------------------------------------------------- stages
class Stage: pass
def finish(st):
    st.farrows = st.far.rows(); st.midrows = st.mid.rows()
    return st

def anim(st, layer, bx, row, wb, h, nfr, period, drawf, phase=0):
    """animated rectangle: drawf(cv, frame) draws frame on a copy of the layer"""
    cv = st.far if layer == 'far' else st.mid
    frames = []
    base = cv.copy()
    for f in range(nfr):
        c = base.copy(); drawf(c, f)
        rows = c.rows()
        frames.append(packrows([rows[row+r][bx*4:(bx+wb)*4] for r in range(h)]))
    drawf(cv, 0)
    st.anims.append(dict(layer=layer, bx=bx, row=row, wb=wb, h=h, frames=frames, period=period, phase=phase,
                         top=1 if (layer == 'far' or row < 12) else 0))

def stage1():
    st = Stage(); st.anims = []
    far = Cv(FW*4, 32)
    far.ell(44, 9, 13, 9, R)
    cloud(far, 90, 5, 22); cloud(far, 150, 9, 16)
    for i, (cx, tp, hw) in enumerate([(10, 14, 22), (52, 17, 20), (96, 12, 26), (140, 16, 22), (186, 13, 24), (220, 17, 18)]):
        peak(far, cx, tp, 33, hw, seed=i, cap=Y if tp < 15 else None)
    ridge(far, 27, 2, G, seed=2)
    far.poly([(160, 33), (166, 14), (176, 12), (186, 15), (190, 33)], G)
    foliage(far, 160, 12, 190, 22, seed=5, dens=8, specks=0.6)
    pagoda(far, 176, 12, tiers=3, w=14, th=4)
    st.far = far
    mid = Cv(MW*4, 24); st.mid = mid
    def cliff(x0, x1, top, seed):
        rnd = random.Random(seed)
        pts = [(x0, 13)]
        for x in range(x0, x1+1, 4): pts.append((x, top+rnd.randint(0, 3)+(0 if x0 < x < x1 else 6)))
        pts.append((x1, 13))
        for x in range(x1, x0-1, -3): pts.append((x, 12+rnd.randint(0, 2)))
        mid.poly(pts, G)
        foliage(mid, x0+2, top-2, x1-2, top+3, seed=seed, dens=10, rx=(3, 6), ry=(1.5, 2.5), hip=0.6, specks=0.6)
        for x in range(x0+3, x1-2, 7): mid.line([(x, top+5), (x+2, 11)], B)
    cliff(-4, 72, 3, 11); cliff(136, 196, 1, 13); cliff(216, 276, 2, 14); cliff(332, 404, 4, 15)
    for x in range(0, MW*4):
        if (x*7) % 13 == 0: mid.px(x, 19, Y)
        if (x*5) % 17 == 0: mid.px(x, 13, Y)
    def fall(c, f):
        for y in range(0, 24):
            for x in range(200, 216):
                v = (y+f*2+(x % 4)*3) % 8
                c.px(x, y, Y if v < 4 else B)
        c.rect(198, 0, 199, 13, G); c.rect(216, 0, 217, 13, G)
    anim(st, 'mid', 50, 0, 4, 24, 4, 3, fall)
    # railing
    for x in range(MW*4):
        mid.px(x, 15, Y); mid.px(x, 16, R); mid.px(x, 21, Y); mid.px(x, 22, R)
    for x in range(10, MW*4, 52):
        mid.rect(x, 12, x+2, 23, R); mid.rect(x, 12, x, 23, Y)
        mid.ell(x+1, 11, 2, 1.5, R); mid.px(x, 10, Y)
    mid.rect(0, 23, MW*4-1, 23, R)
    torii(mid, 410, 23, 30, 22)
    st.mid = mid
    st.floor = mkfloor(t_planks)
    st.particles = 0
    return finish(st)

def stage2():
    st = Stage(); st.anims = []
    far = Cv(FW*4, 32)
    far.ell(150, 8, 12, 8, R)
    for i, (cx, tp, hw) in enumerate([(0, 15, 20), (40, 12, 26), (90, 16, 22), (130, 13, 26), (180, 15, 22), (214, 12, 22)]):
        peak(far, cx, tp, 33, hw, seed=i+20)
    ridge(far, 26, 2, G, seed=4)
    st.far = far
    mid = Cv(MW*4, 24); st.mid = mid
    # long wall
    mid.rect(0, 5, MW*4-1, 5, R)
    for x in range(MW*4):
        for y in (6, 7, 8): mid.px(x, y, Y if (x+(y == 7)) % 3 else R)
    mid.rect(0, 9, MW*4-1, 9, B)
    mid.rect(0, 10, MW*4-1, 13, R)
    for x in range(4, MW*4, 12): mid.rect(x, 11, x+5, 12, B)
    mid.rect(0, 14, MW*4-1, 14, Y)
    for x in range(0, MW*4, 16): mid.rect(x, 14, x, 23, Y)
    for x in range(8, MW*4, 16):
        mid.px(x, 18, Y); mid.px(x-1, 19, Y); mid.px(x+1, 19, Y); mid.px(x, 20, Y)
    mid.rect(0, 23, MW*4-1, 23, R)
    # gate halls
    for gx in (196, 384):
        roof(mid, gx-10, gx+66, 0, 6)
        pillar(mid, gx, 7, 23); pillar(mid, gx+50, 7, 23)
        mid.rect(gx+6, 7, gx+49, 11, R); mid.rect(gx+6, 12, gx+49, 23, B)
        mid.rect(gx+18, 8, gx+37, 11, Y); mid.rect(gx+20, 9, gx+35, 10, R)
        for x in range(gx+10, gx+48, 6):
            for y in range(14, 23, 4): mid.px(x, y, Y)
    # cherry tree at the start
    cherry(mid, 22, 23, 14, 26, seed=7)
    for tx in (120, 168, 324):
        toro(mid, tx, 23)
    def flick(tx):
        def f(c, fr):
            c.rect(tx-1, 15, tx+1, 15, R if fr == 0 else Y)
        return f
    anim(st, 'mid', 120//4-1, 15, 2, 1, 2, 7, flick(120))
    anim(st, 'mid', 168//4-1, 15, 2, 1, 2, 7, flick(168), phase=3)
    anim(st, 'mid', 324//4-1, 15, 2, 1, 2, 7, flick(324), phase=5)
    st.mid = mid
    st.floor = mkfloor(t_tiles(R))
    st.particles = 1
    return finish(st)

def stage3():
    st = Stage(); st.anims = []
    far = Cv(FW*4, 32)
    far.rect(0, 0, FW*4-1, 1, R); far.rect(0, 2, FW*4-1, 2, Y)
    for x in range(2, FW*4, 8): far.rect(x, 3, x+3, 5, Y)
    far.rect(0, 6, FW*4-1, 6, R)
    for sx in (0, 150):
        far.rect(sx+4, 9, sx+50, 27, Y)
        for x in range(sx+4, sx+51, 6): far.rect(x, 9, x, 27, B)
        for y in range(9, 28, 4): far.rect(sx+4, y, sx+50, y, B)
        far.rect(sx+3, 8, sx+51, 8, R); far.rect(sx+3, 28, sx+51, 28, R)
    far.ell(100, 17, 18, 11, R); far.rect(82, 17, 118, 17, B)
    far.rect(62, 9, 72, 26, Y); far.rect(64, 11, 70, 24, B)
    far.line([(65, 14), (69, 14)], Y); far.line([(67, 12), (67, 20)], Y); far.line([(65, 18), (69, 22)], Y)
    far.rect(66, 22, 68, 23, R)
    far.rect(0, 29, FW*4-1, 31, R)
    st.far = far
    mid = Cv(MW*4, 24); st.mid = mid
    mid.rect(0, 0, MW*4-1, 1, R); mid.rect(0, 2, MW*4-1, 2, Y)
    mid.rect(0, 10, MW*4-1, 10, Y); mid.rect(0, 11, MW*4-1, 11, R)
    for x in range(0, MW*4, 14): mid.rect(x, 12, x, 22, Y)
    mid.rect(0, 16, MW*4-1, 16, R)
    mid.rect(0, 23, MW*4-1, 23, Y)
    for px_ in (36, 150, 264, 378):
        pillar(mid, px_, 0, 23, w=7)
    lan = [76, 112, 190, 226, 304, 340, 418]
    for lx in lan:
        mid.line([(lx, 3), (lx, 4)], Y)
    for i, lx in enumerate(lan):
        bx = lx//4-1
        def lf(c, fr, lx=lx): hlantern(c, lx, 5, fr == 1)
        anim(st, 'mid', bx, 5, 2, 8, 2, 7 if i % 2 else 3, lf, phase=i)
    for cx in (60, 130, 244, 360):
        mid.rect(cx, 15, cx, 22, Y); mid.rect(cx-2, 22, cx+2, 22, Y)
        mid.rect(cx-1, 14, cx+1, 14, Y)
    st.mid = mid
    st.floor = mkfloor(t_boards)
    st.particles = 0
    return finish(st)

def stage4():
    st = Stage(); st.anims = []
    far = Cv(FW*4, 32)
    far.ell(70, 7, 12, 8, R)
    cloud(far, 8, 4, 24); cloud(far, 110, 8, 20); cloud(far, 170, 3, 26)
    for i, (cx, tp, hw) in enumerate([(30, 15, 24), (80, 18, 22), (130, 14, 26), (190, 17, 24)]):
        peak(far, cx, tp, 33, hw, seed=i+40, cap=None)
    far.poly([(0, 33), (0, 14), (10, 10), (22, 12), (30, 33)], G)
    foliage(far, 0, 10, 30, 30, seed=41, dens=8, specks=0.6)
    pagoda(far, 12, 11, tiers=3, w=12, th=4)
    torii(far, 150, 17, 12, 7)
    ridge(far, 28, 2, G, seed=5)
    st.far = far
    mid = Cv(MW*4, 24); st.mid = mid
    def willow(x0, x1, seed):
        rnd = random.Random(seed)
        foliage(mid, x0, 0, x1, 6, seed=seed, dens=8, specks=0.5)
        for x in range(x0, x1, 2):
            L = rnd.randint(6, 16)
            mid.line([(x, 3), (x+rnd.uniform(-1, 1), 3+L)], G)
            if rnd.random() < 0.3: mid.px(x, 3+L, Y)
    willow(0, 70, 51); willow(230, 280, 52)
    mid.poly([(0, 24), (0, 14), (30, 12), (60, 18), (74, 24)], G)
    foliage(mid, 0, 12, 74, 16, seed=53, dens=10, specks=0.3, hip=0.3)
    # pine tree
    trunk = [(330, 24), (326, 16), (334, 10), (322, 4), (340, 2)]
    mid.line(trunk, Y, 3); mid.line([(p[0]+1, p[1]) for p in trunk], B)
    for (cx, cy, w) in [(318, 3, 18), (346, 2, 16), (340, 9, 20), (314, 11, 14)]:
        foliage(mid, cx-w, cy-2, cx+w, cy+2, seed=cx+cy, dens=4, rx=(3, 6), ry=(1, 2))
    torii(mid, 410, 23, 28, 21)
    for fx in range(84, 440, 37):
        for k in range(4):
            mid.line([(fx+k*2, 23), (fx+k*2-3+k*2, 18-k % 2*2)], G)
    st.mid = mid
    st.floor = mkfloor(t_rock)
    st.particles = 2
    return finish(st)

def stage5():
    st = Stage(); st.anims = []
    far = Cv(FW*4, 32)
    rnd = random.Random(60)
    for i in range(70): far.px(rnd.randrange(FW*4), rnd.randrange(20), Y)
    far.ell(160, 9, 12, 8, R); far.ell(165, 7, 10, 7, B)
    for i, (cx, tp, hw) in enumerate([(20, 16, 26), (80, 14, 24), (140, 17, 24), (200, 15, 24)]):
        peak(far, cx, tp, 33, hw, seed=i+60, cap=None)
    for tx in (40, 110, 180):
        far.rect(tx-6, 18, tx+6, 31, R)
        for y in (22, 27): far.rect(tx-6, y, tx+6, y, Y)
        far.poly([(tx-10, 18), (tx+10, 18), (tx+6, 14), (tx-6, 14)], Y)
    ridge(far, 29, 1.5, G, seed=6)
    st.far = far
    mid = Cv(MW*4, 24); st.mid = mid
    for y in range(3, 12):
        for x in range(MW*4):
            mid.px(x, y, R if (y % 3 == 2 or (x+(y//3)*6) % 12 == 0) else Y)
    mid.rect(0, 2, MW*4-1, 2, R)
    mid.rect(0, 12, MW*4-1, 13, R)
    mid.rect(0, 14, MW*4-1, 23, B)
    for x in range(0, MW*4, 24): mid.rect(x, 14, x+1, 23, R)
    mid.rect(0, 23, MW*4-1, 23, Y)
    gx = 196
    roof(mid, gx-12, gx+76, 0, 5)
    mid.rect(gx, 6, gx+63, 23, R)
    mid.rect(gx+3, 8, gx+30, 23, B); mid.rect(gx+33, 8, gx+60, 23, B)
    for x in range(gx+6, gx+60, 6):
        if gx+30 < x < gx+33: continue
        for y in range(10, 23, 4): mid.px(x, y, Y)
    mid.rect(gx+30, 8, gx+33, 23, Y)
    def banner(x):
        def f(c, fr):
            c.rect(x, 3, x+7, 15, B)
            sh = (0, 1, 0, -1)[fr]
            c.rect(x+1, 3, x+6, 13, R)
            c.poly([(x+1, 13), (x+6, 13), (x+6+sh, 15), (x+1+sh, 15)], R)
            for k in (5, 8, 11): c.line([(x+2, k), (x+5, k-1)], Y)
            c.rect(x, 3, x+7, 3, Y)
        return f
    for i, bxp in enumerate((80, 152, 296, 368)):
        anim(st, 'mid', bxp//4, 3, 2, 13, 4, 7, banner(bxp), phase=i*2)
    def torch(x):
        def f(c, fr):
            c.rect(x, 6, x+7, 11, B)
            pts = [[(x+1, 11), (x+3, 6), (x+4, 9), (x+6, 7), (x+6, 11)], [(x+1, 11), (x+2, 8), (x+4, 6), (x+5, 9), (x+6, 11)],
                   [(x+1, 11), (x+3, 8), (x+5, 5), (x+6, 9), (x+6, 11)]][fr]
            c.poly(pts, R); c.poly([(x+3, 11), (x+4, 8), (x+5, 11)], Y)
        return f
    for i, tx in enumerate((120, 336)):
        mid.rect(tx+3, 12, tx+4, 23, Y); mid.rect(tx+1, 12, tx+6, 12, Y)
        anim(st, 'mid', tx//4, 6, 2, 6, 3, 3, torch(tx), phase=i)
    st.mid = mid
    st.floor = mkfloor(t_slabs)
    st.particles = 3
    return finish(st)

def stage6():
    st = Stage(); st.anims = []
    far = Cv(FW*4, 32, Y)
    for y in range(14, 32):
        for x in range(FW*4):
            if (x+y) % (2 if y > 22 else 4) == 0 and y > 16: far.px(x, y, R)
    far.ell(104, 25, 30, 20, R)
    for i, (cx, tp, hw) in enumerate([(10, 20, 22), (56, 22, 20), (150, 19, 26), (200, 22, 20)]):
        peak(far, cx, tp, 33, hw, col=B, cap=None, shade=None, seed=i+70)
    ridge(far, 29, 1.5, B, seed=7)
    for (bx_, by_) in ((40, 6), (46, 8), (130, 5), (137, 7), (60, 11)):
        far.line([(bx_-2, by_-1), (bx_, by_), (bx_+2, by_-1)], B)
    st.far = far
    mid = Cv(MW*4, 24, Y); st.mid = mid
    mid.rect(0, 0, MW*4-1, 2, R)
    for x in range(0, MW*4, 3): mid.px(x, 1, Y)
    mid.rect(0, 3, MW*4-1, 3, Y)
    mid.rect(0, 4, MW*4-1, 4, R)
    mid.rect(0, 12, MW*4-1, 15, Y)
    mid.rect(0, 16, MW*4-1, 16, R); mid.rect(0, 17, MW*4-1, 22, R)
    for x in range(4, MW*4, 10): mid.rect(x, 18, x+5, 21, Y if x % 20 == 4 else B)
    mid.rect(0, 23, MW*4-1, 23, Y)
    for px_ in (20, 132, 244, 356):
        pillar(mid, px_, 5, 23, w=7)
    for i, bxp in enumerate((60, 172, 284, 396)):
        mid.rect(bxp, 6, bxp+11, 18, R); mid.rect(bxp+1, 7, bxp+10, 16, Y)
        for k in (8, 11, 14): mid.line([(bxp+2, k), (bxp+5, k+1), (bxp+9, k-1)], R)
        mid.ell(bxp+5, 9, 1, 1, B)
        mid.rect(bxp, 18, bxp+11, 18, Y)
    gxp = 420
    mid.rect(gxp, 6, gxp+1, 23, R); mid.rect(gxp+20, 6, gxp+21, 23, R); mid.rect(gxp, 6, gxp+21, 6, R)
    mid.ell(gxp+11, 13, 7, 5, Y); mid.ell(gxp+11, 13, 3, 2, R)
    st.mid = mid
    st.floor = mkfloor(t_checker)
    st.particles = 0
    return finish(st)

# ---------------------------------------------------------------- big figures for scenes
def figure(style, posename, scale=2, flip=False):
    kw = dict(POSES[pidx(posename)][1])
    img = render(pose(style, **kw), w=32*scale, h=24*scale, ux=2.0/scale, uy=3.0/scale)
    img = outline(img)
    return mirror(img) if flip else img

def scene_open():
    cv = Cv(128, 40)
    rnd = random.Random(80)
    for i in range(40): cv.px(rnd.randrange(128), rnd.randrange(16), Y)
    ridge(cv, 30, 2, G, seed=8, base=40)
    cv.rect(18, 18, 58, 33, R); roof(cv, 12, 64, 10, 7, col=Y, edge=R)
    for x in range(22, 56, 8): cv.rect(x, 22, x+4, 30, B)
    for i in range(14):
        fx = 14+i*4; h = rnd.randint(6, 16)
        cv.poly([(fx, 20), (fx+2, 20-h), (fx+4, 20)], R)
        cv.poly([(fx+1, 20), (fx+2, 24-h), (fx+3, 20)], Y)
    cv.blit(figure(STYLES['guard'], 'RUN2', 1), 80, 14)
    cv.blit(figure(OLD, 'HIT', 1, ), 92, 15)
    cv.blit(figure(STYLES['guard'], 'RUN4', 1), 102, 14)
    cv.blit(figure(HERO, 'BOW', 1), 0, 16)
    return cv

def scene_kuro():
    cv = Cv(128, 40)
    cv.ell(42, 20, 36, 22, Y)
    cv.ell(42, 20, 31, 19, R)
    cv.ell(42, 20, 27, 16, B)
    cv.rect(96, 0, 124, 39, R)
    for k in range(6, 36, 6): cv.line([(98, k), (110, k+3), (122, k-2)], Y)
    cv.ell(110, 18, 3, 2, B)
    cv.poly([(8, 40), (14, 31), (28, 27), (56, 27), (70, 31), (76, 40)], R)
    for y in (32, 36): cv.line([(14, y), (70, y)], Y)
    cv.poly([(26, 18), (30, 8), (42, 5), (54, 8), (58, 18)], R)
    cv.rect(24, 17, 60, 18, Y)
    cv.line([(24, 18), (18, 26)], R, 3); cv.line([(60, 18), (66, 26)], R, 3)
    for (a, b) in ((0, 1), (1, 0)): pass
    pts_l = [(42+0, 7-0), (36, 3), (28, 1), (20, 2)]; pts_r = [(42, 7), (48, 3), (56, 1), (64, 2)]
    cv.line(pts_l, Y, 2); cv.line(pts_r, Y, 2)
    cv.rect(31, 19, 53, 27, R)
    cv.line([(33, 21), (38, 22)], Y); cv.line([(51, 21), (46, 22)], Y)
    cv.rect(35, 25, 49, 25, Y)
    for x in range(36, 49, 3): cv.px(x, 26, Y)
    return cv

def scene_cage():
    cv = Cv(128, 40, Y)
    for y in range(20, 40):
        for x in range(128):
            if (x+y) % 3 == 0: cv.px(x, y, R)
    cv.ell(64, 34, 34, 18, R)
    ridge(cv, 34, 2, B, seed=9, base=40)
    cv.line([(30, 0), (30, 6)], B)
    cv.rect(18, 6, 42, 7, B); cv.rect(18, 33, 42, 34, B)
    cv.blit(figure(OLD, 'BOW', 1), 14, 10)
    for x in range(18, 43, 4): cv.rect(x, 6, x, 34, B)
    cv.blit(figure(STYLES['kuro'], 'FIGHT1', 1, flip=True), 82, 16)
    return cv

def scene_end():
    cv = Cv(128, 40, Y)
    cv.ell(64, 32, 30, 20, R)
    for (cx, tp, hw) in [(10, 26, 20), (110, 24, 26)]:
        peak(cv, cx, tp, 41, hw, col=B, cap=None, shade=None)
    cv.rect(0, 34, 127, 39, B)
    torii(cv, 40, 34, 48, 28, col=B)
    cv.blit(figure(HERO, 'BOW', 1), 36, 11, B)
    cv.blit(figure(OLD, 'BOW', 1, flip=True), 60, 11, B)
    for (bx_, by_) in ((20, 6), (26, 9), (100, 5)):
        cv.line([(bx_-2, by_-1), (bx_, by_), (bx_+2, by_-1)], B)
    return cv

LOGO = {
 'T': ['#####', '#####', '..#..', '..#..', '..#..', '..#..', '..#..'],
 'I': ['.###.', '..#..', '..#..', '..#..', '..#..', '..#..', '.###.'],
 'G': ['.####', '##...', '#....', '#.###', '#...#', '##..#', '.####'],
 'E': ['#####', '##...', '#....', '####.', '#....', '##...', '#####'],
 'R': ['####.', '#..##', '#...#', '####.', '#.##.', '#..##', '#...#'],
 'A': ['.###.', '##.##', '#...#', '#####', '#...#', '#...#', '#...#'],
 ' ': ['.....']*7}

def title():
    cv = Cv(128, 64)
    cv.ell(64, 31, 25, 16, R)
    # temple on a hill, silhouetted against the sun
    cv.poly([(36, 47), (50, 41), (64, 39), (78, 41), (92, 47)], B)
    y = 39
    for (bw, rw) in ((4, 10), (3, 8), (3, 6), (2, 5)):
        cv.rect(64-bw, y-4, 64+bw, y, B)
        cv.rect(64-rw, y-4, 64+rw, y-4, B)
        cv.px(64-rw-1, y-5, B); cv.px(64+rw+1, y-5, B)
        y -= 5
    cv.rect(64, y-3, 64, y, B)
    for (y0, amp, sd) in ((41, 3, 1), (45, 2, 3)):
        pts = [(x, y0-amp*math.sin(x/11.0+sd)-1.5*math.sin(x/4.3)) for x in range(0, 129)]
        cv.poly(pts+[(128, 47), (0, 47)], B)
        cv.line(pts, Y)
    pts = [(94+i, 41-6*math.sin(math.pi*i/32)) for i in range(33)]
    cv.line(pts, Y); cv.line([(p[0], p[1]-3) for p in pts], Y)
    for i in range(0, 33, 4): cv.line([(94+i, pts[i][1]), (94+i, pts[i][1]-3)], Y)
    trunk = [(6, 47), (10, 38), (6, 30), (12, 22), (20, 17)]
    cv.line(trunk, Y, 3); cv.line([(p[0]+2, p[1]) for p in trunk], B)
    cv.line([(9, 30), (24, 26)], Y, 2); cv.line([(11, 23), (2, 18)], Y, 2)
    foliage(cv, -4, 14, 34, 30, col=R, hi=Y, holes=B, seed=9, dens=14, rx=(3, 7), ry=(2, 3.5), hip=0.5, specks=0.5)
    cv.rect(0, 47, 127, 63, B)
    cv.rect(0, 47, 127, 47, R)
    text = 'TIGER GATE'
    def glyphs(dx, dy, col):
        x = 7
        for ch in text:
            g = LOGO[ch]
            for r in range(7):
                for c in range(5):
                    if g[r][c] == '#':
                        cv.rect(x+c*2+dx, 2+r*2+dy, x+c*2+1+dx, 3+r*2+dy, col)
            x += 12 if ch != ' ' else 6
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1), (2, 2), (2, 1), (1, 2)):
        glyphs(dx, dy, B)
    glyphs(1, 1, R)
    glyphs(0, 0, Y)
    return cv

def save(img, path):
    im = Image.new('RGB', (len(img[0]), len(img)))
    for y, row in enumerate(img):
        for x, v in enumerate(row): im.putpixel((x, y), PAL[v])
    im.resize((len(img[0])*4, len(img)*6), Image.NEAREST).save(path)
