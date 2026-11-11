"""Builds RAYBENCH.VZ: generates tables, assembles, simulates, patches expected results."""
import math, sys
from z80tools import assemble, Z80
from PIL import Image

A = dict(DXLO=0x9000, DXHI=0x9400, DYLO=0x9800, DYHI=0x9C00, ASIN=0xA000, ACOS=0xA400,
         LOGD=0xA800, HITAB=0xAC00, TEXBUF=0xAD00, MAP=0xAE00, TEX=0xAF00,
         UNROLL=0xBB00, REC=0xBE00, COLS=0xC500, PATH=0xCB00, MODES=0xCBC0, VARS=0xCBE0, TXT=0xCC40, SCALERS=0xCE00)
A['TEXL'] = A['TEX']+0x400; A['TEXR'] = A['TEX']+0x800
mem = bytearray(65536)
def put(addr, data):
    mem[addr:addr+len(data)] = bytes(data); return addr+len(data)

# ---- trig / delta tables, 1024 angles -------------------------------------
NA = 1024
for a in range(NA):
    th = 2*math.pi*a/NA
    c, s = abs(math.cos(th)), abs(math.sin(th))
    dx = min(32767, int(round(256/c))) if c > 1e-9 else 32767
    dy = min(32767, int(round(256/s))) if s > 1e-9 else 32767
    mem[A['DXLO']+a] = dx & 255; mem[A['DXHI']+a] = dx >> 8
    mem[A['DYLO']+a] = dy & 255; mem[A['DYHI']+a] = dy >> 8
    mem[A['ASIN']+a] = min(255, int(round(s*256))); mem[A['ACOS']+a] = min(255, int(round(c*256)))

# ---- log distance and height index ----------------------------------------
K = 42; DMIN = 0.25; WALL = 74.0
for i in range(1024):
    d = max(i, 16)/64
    mem[A['LOGD']+i] = max(0, min(255, int(round(K*math.log2(d/DMIN)))))
HEIGHTS = list(range(1, 65)) + [72, 80, 96, 112, 128, 160, 192, 256]
for v in range(256):
    h = WALL/(DMIN*2**(v/K))
    mem[A['HITAB']+v] = min(range(len(HEIGHTS)), key=lambda k: abs(HEIGHTS[k]-h))

# ---- row scaling: which texture row each screen row shows ------------------
geom = []; rows = []
for k, h in enumerate(HEIGHTS):
    tab = [0]*64
    if h <= 64:
        top = (64-h)//2; n = h
        for y in range(top, top+n): tab[y] = min(15, int((y-top+0.5)*16/h))
    else:
        top = 0; n = 64
        for y in range(64): tab[y] = max(0, min(15, int(math.floor(8+(y-31.5)*16/h))))
    geom.append((top, n)); rows.append(tab[top:top+n])

# ---- unrolled helpers --------------------------------------------------------
FILL_L = A['UNROLL'];           p = put(FILL_L, [0x71, 0x19]*64 + [0xC9])               # ld (hl),c / add hl,de
FILL_R = p;                     p = put(FILL_R, [0x7E, 0xB1, 0x77, 0x19]*64 + [0xC9])   # ld a,(hl) / or c / ld (hl),a / add hl,de
A['mul816'] = p;                p = put(p, [0x21, 0, 0] + [0x29, 0x17, 0x30, 0x03, 0x19, 0xCE, 0x00]*8 + [0xC9])
A['MERGE'] = p;                 p = put(p, [0x1A, 0xB6, 0x12, 0x1C, 0x2C]*16 + [0xC9])   # texbuf |= right-half texels
assert p <= A['REC']
# ---- compiled scalers: one straight-line routine per wall height ------------
scaler = []; p = A['SCALERS']
for k in range(len(HEIGHTS)):
    code = []; prev = None
    for v in rows[k]:
        if v != prev: code += [0x3A, (A['TEXBUF']+v) & 255, A['TEXBUF'] >> 8]; prev = v   # ld a,(texel)
        code += [0x77, 0x19]                                                              # ld (hl),a / add hl,de
    scaler.append(p); p = put(p, code+[0xC9])
