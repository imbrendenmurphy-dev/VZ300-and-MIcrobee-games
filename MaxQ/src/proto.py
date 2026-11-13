"""
VZ300 3D RACER - Stage 1 renderer prototype (ViBED by BPM)

Simulates the proposed specialised track renderer at the VZ300's true
mode(1) resolution: 128x64, 4 colours, 2 bits per pixel, 32 bytes per row.

It does the same work the Z80 version will do, in the same order, and
COUNTS that work (vertices, polygons, edges, spans, full bytes, masked
bytes) so the frame-time estimate is built from measured workload, not
guesses. Per-operation T-state costs come from the planned Z80 inner
loops (see costs.md); they are estimates until Stage 2 benchmarks them.

Output: preview GIF (scaled to the 4:3 screen shape) + per-frame CSV.
"""
import math, csv, sys
from PIL import Image

W, H = 128, 64
# VZ300 CSS0 palette: 0 green, 1 yellow, 2 blue, 3 red  (no black in CG2!)
PAL = [(40, 220, 40), (230, 230, 60), (40, 40, 200), (200, 40, 40)]
C_GREEN, C_YELLOW, C_BLUE, C_RED = 0, 1, 2, 3

# ---------------- track ----------------
SEG = 8.0          # world units between cross-sections
HALFW = 9.0        # track half-width
THICK = 3.0        # visible slab thickness (underside skirt)

def build_track(n=600):
    """Track as a strip of cross-sections. Each piece: (length, yaw rate,
    pitch target, bank target). Integrated once - on the VZ this table is
    precomputed and stored (or streamed from SD)."""
    pieces = [
        (30, 0.00, 0.00, 0.0), (25, 0.045, 0.00, 0.35), (15, 0.0, 0.12, 0.0),
        (15, 0.0, -0.15, 0.0), (30, -0.05, 0.0, -0.4), (20, 0.0, 0.0, 0.0),
        (25, 0.03, -0.08, 0.25), (20, -0.035, 0.10, -0.3), (25, 0.0, -0.10, 0.0),
        (35, 0.055, 0.04, 0.5), (20, 0.0, 0.0, 0.0), (30, -0.04, -0.06, -0.35),
    ]
    secs = []
    x = y = z = 0.0; h = 0.0; p = 0.0; b = 0.0
    i = 0
    while len(secs) < n:
        L, yaw, pt, bt = pieces[i % len(pieces)]; i += 1
        for _ in range(L):
            p += (pt - p) * 0.08
            b += (bt - b) * 0.08
            h += yaw
            secs.append((x, y, z, h, p, b))
            x += math.sin(h) * math.cos(p) * SEG
            z += math.cos(h) * math.cos(p) * SEG
            y += math.sin(p) * SEG
    return secs

# ---------------- counters ----------------
class Stats:
    def __init__(s): s.reset()
    def reset(s):
        s.vfull = s.vderived = s.polys = s.edges = s.spans = 0
        s.fullbytes = s.maskbytes = s.rows = 0

ST = Stats()

# ---------------- framebuffer ----------------
fb = [[0] * W for _ in range(H)]

def clear(col):
    for r in fb:
        for i in range(W): r[i] = col

def span(y, x0, x1, col):
    """Horizontal span x0..x1 inclusive on row y. Counts bytes the way the
    Z80 fill will touch them: whole bytes (4 px) stored directly, partial
    end bytes read-masked-written."""
    if y < 0 or y >= H: return
    x0 = max(0, x0); x1 = min(W - 1, x1)
    if x0 > x1: return
    ST.spans += 1
    row = fb[y]
    for x in range(x0, x1 + 1): row[x] = col
    b0, b1 = x0 >> 2, x1 >> 2
    if b0 == b1:
        ST.maskbytes += 0 if (x0 & 3 == 0 and x1 & 3 == 3) else 1
        ST.fullbytes += 1 if (x0 & 3 == 0 and x1 & 3 == 3) else 0
        return
    lead = 0 if x0 & 3 == 0 else 1
    trail = 0 if x1 & 3 == 3 else 1
    ST.maskbytes += lead + trail
    ST.fullbytes += (b1 - b0 + 1) - lead - trail

def area2(pts):
    return sum(pts[i][0]*pts[(i+1)%len(pts)][1]-pts[(i+1)%len(pts)][0]*pts[i][1] for i in range(len(pts)))

def cpoly(pts, col):
    """Backface-culled polygon: screen-space winding test (2 muls + subtract)."""
    if area2(pts) > 0: poly(pts, col)

def poly(pts, col):
    """Convex polygon, scanline filled with left/right edge walking."""
    if len(pts) < 3: return
    ys = [p[1] for p in pts]
    ymin = max(0, math.ceil(min(ys))); ymax = min(H - 1, math.floor(max(ys)))
    if ymin > ymax: return
    xs_ = [p[0] for p in pts]
    if max(xs_) < 0 or min(xs_) > W - 1: return
    ST.polys += 1
    n = len(pts)
    ST.edges += n
    for y in range(ymin, ymax + 1):
        xl, xr = 1e9, -1e9
        for i in range(n):
            ax, ay = pts[i]; bx, by = pts[(i + 1) % n]
            if (ay <= y < by) or (by <= y < ay) or (ay == by == y):
                if ay == by: xa, xb = ax, bx
                else:
                    t = (y - ay) / (by - ay); xa = xb = ax + (bx - ax) * t
                xl = min(xl, xa, xb); xr = max(xr, xa, xb)
        if xl <= xr:
            ST.rows += 1
            span(y, int(round(xl)), int(round(xr)), col)

# ---------------- camera / projection ----------------
FX = 70.0               # horizontal focal length in pixels
FY = FX / 1.5           # mode(1) pixels are 1.5x taller than wide on 4:3
HORIZ = 20              # horizon row when pitch = 0
NEAR = 4.0

class Cam: pass

