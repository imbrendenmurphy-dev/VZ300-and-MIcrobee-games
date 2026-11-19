"""pixel-exact scroll check: displayed bits vs the deck grid, both directions"""
import sys, pickle
sys.path.insert(0, '.')
import numpy as np
import rbtest, run
from mbee import Mbee

B = rbtest.B
grid = np.load(B / 'deck_grid.npy')
order = pickle.load(open(B / 'deck_order.pkl', 'rb'))
OFF = 3
R, WC = grid.shape
cellbits = {}
for cid, (bs, col) in enumerate(order):
    cellbits[cid] = np.array([[(b >> (7 - x)) & 1 for x in range(8)] for b in bs], np.uint8)   # 10 x 8
blank = np.zeros((10, 8), np.uint8)


def expected(X):
    """23 rows x 320 px of bits for scroll position X (playfield rows)"""
    out = np.zeros((R * 10, 320), np.uint8)
    for r in range(R):
        for x0 in range(0, 320 + 8, 8):
            pass
    cols = []
    # world pixel columns X .. X+319 ; deck column jj = px // 8 ; grid col = jj - OFF
    for xp in range(320):
        w = X + xp
        jj, b = divmod(w, 8)
        j = jj - OFF
        for r in range(R):
            cid = int(grid[r, j]) if 0 <= j < WC else 0
            bits = cellbits.get(cid, blank)
            out[r * 10:(r + 1) * 10, xp] = bits[:, b]
    return out


def actual(pp):
    cols, rows = 40, 25
    start = pp.start_addr()
    a = (start + np.arange(rows * cols)) & 0x7FF
    ch = pp.scr[a].astype(np.int32)
    at = pp.attr[a].astype(np.int32)
    base = (at & 15) * 2048 + (ch & 0x7F) * 16
    g = pp.pcg[(base[:, None] + np.arange(10)[None, :])]
    g = np.where((ch & 0x80)[:, None] != 0, g, 0)
    bits = ((g[:, :, None] >> (7 - np.arange(8))[None, None, :]) & 1).astype(np.uint8)
    img = bits.reshape(rows, cols, 10, 8).transpose(0, 2, 1, 3).reshape(rows * 10, cols * 8)
    kk = int(at[40 + 5]) & 15      # attribute of a playfield cell
    return img[10:240], start - 0x100, kk


def check(pp, nframes, keys, label):
    pp.keys = set(keys)
    bad = 0
    firstbad = None
    xs = []
    tear = 0
    pp.vw_sc()
    for f in range(nframes):
        pp.run_frames(1)
        n, last = pp.vw_sc()
        if n:
            tear += 1
        img, S, k = actual(pp)
        X = S * 8 + k
        xs.append(X)
        e = expected(X)
        if not np.array_equal(img, e):
            bad += 1
            if firstbad is None:
                d = np.argwhere(img != e)
                firstbad = (f, X, len(d), d[0].tolist())
    pp.keys = set()
    steps = np.diff(xs)
    print('%-18s frames %3d  X %4d..%4d  max step %d  mismatching frames %d  frames with display-time writes %d  %s' %
          (label, nframes, min(xs), max(xs), int(np.abs(steps).max()) if len(steps) else 0, bad, tear, firstbad or ''))
    return bad


if __name__ == '__main__':
    pp = rbtest.boot()
    while not pp.start_addr():
        pp.run_frames(1)
    pp.poke(pp.S['nospr'], 1)
    pp.run_frames(5)
    bad = 0
    bad += check(pp, 60, ['RIGHT'], 'accelerate right')
    bad += check(pp, 40, [], 'coast')
    bad += check(pp, 90, ['LEFT'], 'reverse to left')
    bad += check(pp, 60, [], 'coast left')
    bad += check(pp, 100, ['RIGHT'], 'right again')
    print('BAD' if bad else 'ALL EXACT')