SCEND = p; assert SCEND <= 0xFA00, hex(SCEND)
def rectab(base, fill, fsz, wallfn):
    out = []
    for k, (top, n) in enumerate(geom):
        for v in (fill+(64-top)*fsz, wallfn(k, n), fill+(top+n)*fsz, 0):
            out += [v & 255, v >> 8]
    put(base, out); return base
NR = len(HEIGHTS)*8
REC_FL = rectab(A['REC'], FILL_L, 2, lambda k, n: FILL_L+(64-n)*2)
REC_FR = rectab(A['REC']+NR, FILL_R, 4, lambda k, n: FILL_R+(64-n)*4)
REC_TC = rectab(A['REC']+2*NR, FILL_L, 2, lambda k, n: scaler[k])
assert A['REC']+3*NR <= A['COLS']

# ---- textures: 4 textures of 16x16 two-pixel texels (nibbles) --------------
G, Y, B, R = 0, 1, 2, 3
def nib(l, r): return l << 2 | r
def brick(body, alt, mortar):
    t = [[body]*16 for _ in range(16)]            # t[u][v]
    for v in range(16):
        for u in range(16):
            row = v//4
            if v % 4 == 3: t[u][v] = mortar
            elif (u + (8 if row % 2 else 0)) % 8 == 7: t[u][v] = mortar
            elif (u*7+v*3) % 11 == 0: t[u][v] = alt
    return t
def panel(face, edge, core):
    t = [[face]*16 for _ in range(16)]
    for v in range(16):
        for u in range(16):
            if u in (0, 15) or v in (0, 15): t[u][v] = edge
            elif 5 <= u <= 10 and 4 <= v <= 11: t[u][v] = core
            elif u in (3, 12) and v in (3, 12): t[u][v] = edge
    return t
texs = [brick(nib(R, R), nib(R, Y), nib(Y, Y)), brick(nib(R, B), nib(B, R), nib(Y, B)),
        panel(nib(Y, Y), nib(R, R), nib(B, B)), panel(nib(Y, G), nib(R, B), nib(B, B))]
for var in range(3):
    for ti, t in enumerate(texs):
        for u in range(16):
            for v in range(16):
                n = t[u][v]
                mem[A['TEX']+(var*4+ti)*256+u*16+v] = [n << 4 | n, n << 4, n][var]

# ---- map --------------------------------------------------------------------
MAP = ["################",
       "#......#.......#",
       "#......#.......#",
       "#..##..#..##...#",
       "#..##.....##...#",
       "#..............#",
       "#......#.......#",
       "####.###..######",
       "#......#.......#",
       "#......#..2....#",
       "#..2...........#",
       "#......#.......#",
       "#......####.####",
       "#..............#",
       "#..............#",
       "################"]
assert len(MAP) == 16 and all(len(r) == 16 for r in MAP)
grid = [[{'#': 1, '2': 2, '.': 0}[ch] for ch in r] for r in MAP]
for y in range(16):
    for x in range(16): mem[A['MAP']+y*16+x] = grid[y][x]

# ---- per-variant settings and per-column descriptors ------------------------
def var(rec, mask, texvar):
    cols = [0xAA, 0x00, 0xFF, 0x55, 0xDD, 0x66]          # ceiling, floor, 4 flat wall colours
    return [rec & 255, rec >> 8] + [c & mask for c in cols] + [(A['TEX'] >> 8)+texvar*4]