def to_cam(c, wx, wy, wz):
    ST.vfull += 1
    dx, dy, dz = wx - c.x, wy - c.y, wz - c.z
    ch, sh = math.cos(c.h), math.sin(c.h)
    xc = dx * ch - dz * sh
    zc = dx * sh + dz * ch
    cp, sp = math.cos(c.p), math.sin(c.p)
    yc = dy * cp - zc * sp
    zc2 = dy * sp + zc * cp
    cr, sr = math.cos(c.r), math.sin(c.r)        # camera roll
    xr = xc * cr - yc * sr
    yr = xc * sr + yc * cr
    return xr, yr, zc2

def proj(v):
    x, y, z = v
    return (W / 2 + x * FX / z, HORIZ - y * FY / z)

def clipnear(a, b):
    t = (NEAR - a[2]) / (b[2] - a[2])
    return tuple(a[k] + (b[k] - a[k]) * t for k in range(3))

def clip_poly(vs):
    out = []
    n = len(vs)
    for i in range(n):
        a, b = vs[i], vs[(i + 1) % n]
        ina, inb = a[2] >= NEAR, b[2] >= NEAR
        if ina: out.append(a)
        if ina != inb: out.append(clipnear(a, b))
    return out

def edge_points(s):
    x, y, z, h, p, b = s
    rx, rz = math.cos(h), -math.sin(h)          # right vector (horizontal)
    ox = HALFW * math.cos(b); oy = HALFW * math.sin(b)
    L = (x - rx * ox, y - oy, z - rz * ox)
    R = (x + rx * ox, y + oy, z + rz * ox)
    return L, R

# ---------------- frame ----------------
VIEW = 22   # cross-sections drawn ahead

