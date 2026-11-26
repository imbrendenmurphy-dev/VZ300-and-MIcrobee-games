"""Rotoscope Wren from Eadweard Muybridge's Animal Locomotion (1887, public domain).

ref/plate060_run.jpg        Plate 60, man running: rows 1-2 = 10 side-on frames (one full cycle)
ref/plate363_somersault.jpg Plate 363, running somersault: rows 1 and 3 = 12 side-on frames

Each cell is cut out, the background's horizontal stripes are removed (row medians),
the figure is thresholded and its largest blob kept, then the silhouettes of a set are
scaled together (Microbee pixels are ~1.14 x wider than tall) to fit the 24 x 24 sprite.

python tools/trace.py   -> build/trace_debug.png (cells + masks) and build/trace_frames.png
"""
from PIL import Image, ImageFilter
import numpy as np

K = 3840 / 2000                     # the boxes below were read off a 2000-px-wide view
PIX_ASPECT = 1.143                  # Microbee pixel width / height (336 x 288 on a 4:3 tube)
W = H = 24

def boxes(xs, ys):
    return [(int(x0 * K), int(y0 * K), int(x1 * K), int(y1 * K)) for (y0, y1) in ys for (x0, x1) in xs]

RUN = ('ref/plate060_run.jpg',
       boxes([(514, 688), (705, 888), (905, 1086), (1102, 1285), (1298, 1487)], [(382, 572), (622, 800)]))
SOM = ('ref/plate363_somersault.jpg',
       boxes([(580, 704), (718, 844), (858, 985), (998, 1125), (1139, 1265), (1280, 1407)], [(380, 556), (803, 968)]))


def smooth(g):
    return np.asarray(Image.fromarray(g.astype(np.uint8)).filter(ImageFilter.MedianFilter(5)), np.float32)


def shift_to(ref, g, r=10):
    """Vertical offset that lines g's stripes up with ref's (row-mean profiles)."""
    pr, pg = ref.mean(1) - ref.mean(), g.mean(1) - g.mean()
    n = len(pr) - 2 * r
    return max(range(-r, r + 1), key=lambda d: float(np.dot(pr[r:r + n], pg[r + d:r + d + n])))


def row_masks(img, bxs):
    """One plate row (same camera set-up): rebuild the empty scene from the frames, subtract it."""
    w = min(b[2] - b[0] for b in bxs); h = min(b[3] - b[1] for b in bxs)
    raw = [smooth(np.asarray(img.crop((b[0], b[1] - 12, b[0] + w, b[1] + h + 12)).convert('L'), np.float32)) for b in bxs]
    ref = raw[0]
    gs = []
    for g in raw:
        d = shift_to(ref, g)
        gs.append(g[12 + d:12 + d + h])
    st = np.sort(np.stack(gs), axis=0)
    bg = st[1]                                         # the figure is brighter than the scene behind it
    out = []
    for g in gs:
        d = g - bg
        m = d > max(16.0, np.percentile(d, 99.3) * 0.3)
        m = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))
                       .filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))) > 127
        out.append((largest(m), g))
    return out


def largest(m):
    h, w = m.shape
    lab = np.zeros((h, w), np.int32); best, bestn, n = 0, 0, 0
    for y in range(h):
        for x in range(w):
            if m[y, x] and not lab[y, x]:
                n += 1; st = [(y, x)]; lab[y, x] = n; c = 0
                while st:
                    cy, cx = st.pop(); c += 1
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        yy, xx = cy + dy, cx + dx
                        if 0 <= yy < h and 0 <= xx < w and m[yy, xx] and not lab[yy, xx]:
                            lab[yy, xx] = n; st.append((yy, xx))
                if c > bestn: best, bestn = n, c
    sizes = np.bincount(lab.ravel())
    out = np.isin(lab, [k for k in range(1, n + 1) if sizes[k] >= 0.12 * bestn])   # limbs split off by shadow
    # fill holes (background not reachable from the border)
    inv = ~out; reach = np.zeros_like(out); st = [(y, x) for y in (0, h - 1) for x in range(w) if inv[y, x]] + \
        [(y, x) for x in (0, w - 1) for y in range(h) if inv[y, x]]
    for p in st: reach[p] = True
    while st:
        cy, cx = st.pop()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            yy, xx = cy + dy, cx + dx
            if 0 <= yy < h and 0 <= xx < w and inv[yy, xx] and not reach[yy, xx]:
                reach[yy, xx] = True; st.append((yy, xx))
    return out | (~reach & inv)


def cells(plate, per_row):
    path, bx = plate
    img = Image.open(path)
    out = []
    for r in range(0, len(bx), per_row):
        out += row_masks(img, bx[r:r + per_row])
    return out


