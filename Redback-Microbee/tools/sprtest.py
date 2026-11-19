"""compositor check: every committed picture against the deck bits with the
sprites drawn on top in Python. Also measures idle time and display-time writes."""
import sys
sys.path.insert(0, '.')
import numpy as np
import scrolltest as T, rbtest, sprites
from mbee import L, FRAME_T

frames = sprites.build_frames()


def rd(pp, name, n=1):
    a = pp.S[name]
    return pp.peek(a) if n == 1 else pp.peek(a) | (pp.peek(a + 1) << 8)


def s16(v):
    return v - 65536 if v >= 32768 else v


def go(pp, pcs, maxf=3):
    for p in pcs:
        L.mb_set_bp(pp.h, p, 1)
    hit = L.mb_run(pp.h, pp.tick + maxf * FRAME_T)
    for p in pcs:
        L.mb_set_bp(pp.h, p, 0)
    return pp.cpu.pc if hit else None


def expected_with_sprites(S, k, draws):
    X = S * 8 + k
    e = T.expected(X).astype(np.uint8)
    for (f, sx, y) in draws:
        data = frames[f][2]
        h, w = data.shape
        y = min(y, 199)
        sh = sx & 7
        yo = y % 10
        cx0 = sx >> 3
        cols = (w + sh + 7) // 8
        rows = (yo + h + 9) // 10
        img = np.zeros((rows * 10, cols * 8), np.uint8)
        img[yo:yo + h, sh:sh + w] = data
        for c in range(cols):
            cx = cx0 + c
            if not 0 <= cx < 40:
                continue
            for r in range(rows):
                blk = img[r * 10:(r + 1) * 10, c * 8:(c + 1) * 8]
                if blk.any():
                    rr = y // 10 + r
                    e[rr * 10:(rr + 1) * 10, cx * 8:(cx + 1) * 8] = blk
    return e


def run(pp, nframes, keys_at, label):
    bad = tear = dsp = 0
    first = None
    idles = []
    draws_prev = None
    committed = None
    maxcl = 0
    pp.vw_sc()
    for f in range(nframes):
        pp.keys = set(keys_at(f))
        pc = go(pp, [pp.S['logic']])           # commit done
        n, last = pp.vw_sc()
        tr = pp.vw_tear()
        dsp += (1 if n else 0)
        if tr:
            tear += 1
        idles.append(rd(pp, 'idle', 2))
        if committed is not None:
            S, k, dr = committed
            img, _, _ = T.actual(pp)
            e = expected_with_sprites(S, k, dr)
            if not np.array_equal(img, e):
                bad += 1
                if first is None:
                    d = np.argwhere(img != e)
                    first = (f, S * 8 + k, len(d), d[0].tolist())
        # run this logic, recording draws
        draws = []
        L.mb_set_bp(pp.h, pp.S['spr_draw'], 1)
        L.mb_set_bp(pp.h, pp.S['frame_wait'], 1)
        while True:
            hit = L.mb_run(pp.h, pp.tick + 3 * FRAME_T)
            if not hit:
                break
            if pp.cpu.pc == pp.S['spr_draw']:
                draws.append((rd(pp, 'sp_f'), s16(rd(pp, 'sp_x', 2)), rd(pp, 'sp_y')))
            else:
                break
        L.mb_set_bp(pp.h, pp.S['spr_draw'], 0)
        L.mb_set_bp(pp.h, pp.S['frame_wait'], 0)
        committed = (rd(pp, 'sdeck', 2), rd(pp, 'kph'), draws)
        maxcl = max(maxcl, rd(pp, 'poolcnt'))
    pp.keys = set()
    idl = np.array(idles[1:])
    print('%-16s frames %3d mismatching %d  frames with writes ahead of beam %d / behind beam (tear) %d  idle iters min/avg %d/%d (=%.0f%%/%.0f%% free)  max cells %d' %
          (label, nframes, bad, dsp, tear, idl.min(), idl.mean(), idl.min() * 36 / FRAME_T * 100, idl.mean() * 36 / FRAME_T * 100, maxcl), first or '')
    return bad


if __name__ == '__main__':
    pp = rbtest.boot()
    while not pp.start_addr():
        pp.run_frames(1)
    pp.run_frames(3)
    bad = 0
    bad += run(pp, 40, lambda f: [], 'still')
    bad += run(pp, 80, lambda f: ['RIGHT'], 'right')
    bad += run(pp, 40, lambda f: ['RIGHT', 'UP'], 'right+up')
    bad += run(pp, 80, lambda f: ['LEFT', 'DOWN'], 'left+down')
    bad += run(pp, 80, lambda f: ['RIGHT'], 'right again')
    print('BAD' if bad else 'ALL EXACT')