def render(secs, pos, lateral, cam_yaw_off, frame):
    ST.reset()
    clear(C_BLUE)                    # void / sky
    i0 = int(pos)
    f = pos - i0
    # camera sits behind and above the craft, follows track frame
    ci = max(0, i0 - 2)
    a, bsec = secs[ci], secs[ci + 1]
    c = Cam()
    lerp = lambda u, v: u + (v - u) * f
    c.h = lerp(a[3], bsec[3]) + cam_yaw_off
    c.p = lerp(a[4], bsec[4]) * 0.6 - 0.10
    c.r = lerp(a[5], bsec[5]) * 0.5
    rx, rz = math.cos(c.h), -math.sin(c.h)
    c.x = lerp(a[0], bsec[0]) + rx * lateral
    c.z = lerp(a[2], bsec[2]) + rz * lateral
    c.y = lerp(a[1], bsec[1]) + 7.0

    # transform the visible cross-sections once (shared by adjacent quads)
    cv = []
    for k in range(ci, min(len(secs), ci + VIEW + 1)):
        L, R = edge_points(secs[k])
        cv.append((to_cam(c, *L), to_cam(c, *R), k))

    # painter's order: far to near
    for j in range(len(cv) - 2, -1, -1):
        (L0, R0, k), (L1, R1, _) = cv[j], cv[j + 1]
        if L1[2] < NEAR and R1[2] < NEAR: continue
        surf = clip_poly([L0, R0, R1, L1])
        if len(surf) < 3: continue
        sp = [proj(v) for v in surf]
        # underside skirt: same vertices dropped by THICK (derived: 1 mul)
        if len(sp) == 4:
            ST.vderived += 4
            dn = [(x, y + THICK * FY / v[2]) for (x, y), v in zip(sp, surf)]
            # left and right side faces of the slab (seen on bends and crests)
            cpoly([sp[0], sp[3], dn[3], dn[0]], C_RED)
            cpoly([sp[2], sp[1], dn[1], dn[2]], C_RED)
            # near face (seen when the track drops away ahead)
            cpoly([sp[1], sp[0], dn[0], dn[1]], C_RED)
        stripe = ((k // 3) % 2 == 0)
        poly(sp, C_GREEN if stripe else C_YELLOW if (k % 12 == 0) else C_GREEN)
        # edge rails: thin red polygons along each side
        if len(sp) == 4:
            for e0, e1 in ((0, 3), (1, 2)):
                (x0, y0), (x1, y1) = sp[e0], sp[e1]
                w0 = max(1.0, 0.9 * FX / surf[e0][2]); w1 = max(1.0, 0.9 * FX / surf[e1][2])
                sgn = 1 if e0 == 0 else -1
                poly([(x0, y0), (x0 + sgn * w0, y0), (x1 + sgn * w1, y1), (x1, y1)], C_RED)
        # pylons every 6 sections
        if k % 6 == 0 and len(sp) == 4 and surf[0][2] > NEAR + 2:
            for e in (0, 1):
                x, y = sp[e]; z = surf[e][2]
                hgt = 9 * FY / z; wd = max(1.0, 1.4 * FX / z)
                poly([(x - wd / 2, y - hgt), (x + wd / 2, y - hgt), (x + wd / 2, y), (x - wd / 2, y)], C_YELLOW)

    # craft sprite (pre-shifted sprite on the Z80; counted as masked bytes)
    craft(frame, cam_yaw_off)

CRAFT = [
    "....3333....",
    "..33111133..",
    ".3311111133.",
    "333333333333",
    ".3........3.",
]
def craft(frame, yaw):
    cx = 58 - int(yaw * 40); cy = 52
    # shadow on track
    for dy in (6, 7):
        for x in range(cx + 1, cx + 11):
            if 0 <= cy + dy < H and 0 <= x < W and fb[cy + dy][x] in (C_GREEN, C_YELLOW): fb[cy + dy][x] = C_BLUE
    bob = 1 if (frame // 3) % 2 else 0
    for r, line in enumerate(CRAFT):
        for q, ch in enumerate(line):
            if ch != '.': fb[cy + r - bob][cx + q] = int(ch)
    ST.maskbytes += 5 * 4 + 2 * 3     # sprite rows x bytes + shadow

# ---------------- cost model (T-states, from costs.md) ----------------
COST = dict(
    clear=11_600,        # 2048 bytes via PUSH, unrolled
    copy=22_500,         # 2048 bytes buffer->VRAM via POP/PUSH, beam-racing
    vfull=980,           # yaw+pitch+roll rotate (8-10 table muls) + project
    vderived=120,        # one reciprocal-scaled offset
    poly=260,            # setup, top/bottom vertex search
    edge=230,            # per edge: dx/dy via reciprocal table
    row=70,              # walk two edges one row
    span=110,            # byte address + mask lookup + jump into fill
    fullbyte=11,         # LD (HL),A : INC L  (unrolled)
    maskbyte=38,         # LD A,(HL) : AND m : OR c : LD (HL),A + setup
    logic=6_000,         # input, physics, sound tick, HUD (budget)
)

def frame_cost():
    t = COST['clear'] + COST['copy'] + COST['logic']
    t += ST.vfull * COST['vfull'] + ST.vderived * COST['vderived']
    t += ST.polys * COST['poly'] + ST.edges * COST['edge'] + ST.rows * COST['row']
    t += ST.spans * COST['span'] + ST.fullbytes * COST['fullbyte'] + ST.maskbytes * COST['maskbyte']
    return t

TV_FRAME = 70_824   # 312 lines x 227 T (3.5469 MHz PAL, 312 lines measured on user's VZ)

def main(nframes=240, out='vzrace_preview.gif', csvpath='frames.csv'):
    secs = build_track()
    pos = 3.0; speed = 0.0; lateral = 0.0; yawoff = 0.0
    frames = []
    rows = []
    for fr in range(nframes):
        speed = min(1.1, speed + 0.02)               # accelerate
        pos += speed
        # scripted steering: lean into curve
        curv = secs[int(pos) + 3][3] - secs[int(pos)][3]
        target = -curv * 6
        lateral += (target * HALFW * 0.6 - lateral) * 0.08
        yawoff = (yawoff + (curv * 0.8 - yawoff) * 0.2)
        render(secs, pos, lateral, -yawoff * 0.5, fr)
        t = frame_cost()
        rows.append(dict(frame=fr, vfull=ST.vfull, vderived=ST.vderived, polys=ST.polys,
                         edges=ST.edges, rows=ST.rows, spans=ST.spans,
                         fullbytes=ST.fullbytes, maskbytes=ST.maskbytes, tstates=t,
                         tvframes=round(t / TV_FRAME, 2)))
        img = Image.new('RGB', (W, H))
        img.putdata([PAL[c] for r in fb for c in r])
        img = img.resize((512, 384), Image.NEAREST)   # 4:3 shape, true pixel aspect
        frames.append(img)
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=60, loop=0)
    with open(csvpath, 'w', newline='') as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
    ts = sorted(r['tstates'] for r in rows)
    avg = sum(ts) / len(ts)
    keys = ['vfull', 'vderived', 'polys', 'edges', 'rows', 'spans', 'fullbytes', 'maskbytes']
    print('frames', len(rows))
    for k in keys:
        v = [r[k] for r in rows]; print(f'{k:10s} avg {sum(v)/len(v):7.1f}  max {max(v)}')
    print(f'T-states avg {avg:,.0f}  95th pct {ts[int(len(ts)*.95)]:,}  max {ts[-1]:,}')
    print(f'TV frames avg {avg/TV_FRAME:.2f}  worst {ts[-1]/TV_FRAME:.2f}')
    # breakdown for an average frame
    ag = {k: sum(r[k] for r in rows) / len(rows) for k in keys}
    br = {
        'clear buffer': COST['clear'], 'copy to VRAM': COST['copy'],
        'vertex transform+project': ag['vfull'] * COST['vfull'] + ag['vderived'] * COST['vderived'],
        'polygon/edge setup': ag['polys'] * COST['poly'] + ag['edges'] * COST['edge'],
        'edge walking': ag['rows'] * COST['row'],
        'span setup': ag['spans'] * COST['span'],
        'pixel fill': ag['fullbytes'] * COST['fullbyte'] + ag['maskbytes'] * COST['maskbyte'],
        'game logic/input/sound': COST['logic'],
    }
    for k, v in br.items(): print(f'  {k:26s} {v:8,.0f}  {100*v/avg:4.1f}%')
    return br, avg

if __name__ == '__main__' and len(sys.argv) == 1:
    main()


# =====================================================================
# RENDERER B - specialised "row-claiming strip" renderer
# =====================================================================
# Pass A (geometry, near->far): each cross-section is transformed once;
#   the left and right edge lines between consecutive sections are set
#   up once (shared, no per-polygon setup). Each screen row is CLAIMED by
#   the nearest section that reaches it (floating horizon), so a row is
#   computed exactly once and crests hide what is behind them for free.
#   Each claimed row stores a tiny run list: void|skirt|rail|surface|rail|skirt|void.
# Pass B (raster): rows are composed straight into video RAM top to
#   bottom, every byte written exactly once, boundary bytes from a
#   precomputed (colourA, colourB, split) table. No clear, no copy.
#   Started at the top of field sync it can race the beam (see costs.md).

class StatsB:
    def reset(s):
        s.vfull = s.sections = s.edges = s.claimed = s.runs = s.boundary = 0
        s.overlay = 0
STB = StatsB()

def interp_x(a, b, y):
    (ax, ay), (bx, by) = a, b
    if abs(by - ay) < 1e-6: return (ax + bx) / 2
    t = (y - ay) / (by - ay)
    t = min(1.0, max(0.0, t))      # never extrapolate past the edge's endpoints
    return ax + (bx - ax) * t

def render_b(secs, pos, lateral, cam_yaw_off, frame, cam_h=11.0):
    STB.reset()
    i0 = int(pos); f = pos - i0
    ci = max(0, i0 - 2)
    a, bsec = secs[ci], secs[ci + 1]
    c = Cam(); lerp = lambda u, v: u + (v - u) * f
    c.h = lerp(a[3], bsec[3]) + cam_yaw_off
    c.p = lerp(a[4], bsec[4]) * 0.6 - 0.16
    c.r = lerp(a[5], bsec[5]) * 0.5
    rx, rz = math.cos(c.h), -math.sin(c.h)
    c.x = lerp(a[0], bsec[0]) + rx * lateral
    c.z = lerp(a[2], bsec[2]) + rz * lateral
    c.y = lerp(a[1], bsec[1]) + cam_h

    rows = [None] * H           # run list per row
    overlays = [[] for _ in range(H)]
    ytop = H                    # rows >= ytop already claimed
    prev = None; behind = None
    for k in range(ci, min(len(secs), ci + VIEW + 1)):
        L, R = edge_points(secs[k])
        STB.vfull += 2
        Lc, Rc = to_cam(c, *L), to_cam(c, *R)
        if Lc[2] < NEAR or Rc[2] < NEAR:
            prev = None; behind = (Lc, Rc); continue
        if prev is None and behind is not None:
            # strip crossing the near plane: clip both edges at z = NEAR
            Lb, Rb = behind
            Ln, Rn = clipnear(Lb, Lc) if Lb[2] < NEAR else Lb, clipnear(Rb, Rc) if Rb[2] < NEAR else Rb
            prev = (proj(Ln), proj(Rn), NEAR, k - 1)
            STB.vfull += 0     # clip = 2 lerps, counted in section overhead
        Lp, Rp, zl = proj(Lc), proj(Rc), (Lc[2] + Rc[2]) / 2
        if prev is not None:
            STB.sections += 1
            (Lq, Rq, zq, kq) = prev
            STB.edges += 2
            yfar = min(Lp[1], Rp[1])
            ynear = max(Lq[1], Rq[1])
            y0 = max(0, math.ceil(yfar)); y1 = min(ytop - 1, math.floor(ynear))
            band = (kq // 2) % 2
            rail = C_YELLOW if band else C_RED
            surf = C_YELLOW if kq % 8 == 0 else C_GREEN
            for y in range(y1, y0 - 1, -1):
                xl = interp_x(Lq, Lp, y); xr = interp_x(Rq, Rp, y)
                zrow = zq + (zl - zq) * (0 if ynear == yfar else (ynear - y) / max(1e-6, ynear - yfar))
                zrow = max(zrow, NEAR)
                rw = max(1.0, 1.0 * FX / zrow)            # rail width
                t = THICK * FY / zrow                      # skirt drop in rows
                sl = interp_x(Lq, Lp, y - t); sr = interp_x(Rq, Rp, y - t)
                runs = []
                xl_, xr_ = int(round(xl)), int(round(xr))
                sl_ = min(int(round(sl)), xl_); sr_ = max(int(round(sr)), xr_)
                runs = [(sl_, C_RED), (xl_, rail), (xl_ + int(rw), surf),
                        (xr_ - int(rw), rail), (xr_, C_RED), (sr_ + 1, C_BLUE)]
                rows[y] = runs
                STB.claimed += 1
                STB.runs += len(runs)
            if y0 <= y1: ytop = y0
            # pylons: overlay runs above their base, clipped by occlusion
            if kq % 6 == 0:
                for P, z in ((Lq, zq), (Rq, zq)):
                    x, yb = P
                    if yb >= H or yb < 0: continue
                    if yb > ytop_before[0] + 0.5: continue    # base hidden by a crest
                    hgt = 10 * FY / z; wd = max(1, int(round(1.4 * FX / z)))
                    for yy in range(max(0, int(yb - hgt)), min(H, int(yb))):
                        overlays[yy].append((int(x - wd / 2), int(x - wd / 2) + wd - 1, C_YELLOW))
                        STB.overlay += 1
        ytop_before[0] = ytop
        prev = (Lp, Rp, zl, k)
    prev_first[0] = True

    # Pass B: compose every row (each byte written once)
    for y in range(H):
        row = fb[y]
        runs = rows[y]
        if runs is None:
            for x in range(W): row[x] = C_BLUE
            continue
        col = C_BLUE; xi = 0; nb = 0
        for (xs, cc) in runs:
            xs = max(0, min(W, xs))
            for x in range(xi, xs): row[x] = col
            if xs & 3 and 0 < xs < W: nb += 1
            xi = max(xi, xs); col = cc
        for x in range(xi, W): row[x] = col
        for (x0, x1, cc) in overlays[y]:
            for x in range(max(0, x0), min(W, x1 + 1)): row[x] = cc
        STB.boundary += nb
    craft(frame, cam_yaw_off)

prev_first = [True]
ytop_before = [H]

COSTB = dict(
    vfull=980,       # same transform as renderer A (no track-relative tricks yet)
    section=150,     # loop overhead, colour selection
    edge=230,        # shared edge setup (dx/dy via reciprocal table)
    claimed=150,     # step 2 edges + 2 skirt lookups + z interp, per claimed row
    run=14,          # store one run descriptor
    rowcompose=90,   # per-row overhead in raster pass
    fullbyte=11,     # LD (HL),A : INC L
    boundary=34,     # table lookup for a split byte
    overlay=45,      # pylon/overlay byte, masked
    craft=26 * 38,   # craft sprite + shadow, masked bytes
    logic=6_000,
)

def frame_cost_b(beam_race=True):
    t = COSTB['logic'] + COSTB['craft']
    t += STB.vfull * COSTB['vfull'] + STB.sections * COSTB['section'] + STB.edges * COSTB['edge']
    t += STB.claimed * COSTB['claimed'] + STB.runs * COSTB['run']
    t += H * COSTB['rowcompose'] + (2048 - STB.boundary) * COSTB['fullbyte'] + STB.boundary * COSTB['boundary']
    t += STB.overlay * COSTB['overlay']
    if not beam_race: t += 22_500    # compose to buffer then copy, if racing proves impossible
    return t

def main_b(nframes=240, out='vzrace_B.gif', csvpath='frames_B.csv'):
    secs = build_track()
    pos = 3.0; speed = 0.0; lateral = 0.0; yawoff = 0.0
    frames, rows = [], []
    for fr in range(nframes):
        speed = min(1.1, speed + 0.02); pos += speed
        curv = secs[int(pos) + 3][3] - secs[int(pos)][3]
        lateral += (-curv * 6 * HALFW * 0.6 - lateral) * 0.08
        yawoff = (yawoff + (curv * 0.8 - yawoff) * 0.2)
        render_b(secs, pos, lateral, -yawoff * 0.5, fr)
        t = frame_cost_b(); t2 = frame_cost_b(False)
        rows.append(dict(frame=fr, vfull=STB.vfull, sections=STB.sections, edges=STB.edges,
                         claimed=STB.claimed, runs=STB.runs, boundary=STB.boundary,
                         overlay=STB.overlay, tstates=t, tstates_buffered=t2))
        img = Image.new('RGB', (W, H)); img.putdata([PAL[c] for r in fb for c in r])
        frames.append(img.resize((512, 384), Image.NEAREST))
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=60, loop=0)
    with open(csvpath, 'w', newline='') as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
    for k in ['vfull', 'sections', 'edges', 'claimed', 'runs', 'boundary', 'overlay']:
        v = [r[k] for r in rows]; print(f'{k:9s} avg {sum(v)/len(v):7.1f}  max {max(v)}')
    for key in ('tstates', 'tstates_buffered'):
        ts = sorted(r[key] for r in rows); avg = sum(ts) / len(ts)
        print(f'{key:17s} avg {avg:,.0f} ({avg/TV_FRAME:.2f} TV frames)  worst {ts[-1]:,} ({ts[-1]/TV_FRAME:.2f})')
    return frames

if __name__ == '__main__' and 'B' in sys.argv:
    main_b()


# =====================================================================
# RENDERER C - renderer B geometry, restyled after the user's reference
# shots: checker dithers as extra shades, low camera, banded dithered sky
# in the second colour set (mid-frame CSS switch), bold silhouette craft.
# =====================================================================
CSS0 = [(40, 205, 40), (235, 235, 70), (45, 35, 205), (205, 30, 60)]      # green yellow blue red
CSS1 = [(232, 232, 214), (30, 215, 160), (235, 45, 235), (250, 135, 20)]  # buff cyan magenta orange
# pattern ids: <4 solid; >=4 checker of two indices
PATS = {4: (0, 2), 5: (3, 2), 6: (1, 0), 7: (1, 3), 8: (2, 0),
        # sky patterns (CSS1 indices)
        20: (1, 2), 21: (2, 3), 22: (2, 2), 23: (3, 3), 24: (1, 1)}
rowcss = [0] * H

def pix(c, x, y):
    if c < 4: return c
    a, b = PATS[c]; return a if (x + y) & 1 == 0 else b

SKYBANDS = [24, 20, 22, 22, 21, 23]   # cyan, cyan/magenta, magenta, magenta, magenta/orange, orange

CRAFT2 = [  # rear view, 28 x 11 : 2 blue body, 8 dither edge, 3 tail light, 1 thruster
    "......8222222222222228......",
    "....822222222222222222228...",
    "...82222222222222222222228..",
    "..8222333332222222333332228.",
    "..8222333332222222333332228.",
    "..8222222222222222222222228.",
    "...82222222222222222222228..",
    "....8222221111111122222228..",
    ".....88222222222222222288...",
    "........8888888888888.......",
]

def render_c(secs, pos, lateral, cam_yaw_off, frame, steer):
    global HORIZ
    HORIZ = 27
    STB.reset()
    i0 = int(pos); f = pos - i0
    ci = max(0, i0 - 2)
    a, bsec = secs[ci], secs[ci + 1]
    c = Cam(); lerp = lambda u, v: u + (v - u) * f
    c.h = lerp(a[3], bsec[3]) + cam_yaw_off
    c.p = lerp(a[4], bsec[4]) * 0.6 - 0.07
    c.r = lerp(a[5], bsec[5]) * 0.45
    rx, rz = math.cos(c.h), -math.sin(c.h)
    c.x = lerp(a[0], bsec[0]) + rx * lateral
    c.z = lerp(a[2], bsec[2]) + rz * lateral
    c.y = lerp(a[1], bsec[1]) + 6.0

    rows = [None] * H
    overlays = [[] for _ in range(H)]
    # ---- pass A1: transform cross-sections, near-plane clip the first strip
    pts = []          # (Lscreen, Rscreen, z, k)
    behind = None
    for k in range(ci, min(len(secs), ci + VIEW + 1)):
        L, R = edge_points(secs[k]); STB.vfull += 2
        Lc, Rc = to_cam(c, *L), to_cam(c, *R)
        if Lc[2] < NEAR or Rc[2] < NEAR:
            behind = (Lc, Rc, k); pts = []; continue
        if not pts and behind is not None:
            Lb, Rb, kb = behind
            Ln = clipnear(Lb, Lc) if Lb[2] < NEAR else Lb
            Rn = clipnear(Rb, Rc) if Rb[2] < NEAR else Rb
            pts.append((proj(Ln), proj(Rn), NEAR, kb))
        pts.append((proj(Lc), proj(Rc), (Lc[2] + Rc[2]) / 2, k))
    # ---- pass A2: rasterise left and right edge polylines into row tables.
    # Each table row is claimed once, near->far (floating horizon per edge):
    # crests hide what lies behind them, banking just tilts the two edges.
    def raster_edge(side):
        xs = [None] * H; zs = [None] * H; ks = [None] * H
        top = H
        for j in range(len(pts) - 1):
            (P0, z0, k0), (P1, z1, _) = (pts[j][side], pts[j][2], pts[j][3]), (pts[j + 1][side], pts[j + 1][2], 0)
            STB.edges += 1
            ya, yb = P0[1], P1[1]
            y_hi = min(top - 1, math.floor(max(ya, yb))); y_lo = max(0, math.ceil(min(ya, yb)))
            for y in range(y_hi, y_lo - 1, -1):
                t = 0.5 if abs(ya - yb) < 1e-6 else (ya - y) / (ya - yb)
                xs[y] = P0[0] + (P1[0] - P0[0]) * t
                zs[y] = z0 + (z1 - z0) * t; ks[y] = k0
            if y_lo <= y_hi: top = y_lo
        return xs, zs, ks, top
    xL, zL, kL, topL = raster_edge(0)
    xR, zR, kR, topR = raster_edge(1)
    ytop = min(topL, topR)
    # rows where only one edge is defined borrow the other edge's nearest value below
    lastL = lastR = None
    for y in range(H - 1, -1, -1):
        if xL[y] is not None: lastL = (xL[y], zL[y], kL[y])
        if xR[y] is not None: lastR = (xR[y], zR[y], kR[y])
        if y < ytop or (xL[y] is None and xR[y] is None): continue
        if lastL is None or lastR is None: continue
        lx, lz, lk = lastL
        rx, rz, rk = lastR
        if lx > rx: continue
        zrow = max(NEAR, (lz + rz) / 2); kq = lk
        surf = 0 if (kq // 2) % 2 else 4
        rail = 7 if kq % 2 else 1
        rw = max(1.0, 1.1 * FX / zrow)
        t = THICK * FY / zrow
        # skirt: the edge as it appears t rows higher up (the dropped edge)
        yy = max(0, int(round(y - t)))
        sl = xL[yy] if xL[yy] is not None else lx
        sr = xR[yy] if xR[yy] is not None else rx
        xl_, xr_ = int(round(lx)), int(round(rx))
        sl_ = max(xl_ - int(3 * rw), min(int(round(sl)), xl_))
        sr_ = min(xr_ + int(3 * rw), max(int(round(sr)), xr_))
        rows[y] = [(sl_, 5), (xl_, rail), (xl_ + int(rw), surf),
                   (xr_ - int(rw), rail), (xr_, 5), (sr_ + 1, 2)]
        STB.claimed += 1; STB.runs += 6
    STB.sections = max(0, len(pts) - 1)
    # ---- gates: overlay runs; visible only if both bases are unoccluded
    for j in range(len(pts)):
        Lq, Rq, zq, kq = pts[j]
        if kq % 8 or zq < NEAR + 3: continue
        ok = True
        for P, tab in ((Lq, xL), (Rq, xR)):
            yb = int(round(P[1]))
            if not (0 <= yb < H) or tab[yb] is None or abs(tab[yb] - P[0]) > 2: ok = False
        if not ok: continue
        hgt = 11 * FY / zq; wd = max(1, int(round(1.6 * FX / zq)))
        for (x, yb) in (Lq, Rq):
            for yy in range(max(0, int(yb - hgt)), min(H, int(yb))):
                overlays[yy].append((int(x - wd / 2), int(x - wd / 2) + wd - 1, 3)); STB.overlay += 1
        ybar = int(min(Lq[1], Rq[1]) - hgt); th = max(1, int(1.2 * FY / zq))
        for yy in range(max(0, ybar), min(H, ybar + th)):
            overlays[yy].append((int(Lq[0]), int(Rq[0]), 3)); STB.overlay += 1

    # CSS split row: above the topmost track row and the horizon -> sky palette
    split = max(0, min(ytop, HORIZ + int(-c.p * FY)))
    for y in range(H):
        row = fb[y]
        if y < split:
            rowcss[y] = 1
            band = SKYBANDS[min(len(SKYBANDS) - 1, int((y / max(1, split)) * len(SKYBANDS)))]
            for x in range(W): row[x] = pix(band, x, y)
        else:
            rowcss[y] = 0
            runs = rows[y]
            if runs is None:
                for x in range(W): row[x] = pix(8 if y < split + 2 else 2, x, y)   # dithered horizon haze
            else:
                col = 2; xi = 0; nb = 0
                for (xs, cc) in runs:
                    xs = max(0, min(W, xs))
                    for x in range(xi, xs): row[x] = pix(col, x, y)
                    if xs & 3 and 0 < xs < W: nb += 1
                    xi = max(xi, xs); col = cc
                for x in range(xi, W): row[x] = pix(col, x, y)
                STB.boundary += nb
        for (x0, x1, cc) in overlays[y]:
            for x in range(max(0, x0), min(W, x1 + 1)): row[x] = cc
    # player craft: bold silhouette, leans with steering
    cx = 50 - int(steer * 6); cy = 51 + (1 if (frame // 4) % 2 else 0)
    for r, line in enumerate(CRAFT2):
        sh = int(round(steer * (r - 5) * 0.25))      # lean: shear rows
        for q, ch in enumerate(line):
            if ch == '.': continue
            x, y = cx + q + sh, cy + r
            if 0 <= x < W and 0 <= y < H and rowcss[y] == 0:
                v = int(ch) if ch != '8' else pix(8, x, y)
                if ch == '1': v = 1 if frame % 2 else 3
                fb[y][x] = v
    return split

def main_c(nframes=300, out='vzrace_C.gif', csvpath='frames_C.csv'):
    secs = build_track()
    pos = 3.0; speed = 0.0; lateral = 0.0; yawoff = 0.0; steer = 0.0
    frames, rows = [], []
    for fr in range(nframes):
        speed = min(1.15, speed + 0.02); pos += speed
        curv = secs[int(pos) + 3][3] - secs[int(pos)][3]
        target = -curv * 6 * HALFW * 0.6
        steer += ((target - lateral) * 0.6 - steer) * 0.25
        lateral += (target - lateral) * 0.08
        yawoff = (yawoff + (curv * 0.8 - yawoff) * 0.2)
        render_c(secs, pos, lateral, -yawoff * 0.5, fr, max(-3, min(3, steer)))
        t = frame_cost_b()
        rows.append(dict(frame=fr, vfull=STB.vfull, sections=STB.sections, claimed=STB.claimed,
                         runs=STB.runs, boundary=STB.boundary, overlay=STB.overlay, tstates=t))
        img = Image.new('RGB', (W, H))
        img.putdata([(CSS1 if rowcss[y] else CSS0)[fb[y][x]] for y in range(H) for x in range(W)])
        frames.append(img.resize((512, 384), Image.NEAREST))
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=60, loop=0)
    with open(csvpath, 'w', newline='') as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
    ts = sorted(r['tstates'] for r in rows); avg = sum(ts) / len(ts)
    print(f'C: avg {avg:,.0f} T ({avg/TV_FRAME:.2f} TV frames)  worst {ts[-1]:,} ({ts[-1]/TV_FRAME:.2f})')
    return frames

if __name__ == '__main__' and 'C' in sys.argv:
    main_c()


# =====================================================================
# RENDERER D - robust hybrid: one quad per track section, painted far->near
# as ROW INTERVALS into per-row run lists (no pixels touched), then every
# row composed once (each byte written once, no clear, no copy).
# Handles hard banking, where left and right edges occupy different rows.
# =====================================================================
class StatsD:
    def reset(s):
        s.vfull = s.strips = s.edges = s.rowstrips = s.inserts = s.boundary = s.overlay = 0
STD = StatsD()
LASTCOLS = [None] * H
LASTSPLIT = [0]

def hull(points):
    pts = sorted(set(points))
    if len(pts) < 3: return pts
    def cr(o, a, b): return (a[0]-o[0])*(b[1]-o[1]) - (a[1]-o[1])*(b[0]-o[0])
    lo, up = [], []
    for p in pts:
        while len(lo) >= 2 and cr(lo[-2], lo[-1], p) <= 0: lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) >= 2 and cr(up[-2], up[-1], p) <= 0: up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]

def row_extent(poly_pts, tags, y):
    """x-extent of a convex polygon on row y, plus the tag of the edge
    giving each end. tags[i] labels edge pts[i]->pts[i+1]."""
    xl, xr, tl, tr = 1e9, -1e9, None, None
    n = len(poly_pts)
    for i in range(n):
        (ax, ay), (bx, by) = poly_pts[i], poly_pts[(i + 1) % n]
        if (ay <= y <= by) or (by <= y <= ay):
            x = ax if ay == by else ax + (bx - ax) * (y - ay) / (by - ay)
            if x < xl: xl, tl = x, tags[i] if tags else None
            if x > xr: xr, tr = x, tags[i] if tags else None
    return (xl, xr, tl, tr) if xl <= xr else None

CAMH_D = 6.0
HZ_D = 27
def render_d(secs, pos, lateral, cam_yaw_off, frame, steer):
    global HORIZ
    HORIZ = HZ_D
    STD.reset()
    i0 = int(pos); f = pos - i0
    ci = max(0, i0 - 2)
    a, bsec = secs[ci], secs[ci + 1]
    c = Cam(); lerp = lambda u, v: u + (v - u) * f
    c.h = lerp(a[3], bsec[3]) + cam_yaw_off
    c.p = lerp(a[4], bsec[4]) * 0.6 - 0.07
    c.r = lerp(a[5], bsec[5]) * 0.45
    rx, rz = math.cos(c.h), -math.sin(c.h)
    c.x = lerp(a[0], bsec[0]) + rx * lateral
    c.z = lerp(a[2], bsec[2]) + rz * lateral
    c.y = lerp(a[1], bsec[1]) + CAMH_D

    cv = []
    for k in range(ci, min(len(secs), ci + VIEW + 1)):
        L, R = edge_points(secs[k]); STD.vfull += 2
        cv.append((to_cam(c, *L), to_cam(c, *R), k))
    rows = [[] for _ in range(H)]          # painter-ordered intervals per row
    overlays = [[] for _ in range(H)]
    ytop = H
    for j in range(len(cv) - 2, -1, -1):          # far -> near
        (L0, R0, k), (L1, R1, _) = cv[j], cv[j + 1]
        if L1[2] < NEAR and R1[2] < NEAR: continue
        quad = [L0, R0, R1, L1]
        qtags = ['C', 'R', 'C', 'L']               # near cap, right edge, far cap, left edge
        # near-plane clip keeping edge tags
        out, otags = [], []
        for i in range(4):
            A, B = quad[i], quad[(i + 1) % 4]
            ina, inb = A[2] >= NEAR, B[2] >= NEAR
            if ina:
                out.append(A); otags.append(qtags[i])
            if ina != inb:
                out.append(clipnear(A, B)); otags.append(qtags[i] if not ina else 'C')
        if len(out) < 3: continue
        sp = [proj(v) for v in out]
        dn = [(x, y + THICK * FY / v[2]) for (x, y), v in zip(sp, out)]
        sil = hull(sp + dn)
        STD.strips += 1; STD.edges += 3 + 2          # shared L/R/cap + 2 silhouette edges
        surf = 0 if (k // 2) % 2 else 4
        rail = 7 if k % 2 else 1
        zmid = max(NEAR, sum(v[2] for v in out) / len(out))
        rw = max(1, int(1.1 * FX / zmid))
        ys = [p[1] for p in sil]
        for y in range(max(0, math.ceil(min(ys))), min(H - 1, math.floor(max(ys))) + 1):
            e = row_extent(sil, None, y)
            if not e: continue
            STD.rowstrips += 1
            rows[y].append((int(round(e[0])), int(round(e[1])), 5)); STD.inserts += 1
            s_ = row_extent(sp, otags, y)
            if s_:
                xl, xr, tl, tr = s_
                xl, xr = int(round(xl)), int(round(xr))
                rows[y].append((xl, xr, surf)); STD.inserts += 1
                if tl == 'L': rows[y].append((xl, min(xr, xl + rw - 1), rail)); STD.inserts += 1
                if tr == 'R': rows[y].append((max(xl, xr - rw + 1), xr, rail)); STD.inserts += 1
                ytop = min(ytop, y)
        # gates (painter's order handles occlusion by nearer track)
        if k % 8 == 0 and L0[2] > NEAR + 3 and R0[2] > NEAR + 3:
            Lq, Rq = proj(L0), proj(R0); zq = (L0[2] + R0[2]) / 2
            hgt = 11 * FY / zq; wd = max(1, int(round(1.6 * FX / zq)))
            for (x, yb) in (Lq, Rq):
                for yy in range(max(0, int(yb - hgt)), min(H, int(yb))):
                    rows[yy].append((int(x - wd / 2), int(x - wd / 2) + wd - 1, 3)); STD.inserts += 1
            ybar = int(min(Lq[1], Rq[1]) - hgt); th = max(1, int(1.2 * FY / zq))
            for yy in range(max(0, ybar), min(H, ybar + th)):
                rows[yy].append((int(min(Lq[0], Rq[0])), int(max(Lq[0], Rq[0])), 3)); STD.inserts += 1

    split = max(0, min(ytop, HORIZ + int(-c.p * FY)))
    LASTSPLIT[0] = split
    for y in range(H):
        row = fb[y]
        if y < split:
            rowcss[y] = 1
            band = SKYBANDS[min(len(SKYBANDS) - 1, int((y / max(1, split)) * len(SKYBANDS)))]
            base = band
        else:
            rowcss[y] = 0; base = 8 if y < split + 2 else 2
        cols = [base] * W
        for (x0, x1, cc) in rows[y]:
            for x in range(max(0, x0), min(W, x1 + 1)): cols[x] = cc
        LASTCOLS[y] = list(cols)
        prev = None
        for x in range(W):
            row[x] = pix(cols[x], x, y)
            if cols[x] != prev and x & 3: STD.boundary += 1
            prev = cols[x]
    cx = 50 - int(steer * 6); cy = 51 + (1 if (frame // 4) % 2 else 0)
    for r, line in enumerate(CRAFT2):
        sh = int(round(steer * (r - 5) * 0.25))
        for q, ch in enumerate(line):
            if ch == '.': continue
            x, y = cx + q + sh, cy + r
            if 0 <= x < W and 0 <= y < H and rowcss[y] == 0:
                v = int(ch) if ch != '8' else pix(8, x, y)
                if ch == '1': v = 1 if frame % 2 else 3
                fb[y][x] = v

COSTD = dict(
    vfull=980,        # rotate yaw/pitch/roll + project (table multiplies)
    strip=200,        # clip test, colour select, hull of 8 pts (mostly table-driven)
    edge=230,         # edge setup: dx/dy via reciprocal table
    rowstrip=110,     # step silhouette + surface edges one row
    insert=75,        # paint one interval into a row's run list (painter clip)
    rowcompose=90,
    fullbyte=11,
    boundary=34,
    craft=26 * 38,
    logic=6_000,
)

def frame_cost_d():
    t = COSTD['logic'] + COSTD['craft']
    t += STD.vfull * COSTD['vfull'] + STD.strips * COSTD['strip'] + STD.edges * COSTD['edge']
    t += STD.rowstrips * COSTD['rowstrip'] + STD.inserts * COSTD['insert']
    t += H * COSTD['rowcompose'] + (2048 - STD.boundary) * COSTD['fullbyte'] + STD.boundary * COSTD['boundary']
    return t

def main_d(nframes=300, out='vzrace_D.gif', csvpath='frames_D.csv'):
    secs = build_track()
    pos = 3.0; speed = 0.0; lateral = 0.0; yawoff = 0.0; steer = 0.0
    frames, rows = [], []
    for fr in range(nframes):
        speed = min(1.15, speed + 0.02); pos += speed
        curv = secs[int(pos) + 3][3] - secs[int(pos)][3]
        target = -curv * 6 * HALFW * 0.6
        steer += ((target - lateral) * 0.6 - steer) * 0.25
        lateral += (target - lateral) * 0.08
        yawoff = (yawoff + (curv * 0.8 - yawoff) * 0.2)
        render_d(secs, pos, lateral, -yawoff * 0.5, fr, max(-3, min(3, steer)))
        t = frame_cost_d()
        rows.append(dict(frame=fr, vfull=STD.vfull, strips=STD.strips, edges=STD.edges,
                         rowstrips=STD.rowstrips, inserts=STD.inserts, boundary=STD.boundary,
                         tstates=t, tvframes=round(t / TV_FRAME, 2)))
        img = Image.new('RGB', (W, H))
        img.putdata([(CSS1 if rowcss[y] else CSS0)[fb[y][x]] for y in range(H) for x in range(W)])
        frames.append(img.resize((512, 384), Image.NEAREST))
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=60, loop=0)
    with open(csvpath, 'w', newline='') as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
    for k in ['vfull', 'strips', 'edges', 'rowstrips', 'inserts', 'boundary']:
        v = [r[k] for r in rows]; print(f'{k:9s} avg {sum(v)/len(v):7.1f}  max {max(v)}')
    ts = sorted(r['tstates'] for r in rows); avg = sum(ts) / len(ts)
    print(f'D: avg {avg:,.0f} T ({avg/TV_FRAME:.2f} TV frames)  95th {ts[int(len(ts)*.95)]:,}  worst {ts[-1]:,} ({ts[-1]/TV_FRAME:.2f})')
    ag = {k: sum(r[k] for r in rows) / len(rows) for k in ['vfull','strips','edges','rowstrips','inserts','boundary']}
    br = {'vertex transform+project': ag['vfull']*COSTD['vfull'],
          'strip + edge setup': ag['strips']*COSTD['strip'] + ag['edges']*COSTD['edge'],
          'row stepping': ag['rowstrips']*COSTD['rowstrip'],
          'interval painting': ag['inserts']*COSTD['insert'],
          'row composition (all 2048 bytes)': H*COSTD['rowcompose'] + (2048-ag['boundary'])*COSTD['fullbyte'] + ag['boundary']*COSTD['boundary'],
          'craft sprite': COSTD['craft'], 'game logic/input/sound': COSTD['logic']}
    for k, v in br.items(): print(f'  {k:34s} {v:8,.0f}  {100*v/avg:4.1f}%')
    return frames

if __name__ == '__main__' and 'D' in sys.argv:
    main_d()