def to_sprite(m, scale, ground, anchor_x=None, cover=0.42):
    """Mask -> 24 x 24 bitmap.  scale = sprite px per source px (vertical)."""
    ys, xs = np.nonzero(m)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    m = m[y0:y1, x0:x1].astype(np.float32)
    h = max(1, round((y1 - y0) * scale)); w = max(1, round((x1 - x0) * scale / PIX_ASPECT))
    small = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).resize((w, h), Image.BOX), np.float32) / 255
    bm = small >= cover
    out = np.zeros((H, W), bool)
    oy = H - h if ground else (H - h) // 2
    if anchor_x is None: ox = (W - w) // 2
    else: ox = round(W / 2 - (anchor_x - x0) * scale / PIX_ASPECT)
    for y in range(h):
        for x in range(w):
            if bm[y, x] and 0 <= y + oy < H and 0 <= x + ox < W: out[y + oy, x + ox] = True
    return tidy(out)


def tidy(bm):
    bm = bm.copy()
    for _ in range(2):
        for y in range(H):
            for x in range(W):
                k = sum(bm[y + dy, x + dx] for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)) if 0 <= y + dy < H and 0 <= x + dx < W)
                if not bm[y, x] and k >= 3: bm[y, x] = True
                elif bm[y, x] and k == 0: bm[y, x] = False
    return bm


def torso_x(m):
    """x of the upper body (shoulders to hips): the run's steady anchor."""
    ys, xs = np.nonzero(m)
    top, bot = ys.min(), ys.max()
    band = (ys > top + (bot - top) * 0.12) & (ys < top + (bot - top) * 0.45)
    return float(np.median(xs[band]))


def traced():
    """Frames by name, like wren_anim.FRAMES, as 24 x 24 lists of 0/1."""
    run = cells(RUN, 5); som = cells(SOM, 6)
    tall = np.median([np.ptp(np.nonzero(m)[0]) for m, _ in run])
    s_run = 23.0 / tall                                 # runner: 23 px from head to the lowest foot
    tall_s = np.ptp(np.nonzero(som[0][0])[0])             # somersault: frame 1 stands upright
    s_som = 23.5 / tall_s
    F = {}
    F['run'] = [to_sprite(m, s_run, True, torso_x(m)) for m, _ in run]
    sm = [m for m, _ in som]
    F['stand'] = [to_sprite(sm[0], s_som, True, torso_x(sm[0]))]
    air = lambda m: to_sprite(m, s_som, False)
    # vault slots (wren.asm): crouch, takeoff, 7 spin frames, opening, landing
    F['vault'] = [to_sprite(sm[1], s_som, True, torso_x(sm[1])), air(sm[2])] + \
        [air(sm[k]) for k in (3, 4, 5, 6, 7, 8, 9)] + [air(sm[10]), to_sprite(sm[9], s_som, True, torso_x(sm[9]))]
    return {k: [[[1 if v else 0 for v in row] for row in bm] for bm in fs] for k, fs in F.items()}, run, som


if __name__ == '__main__':
    F, run, som = traced()
    # debug: each cell with its mask outlined
    tiles = []
    for m, g in run + som:
        im = Image.fromarray(g.astype(np.uint8)).convert('RGB').resize((160, int(160 * g.shape[0] / g.shape[1])))
        mm = Image.fromarray((m * 255).astype(np.uint8)).resize(im.size)
        red = Image.new('RGB', im.size, (255, 40, 40))
        tiles.append(Image.composite(Image.blend(im, red, 0.45), im, mm))
    th = max(t.size[1] for t in tiles)
    sheet = Image.new('RGB', (160 * 11, th * 2), (30, 30, 30))
    for k, t in enumerate(tiles): sheet.paste(t, ((k % 11) * 160, (k // 11) * th))
    sheet.save('build/trace_debug.png')
    allf = [(n, bm) for n in ('stand', 'run', 'vault') for bm in F[n]]
    Z = 8; cols = 12
    sh = Image.new('RGB', (cols * (W + 3) * Z, ((len(allf) + cols - 1) // cols) * (H + 3) * Z), (25, 25, 60))
    for k, (n, bm) in enumerate(allf):
        ox = (k % cols) * (W + 3) * Z; oy = (k // cols) * (H + 3) * Z
        for y in range(H):
            for x in range(W):
                c = (255, 255, 255) if bm[y][x] else (0, 0, 0)
                for a in range(Z - 1):
                    for b in range(round((Z - 1) * 1.0)):
                        sh.putpixel((ox + round(x * Z * PIX_ASPECT / 1.143) + a, oy + y * Z + b), c)
    sh.save('build/trace_frames.png'); print({k: len(v) for k, v in F.items()})
