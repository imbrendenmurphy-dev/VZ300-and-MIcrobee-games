"""REDBACK deck packer: base cells -> pair glyphs (8 scroll phases) -> static slot
allocation -> the banks and column records the game reads."""
import numpy as np
from deckart import PR, CH, CW

NPH = 8
AHEAD = 2
WINDOW = 40 + 2 * AHEAD + 2      # columns two cells can both be resident
REC = NPH * CH + 1               # 80 bytes of phases + colour


def pair_glyphs(a, b):
    """phase k of the pair (a, b): the 8 pixels starting k pixels into a|b"""
    out = bytearray()
    for k in range(NPH):
        for l in range(CH):
            v = (a[l] << 8) | b[l]
            out.append((v >> (8 - k)) & 0xFF)
    return bytes(out)


def pair_colour(ca, cb, abytes):
    """one colour for the whole pair: a's, unless a has no ink pixels"""
    return cb if not any(abytes) else ca


def build(grid, order):
    R, WC = grid.shape
    pairs, pidx = [], {}
    pcol = np.zeros((WC + 2 * AHEAD + 2, R), np.int32)       # pair index per (column, row), col offset
    OFF = AHEAD + 1

    def pair_at(r, j):
        a = grid[r, j] if 0 <= j < WC else 0
        b = grid[r, j + 1] if 0 <= j + 1 < WC else 0
        key = (int(a), int(b))
        if key not in pidx:
            pidx[key] = len(pairs)
            ab, ca = order[a]
            bb, cb = order[b]
            pairs.append((key, pair_glyphs(ab, bb), pair_colour(ca, cb, ab)))
        return pidx[key]
    cols = range(-OFF, WC + OFF)
    P = {}
    for j in cols:
        for r in range(R):
            P[(j, r)] = pair_at(r, j)
    blank = pidx[(0, 0)]
    # --- static slot allocation, forward sweep
    slot_of = {}
    last = [-10 ** 9] * 128           # last column a slot's pair was used
    owner = [None] * 128              # which pair it holds
    cur = {}                          # pair -> slot, while within the window
    worst = 0
    for j in cols:
        used_now = set()
        for r in range(R):
            p = P[(j, r)]
            if p == blank:
                slot_of[(j, r)] = 0
                continue
            s = cur.get(p)
            if s is not None and j - last[s] <= WINDOW and owner[s] == p:
                pass
            else:
                free = [x for x in range(1, 128) if j - last[x] > WINDOW and x not in used_now]
                if not free:
                    raise SystemExit('out of slots at column %d row %d' % (j, r))
                s = min(free, key=lambda x: last[x])
                owner[s] = p
                cur[p] = s
            last[s] = j
            used_now.add(s)
            slot_of[(j, r)] = s
        busy = sum(1 for x in range(1, 128) if j - last[x] <= WINDOW)
        worst = max(worst, busy)
    return pairs, P, slot_of, blank, worst, OFF


def stats(pairs, P, slot_of, blank, WC, OFF, R):
    """loads needed when each column enters (forward), assuming a resident table"""
    res = {}
    loads = []
    for j in range(-OFF, WC + OFF):
        n = 0
        for r in range(R):
            s = slot_of[(j, r)]
            if s and res.get(s) != P[(j, r)]:
                res[s] = P[(j, r)]
                n += 1
        loads.append(n)
    return loads