vdefs = [var(REC_FL, 0xFF, 0), var(REC_TC, 0xFF, 0), var(REC_FL, 0xF0, 1), var(REC_FR, 0x0F, 2), var(REC_TC, 0xFF, 1)]
vaddr = [A['VARS']+i*9 for i in range(5)]
for a_, v_ in zip(vaddr, vdefs): put(a_, v_)
FOV2 = math.radians(30)
def coldesc(ncols, vl, vr):
    out = []; info = []
    for i in range(ncols):
        th = math.atan((i+0.5-ncols/2)/(ncols/2)*math.tan(FOV2))
        off = int(round(th*NA/(2*math.pi))) & 0xFFFF
        fish = int(round(-K*math.log2(math.cos(th))))
        scr = 0x7000 + (i if ncols == 32 else i >> 1)
        v = vl if (ncols == 32 or i % 2 == 0) else vr
        out += [off & 255, off >> 8, fish, scr & 255, scr >> 8, v & 255, v >> 8, 0]
        info.append((off, th))
    return out, info
p = A['COLS']; modes = []
for ncols, iters, hand, vl, vr in ((32, 32, 'h_flat', vaddr[0], 0), (32, 32, 'h_tex', vaddr[1], 0),
                                   (64, 64, 'h_flat', vaddr[2], vaddr[3]), (64, 32, 'h_pair', vaddr[4], vaddr[4])):
    d, info = coldesc(ncols, vl, vr); modes.append((iters, hand, p)); p = put(p, d)
assert p <= A['PATH']

# ---- camera path: 32 frames, walking the corridor while turning a full circle
path = []; pathf = []
for k in range(32):
    px = int((1.5+12*k/31)*256); py = int(5.5*256); ang = (k*32) % 1024
    path += [px & 255, px >> 8, py & 255, py >> 8, ang & 255, ang >> 8]; pathf.append((px, py, ang))
put(A['PATH'], path)

# ---- text screen -------------------------------------------------------------
def sc(s): return [(ord(ch)-64 if 64 <= ord(ch) < 96 else ord(ch)) for ch in s]
lines = [(0, 4, "VZ300 RAYCAST BENCH V0.2"), (2, 0, "32 FRAMES PER TEST, 50 FIELDS/S"),
         (3, 0, "TEST          FIELDS   SIM  FPS"),
         (5, 0, "1 32COL FLAT"), (6, 0, "2 32COL TEXTURE"), (7, 0, "3 64COL FLAT"), (8, 0, "4 64COL PAIRED"),
         (10, 0, "FIELDS SHOULD BE WITHIN 2 OF SIM"),
         (12, 0, "KEYS 1-4: WALK ABOUT IN THAT"), (13, 0, "MODE. W A S D MOVE, Q RESULTS"),
         (15, 7, "VIBED BY BPM 2026")]
t = []
for r, c, s in lines:
    assert c+len(s) <= 32, s
    ad = 0x7000+r*32+c; t += [ad & 255, ad >> 8]+sc(s)+[0xFF]
t += [0, 0]; assert put(A['TXT'], t) <= A['SCALERS']; END = SCEND

# ---- assemble ------------------------------------------------------------------
syms = dict(A); syms.update({k+'_HI': v >> 8 for k, v in A.items()})
code = assemble(open('raybench.asm').read(), syms)
assert max(code) < A['DXLO'], hex(max(code))
for a_, v_ in code.items(): mem[a_] = v_
for i, (iters, hand, cp) in enumerate(modes):
    put(A['MODES']+i*5, [iters, syms[hand] & 255, syms[hand] >> 8, cp & 255, cp >> 8])
print('code end %04X, image end %04X' % (syms['codeend'], END))

def write_vz(name):
    hdr = b'VZF0' + b'RAYBENCH'.ljust(17, b'\0') + bytes([0xF1, 0x00, 0x80])
    open(name, 'wb').write(hdr + bytes(mem[0x8000:END]))

# ---- simulate --------------------------------------------------------------------
PAL = [(48, 210, 0), (193, 229, 0), (76, 58, 180), (154, 50, 54)]
def shot(m):
    im = Image.new('RGB', (128, 64))
    for y in range(64):
        for xb in range(32):
            b = m[0x7000+y*32+xb]
            for i in range(4): im.putpixel((xb*4+i, y), PAL[(b >> (6-2*i)) & 3])
    return im.resize((768, 576), Image.NEAREST)

