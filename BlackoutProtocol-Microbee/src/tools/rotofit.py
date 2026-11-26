"""Rotoscope Wren: fit the skeleton (wren_anim) to Muybridge's photographs.

For each traced frame (tools/trace.py: the figure cut out of the plate), search the
pose - body lean, spin, hip/knee/foot and shoulder/elbow angles, position - whose
silhouette best overlaps the photo (IoU), starting from the last frame's pose.  The
fitted poses are saved to tools/roto_poses.json, and wren_anim uses them for the run,
the stand and the vault, so Wren moves like the 1887 athletes but keeps a clean,
readable 24 x 24 body.

python tools/rotofit.py      (slow: a minute or two)  -> tools/roto_poses.json, build/roto_fit.png
"""
import json, math, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, 'tools')
import trace, wren_anim as wa

FH = 110                                   # fit at this many pixels of standing height
PARAMS = ['lean', 'rot', 'hipA', 'kneeA', 'footA', 'hipB', 'kneeB', 'footB', 'shA', 'elA', 'shB', 'elB', 'head', 'tx', 'ty']
STEP0 = dict(lean=12, rot=20, hipA=15, kneeA=15, footA=15, hipB=15, kneeB=15, footB=15, shA=20, elA=20, shB=20, elB=20,
             head=8, tx=6, ty=6)
LIMIT = dict(kneeA=(0, 160), kneeB=(0, 160), elA=(0, 150), elB=(0, 150), footA=(40, 160), footB=(40, 160), head=(-30, 40))


def closed(m):
    im = Image.fromarray((m * 255).astype(np.uint8))
    for f in (ImageFilter.MaxFilter(7), ImageFilter.MinFilter(7)):
        im = im.filter(f)
    return np.asarray(im) > 127


def prep(m, unit):
    """Mask cropped to its box (+margin), scaled so `unit` source px = FH fit px."""
    ys, xs = np.nonzero(m)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    k = FH / unit
    w, h = max(2, round((x1 - x0) * k)), max(2, round((y1 - y0) * k))
    small = np.asarray(Image.fromarray((m[y0:y1, x0:x1] * 255).astype(np.uint8)).resize((w, h), Image.BILINEAR)) > 127
    M = 30
    out = np.zeros((h + 2 * M, w + 2 * M), bool); out[M:M + h, M:M + w] = small
    return out


def draw(p, shape, sc):
    """Skeleton silhouette in fit space; pose p is a dict (tx, ty = hip position)."""
    pose = wa.Pose(**{k: v for k, v in p.items() if k not in ('tx', 'ty')}, ground=False)
    j = wa.joints(pose)
    img = Image.new('L', (shape[1], shape[0]), 0); d = ImageDraw.Draw(img)
    hx, hy = j['hip']
    P = lambda q: ((q[0] - hx) * sc + p['tx'], (q[1] - hy) * sc + p['ty'])
    def limb(a, b, w):
        w = w * sc; d.line([P(a), P(b)], fill=255, width=max(1, int(w)))
        for q in (a, b):
            x, y = P(q); r = w / 2; d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    for s in 'AB':
        limb(j['hip'], j['knee' + s], wa.WID['thigh']); limb(j['knee' + s], j['ankle' + s], wa.WID['shin'])
        limb(j['ankle' + s], j['toe' + s], wa.WID['foot'])
        limb(j['sh'], j['elbow' + s], wa.WID['uarm']); limb(j['elbow' + s], j['hand' + s], wa.WID['farm'])
    limb(j['hip'], j['sh'], wa.WID['torso'])
    x, y = P(j['head']); r = wa.HEAD_R * sc; d.ellipse([x - r, y - r * 1.08, x + r, y + r * 1.08], fill=255)
    return np.asarray(img) > 127


def iou(a, b):
    i = np.logical_and(a, b).sum(); u = np.logical_or(a, b).sum()
    return i / u if u else 0


def fit(mask, sc, starts, iters=1400, seed=1):
    rnd = random.Random(seed)
    best, bs = None, -1
    for s in starts:                                   # place each start on the mask's middle
        ys, xs = np.nonzero(mask)
        p = dict(s); p.setdefault('tx', float(xs.mean())); p.setdefault('ty', float(ys.mean()))
        v = iou(draw(p, mask.shape, sc), mask)
        if v > bs: best, bs = p, v
    p, v = dict(best), bs
    step = dict(STEP0)
    for it in range(iters):
        k = rnd.choice(PARAMS)
        q = dict(p); q[k] = q.get(k, 0) + rnd.choice((-1, 1)) * step[k] * rnd.random()
        if k in LIMIT: q[k] = min(max(q[k], LIMIT[k][0]), LIMIT[k][1])
        w = iou(draw(q, mask.shape, sc), mask)
        if w >= v: p, v = q, w
        if it % 200 == 199:
            for kk in step: step[kk] *= 0.7
    return p, v


def pose_dict(P):
    return {k: getattr(P, k) for k in PARAMS[:-2]}


if __name__ == '__main__':
    run = [(closed(m), g) for m, g in trace.cells(trace.RUN, 5)]
    som = [(closed(m), g) for m, g in trace.cells(trace.SOM, 6)]
    skel_h = 2 * wa.HEAD_R + wa.NECK + wa.TORSO + wa.THIGH + wa.SHIN       # head top to ankle, standing
    unit_run = np.median([np.ptp(np.nonzero(m)[0]) for m, _ in run]) * 1.04
    unit_som = np.ptp(np.nonzero(som[0][0])[0]) * 1.0
    sc = FH / skel_h
    out, previews = {'run': [], 'vault_src': []}, []
    prev = None
    for n, (m, _) in enumerate(run):
        M = prep(m, unit_run)
        starts = [pose_dict(wa.run_pose(t / 20)) for t in range(20)] + ([prev] if prev else [])
        p, v = fit(M, sc, starts, seed=n)
        prev = p; out['run'].append(p); previews.append((M, draw(p, M.shape, sc), v))
        print(f'run {n}: IoU {v:.2f}', flush=True)
    cands = [pose_dict(x) for x in (wa.STAND, wa.CROUCH, wa.TAKEOFF, wa.OPEN, wa.LAND)] + \
            [pose_dict(wa.tuck(45 * i)) for i in range(8)]
    prev = None
    for n, (m, _) in enumerate(som):
        M = prep(m, unit_som)
        p, v = fit(M, sc, cands + ([prev] if prev else []), iters=1800, seed=100 + n)
        prev = p; out['vault_src'].append(p); previews.append((M, draw(p, M.shape, sc), v))
        print(f'somersault {n}: IoU {v:.2f}', flush=True)
    json.dump(out, open('tools/roto_poses.json', 'w'), indent=1)
    # preview: photo mask grey, fitted skeleton red
    tiles = []
    for M, S, v in previews:
        rgb = np.zeros(M.shape + (3,), np.uint8); rgb[M] = (90, 90, 90); rgb[S] = (230, 60, 60); rgb[M & S] = (255, 170, 170)
        tiles.append(Image.fromarray(rgb).resize((120, round(120 * M.shape[0] / M.shape[1]))))
    th = max(t.size[1] for t in tiles)
    sheet = Image.new('RGB', (120 * 11, th * 2), (20, 20, 40))
    for k, t in enumerate(tiles): sheet.paste(t, ((k % 11) * 120, (k // 11) * th))
    sheet.save('build/roto_fit.png')
