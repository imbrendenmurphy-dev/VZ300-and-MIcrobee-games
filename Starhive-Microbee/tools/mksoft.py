"""STARHIVE software fine scroll: data builder for SOFTSCRL.

The monitor won't take a changing frame length, so the 6545's R5 can't be
used. Instead the frame stays fixed (312 lines) and:
  - coarse scroll: start address back 40 cells (one cell row, 11 lines);
  - fine scroll k = 0..10: every scenery cell shows a pre-drawn PAIR
    glyph = the bottom k lines of the cell above + the top 11-k lines of
    its own cell. Phase k of all pairs lives in PCG bank k (banks 0-10),
    at code 80h + slot, so one attribute write per scenery cell per frame
    moves everything down a line. Empty pairs are far-star cells (bank 11).
  - 128 pair slots; pairs are loaded into slots just before their row
    scrolls on (a schedule worked out here), so a level may use thousands.

Writes build/ROWS*.BNK (row records), PAIRS*.BNK (phase glyphs),
SCHED.BNK (load schedule) and build/soft.inc."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
import gfx
import art
import font
import space
from gfx import BLACK

ROOT = Path(__file__).resolve().parent.parent
B = ROOT / 'build'
CL, COLS = 11, 40
VIS = 22                # playfield rows on screen
NSLOT = 128
CAP = 16                # loads per step (between two coarse steps)
LOOK = 3                # how many steps early a load may be done
STAR_BANK = 11
BLK_ROWS, BLK_PAIRS = 8, 13
ROWS_PER_BLK = 128
PAIRS_PER_BLK = 128


def cell_px(img, rt, c):
    return img[rt * CL:(rt + 1) * CL, c * 8:(c + 1) * 8]


def best2(seg):
    """one cell's pixels -> glyph, colour: black is the paper whenever it
    is there, the commonest other colour is the ink"""
    vals, counts = np.unique(seg, return_counts=True)
    order = [int(v) for c, v in sorted(zip(counts, vals), reverse=True)]
    other = [v for v in order if v != BLACK]
    if not other:
        return (0,) * CL, 0
    ink = other[0]
    paper = BLACK if BLACK in order else (other[1] if len(other) > 1 else BLACK)
    g = tuple(gfx.byte8([seg[y, x] != paper and (seg[y, x] == ink or paper != BLACK or True)
 for x in range(8)]) for y in range(CL))
    return g, (paper << 4) | ink


def build(sp):
    b = sp.build()
    img = b['img']
    R = b['nrows']
    H = sp.img.shape[0]
    empty = np.zeros((R, COLS), bool)          # by map row r (0 = bottom)
    for r in range(R):
        rt = (H // CL) - 1 - r
        for c in range(COLS):
            empty[r, c] = (cell_px(sp.img, rt, c) < 0).all()
    C = b['C']

    def px(r, c):
        if r >= R:
            return np.full((CL, 8), BLACK, np.int16), BLACK
        rt = (H // CL) - 1 - r
        return cell_px(img, rt, c), C[rt][c]

    def colours(col):
        return col >> 4, col & 15

    pairs, pid = [], {}
    rows = []
    for r in range(R):
        rec = []
        for c in range(COLS):
            up_empty = (r + 1 >= R) or empty[r + 1, c]
            if empty[r, c] and up_empty:
                rec.append(None)
                continue
            Lp, Lc = px(r, c)
            Up, Uc = px(r + 1, c)
            strip = np.vstack([Up, Lp])
            ph, cols = [], []
            for k in range(CL):
                seg = strip[CL - k:2 * CL - k]
                g, col = best2(seg)
                ph.append(g)
                cols.append(col)
            colL, colU = tuple(cols), None
            key = (tuple(ph), colL)
            if key not in pid:
                pid[key] = len(pairs)
                pairs.append(key)
            rec.append(pid[key])
        rows.append(rec)
    return b, rows, pairs


def schedule(rows):
    """slot for every pair cell of every row, and when to load it.
    Group u is loaded after coarse step u-1 and before step u (rows
    u-22 .. u-1 are on screen then); row T scrolls on at step T."""
    R = len(rows)
    first = VIS - 1                      # rows 0..21 are loaded at start-up
    slot_pair = [None] * NSLOT
    slot_last = [-10 ** 9] * NSLOT
    pair_slot = {}
    groups = {}
    count = {}
    slots = []
    peak = 0
    for T in range(R):
        rs = []
        for p in rows[T]:
            if p is None:
                rs.append(None)
                continue
            s = pair_slot.get(p)
            if s is not None and slot_pair[s] == p and slot_last[s] >= T - VIS:
                slot_last[s] = T
                rs.append(s)
                continue
            done = False
            ulist = [first] if T <= first else list(range(T, max(first + 1, T - LOOK) - 1, -1))
            for u in ulist:
                if u > first and count.get(u, 0) >= CAP:
                    continue
                free = [i for i in range(NSLOT) if slot_last[i] < u - VIS]
                if not free:
                    continue
                s = min(free, key=lambda i: slot_last[i])
                slot_pair[s] = p
                slot_last[s] = T
                pair_slot[p] = s
                groups.setdefault(u, []).append((s, p))
                count[u] = count.get(u, 0) + 1
                done = True
                break
            if not done:
                raise SystemExit('row %d: no free pair slot (too many different cells on screen)' % T)
            rs.append(s)
        slots.append(rs)
        inuse = sum(1 for i in range(NSLOT) if slot_last[i] >= T - VIS + 1)
        peak = max(peak, inuse)
    return slots, groups, peak


def main():
    sp = space.build_test()
    b, rows, pairs = build(sp)
    R = len(rows)
    slots, groups, peak = schedule(rows)
    loads = sum(len(g) for g in groups.values())
    print('rows %d, pairs %d, peak slots in use %d/%d, loads %d (max/step %d)' % (
        R, len(pairs), peak, NSLOT, loads, max(len(g) for u, g in groups.items() if u > VIS - 1)))
    stars = {}
    vcol = b['vcol']

    # ---- row records (256 bytes): codes[40] attrs[40] colours[40] n (col colL colU)*n
    nrb = (R + ROWS_PER_BLK - 1) // ROWS_PER_BLK
    rblk = [bytearray(0x8000) for _ in range(nrb)]
    for r in range(R):
        rec = bytearray(256)
        plist = []
        for c in range(COLS):
            p = rows[r][c]
            if p is None:
                rec[c] = 0xF0 + vcol[c] * 4 + ((-r) & 3)
                rec[40 + c] = STAR_BANK
                rec[80 + c] = art.STAR_COLOUR
            else:
                s = slots[r][c]
                _, cols = pairs[p]
                rec[c] = 0x80 + s
                rec[40 + c] = 0
                rec[80 + c] = cols[0]
                plist.append((c, s))
        rec[120] = len(plist)
        for i, (c, s) in enumerate(plist):
            rec[121 + 2 * i:123 + 2 * i] = bytes((c, s))
        o = (r % ROWS_PER_BLK) * 256
        rblk[r // ROWS_PER_BLK][o:o + 256] = rec
    # ---- pair records (256 apart): 11 phases x 11 bytes, then 11 colours
    npb = (len(pairs) + PAIRS_PER_BLK - 1) // PAIRS_PER_BLK
    assert BLK_ROWS + nrb <= BLK_PAIRS and BLK_PAIRS + npb + 1 <= 27, 'out of blocks'
    pblk = [bytearray(0x8000) for _ in range(npb)]
    for i, (ph, cols) in enumerate(pairs):
        o = (i % PAIRS_PER_BLK) * 256
        pblk[i // PAIRS_PER_BLK][o:o + 132] = bytes(x for g in ph for x in g) + bytes(cols)
    # ---- schedule: dw offset[R]; groups: n, (slot, id lo, id hi)*n
    sch = bytearray(2 * R)
    for u in range(R):
        g = groups.get(u, [])
        o = len(sch)
        sch[2 * u:2 * u + 2] = o.to_bytes(2, 'little')
        sch.append(len(g))
        for s, p in g:
            sch += bytes((s, p & 255, p >> 8))
    assert len(sch) <= 0x8000
    files = []

    def trim(bb):
        n = len(bb)
        while n > 128 and not any(bb[n - 128:n]):
            n -= 128
        return bytes(bb[:max(n, 128)])
    for i, bb in enumerate(rblk):
        (B / ('ROWS%d.BNK' % i)).write_bytes(trim(bb))
        files.append((BLK_ROWS + i, 'ROWS%d   BNK' % i))
    for i, bb in enumerate(pblk):
        (B / ('PAIRS%d.BNK' % i)).write_bytes(trim(bb))
        files.append((BLK_PAIRS + i, 'PAIRS%d  BNK' % i))
    blk_sched = BLK_PAIRS + npb
    (B / 'SCHED.BNK').write_bytes(bytes(sch))
    files.append((blk_sched, 'SCHED   BNK'))
    total = sum((B / f.replace(' ', '').replace('BNK', '.BNK')).stat().st_size for _, f in files)
    print('data files: %d, %d KB' % (len(files), total // 1024))

    # ---- soft.inc: constants, star textures, font, HUD text
    h = ['; generated by tools/mksoft.py']
    h.append('NROWS\tequ %d' % R)
    h.append('BLK_ROWS\tequ %d' % BLK_ROWS)
    h.append('BLK_PAIRS\tequ %d' % BLK_PAIRS)
    h.append('BLK_SCHED\tequ %d' % blk_sched)
    h.append('STAR_BANK\tequ %d' % STAR_BANK)
    h.append('STAR_COL\tequ %d' % art.STAR_COLOUR)
    tex = art.star_textures()
    for v in range(4):
        h.append('star_tex%d:\tdb %s' % (v, ','.join('$%02X' % x for x in tex[v] + tex[v])))
    # font glyphs: code 81h + index in font.ORDER (space = 80h black)
    fg = []
    for ch in font.ORDER[1:]:
        g = list(font.glyph(ch)[:7])
        fg += [0, 0] + g + [0, 0] + [0] * 5
    h.append('N_FONT\tequ %d' % (len(font.ORDER) - 1))
    for i in range(0, len(fg), 16):
        h.append(('font_gl:' if i == 0 else '') + '\tdb ' + ','.join('$%02X' % x for x in fg[i:i + 16]))
    fmap = [0x80] * 64
    for i, ch in enumerate(font.ORDER):
        if 32 <= ord(ch) < 96:
            fmap[ord(ch) - 32] = 0x80 + i
    h.append('font_map:\tdb ' + ','.join('$%02X' % x for x in fmap))
    (B / 'soft.inc').write_text('\n'.join(h) + '\n')
    (B / 'soft_files.inc').write_text(''.join('\tDB %d,"%s"\n' % (blk, name) for blk, name in files))
    (B / 'soft_files.txt').write_text('\n'.join(n.replace(' ', '').replace('BNK', '.BNK') for _, n in files))

    # ---- preview: phase 0 picture of the first screen, from the data
    from PIL import Image
    out = np.zeros((VIS * CL, COLS * 8, 3), np.uint8)
    for d in range(VIS):
        r = VIS - 1 - d
        for c in range(COLS):
            p = rows[r][c]
            if p is None:
                continue
            ph, cols = pairs[p]
            g, colL = ph[0], cols[0]
            fgc, bgc = gfx.PAL[colL & 15], gfx.PAL[colL >> 4]
            for y in range(CL):
                for x in range(8):
                    out[d * CL + y, c * 8 + x] = fgc if (g[y] >> (7 - x)) & 1 else bgc
    Image.fromarray(out).save(B / 'soft_preview.png')


if __name__ == '__main__':
    main()