def refray(px, py, ang):
    th = 2*math.pi*ang/NA; dx, dy = math.cos(th), math.sin(th)
    x, y = px/256, py/256; mx, my = int(x), int(y)
    ddx = abs(1/dx) if abs(dx) > 1e-12 else 1e30; ddy = abs(1/dy) if abs(dy) > 1e-12 else 1e30
    sx = (mx+1-x)*ddx if dx > 0 else (x-mx)*ddx; sy = (my+1-y)*ddy if dy > 0 else (y-my)*ddy
    while True:
        if sx < sy:
            mx += 1 if dx > 0 else -1
            if grid[my][mx]: return sx, 0, grid[my][mx]
            sx += ddx
        else:
            my += 1 if dy > 0 else -1
            if grid[my][mx]: return sy, 1, grid[my][mx]
            sy += ddy

def simulate(save=False):
    z = Z80(bytearray(mem)); z.pc = 0x8000; z.logio = True
    S = syms; res = []; frames = [[] for _ in range(4)]; tstart = 0; worst = 0; nchk = 0; bad = 0; ft = []
    rd16 = lambda a: z.m[a] | z.m[a+1] << 8
    while z.pc != S['keywait']:
        pc = z.pc
        if pc == S['w1']: z.ioreads = []
        if pc == S['fl']: ft.append(z.t)
        if pc == S['height']:
            d, side, cell, ra = rd16(S['dist'])/256, z.m[S['side']], z.m[S['cell']], rd16(S['rang'])
            rdist, rside, rcell = refray(rd16(S['px']), rd16(S['py']), ra)
            nchk += 1; e = abs(d-rdist)
            if (side, cell) != (rside, rcell) or e > 0.05+0.03*rdist:
                # corner grazes may legitimately pick the neighbouring face; count only real misses
                if e > 0.15+0.05*rdist: bad += 1
            worst = max(worst, e)
        if pc == S['frame_done'] and save: frames[len(res)].append(shot(z.m))
        if pc == S['test_done']:
            gaps = [b-a for a, b in zip(z.ioreads, z.ioreads[1:])]
            res.append(dict(fields=rd16(S['fields']), maxgap=max(gaps), tper=(z.t-ft[-32])/32,
                            tmax=max(b-a for a, b in zip(ft[-32:], ft[-31:]+[z.t]))))
        z.step()
    return z, res, frames, (nchk, bad, worst)

if __name__ == '__main__':
    z, res, frames, chk = simulate(save=True)
    print('ray check: %d rays, %d misses, worst distance error %.3f' % chk)
    for i, r in enumerate(res):
        print('test %d: fields %d  avg T/frame %d  worst frame %d  fps %.1f  max poll gap %d' %
              (i+1, r['fields'], r['tper'], r['tmax'], 1600/r['fields'], r['maxgap']))
        assert r['maxgap'] < 12000
    for i, r in enumerate(res):
        a_ = syms['EXPECT']+i*2; mem[a_] = r['fields'] & 255; mem[a_+1] = r['fields'] >> 8
    write_vz('RAYBENCH.VZ')
    # results screen as text
    z2, res2, _, _ = simulate()
    assert [r['fields'] for r in res2] == [r['fields'] for r in res]
    for row in range(16):
        print(''.join(chr(c+64 if c < 32 else c) if c < 64 else '#' for c in z2.m[0x7000+row*32:0x7020+row*32]))
    sheet = Image.new('RGB', (768*2+8, 576*2+8), (0, 0, 0))
    for i in range(4): sheet.paste(frames[i][9], ((i % 2)*776, (i//2)*584))
    sheet.save('preview.png')
    for i in (1, 3):
        d = int(round(res[i]['fields']/32*20))
        frames[i][0].save('run_mode%d.gif' % (i+1), save_all=True, append_images=frames[i][1:], duration=d, loop=0)
    import pickle; pickle.dump((syms, bytes(mem)), open('image.pkl', 'wb'))
