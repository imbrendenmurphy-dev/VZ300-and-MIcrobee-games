"""STORMBELL: build everything into build/ (VIBED BY BPM 2026).

    python3 tools/build.py

1. font, HUD glyphs and the seven pictures -> GFX0.BNK, GFX1.BNK
2. the six fighters, sixteen frames each   -> F0.BNK .. F5.BNK, src/ftab.inc
3. music and sound tables                  -> src/snd.inc
4. the program (src/main.asm)              -> STORM.BIN
5. the CP/M loader (src/loader.asm)        -> STORM.COM
6. the disk                                -> STORM.DS8
"""
import os
import sys
import subprocess
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
BUILD = ROOT / 'build'
SRC = ROOT / 'src'
sys.path.insert(0, str(HERE))
BUILD.mkdir(exist_ok=True)

import art
import stages as SG
import fighters as F
import music

BLK_FIGHT = 4            # fighters: blocks 4..9
BLK_GFX = 10             # font, the title and the ending
BLK_STG = 11             # the five stages: blocks 11..15
SCN_BANK = 1             # PCG banks 1..4: the stage on show (512 glyphs)
SCN_GLYPHS = 4 * 128
HERO_BANK = 5            # PCG banks 5..9 (640 glyphs)
HERO_BANKS = 5
FOE_BANK = 10            # PCG banks 10..15 (768 glyphs)
FOE_BANKS = 6
PIC_SLOT = 0x2000
CELL = art.CELL              # lines a cell (10)
FR_BASE = 0x0100         # frame records
GL_BASE = 0x4000         # glyph records: 10 pattern bytes + 10 mask bytes


def dilate8(m):
    o = F.dilate(m)
    o[1:, 1:] |= m[:-1, :-1]
    o[1:, :-1] |= m[:-1, 1:]
    o[:-1, 1:] |= m[1:, :-1]
    o[:-1, :-1] |= m[1:, 1:]
    return o


def rowbytes(cell):
    return bytes(int(sum(128 >> x for x in range(8) if cell[y, x])) for y in range(CELL))


def merge_glyphs(keys, uses, limit):
    """keys: list of 16-byte glyphs (pattern + mask); uses: how many cells
    use each. While there are more than `limit`, the glyph that costs
    least to lose (fewest differing pixels times uses) is replaced by its
    nearest neighbour. Returns a map old index -> new index and the new
    key list."""
    n = len(keys)
    remap = list(range(n))
    if n <= limit:
        return remap, keys
    bits = np.unpackbits(np.frombuffer(b''.join(k[:CELL] for k in keys), np.uint8).reshape(n, CELL), axis=1).astype(np.int16)
    alive = np.ones(n, bool)
    uses = np.array(uses, float)
    while alive.sum() > limit:
        idx = np.where(alive)[0]
        b = bits[idx]
        d = (b[:, None, :] != b[None, :, :]).sum(axis=2).astype(float)
        np.fill_diagonal(d, 1e9)
        nn = d.argmin(axis=1)
        cost = d[np.arange(len(idx)), nn] * uses[idx]
        order = np.argsort(cost)
        gone = set()
        k = min(int(alive.sum() - limit), max(1, len(idx) // 50))
        for j in order:
            if k == 0:
                break
            a, t = idx[j], idx[nn[j]]
            if a in gone or t in gone:
                continue
            alive[a] = False
            uses[t] += uses[a]
            for q in range(n):
                if remap[q] == a:
                    remap[q] = t
            gone.add(a)
            gone.add(t)
            k -= 1
    # renumber the survivors
    live = [i for i in range(n) if alive[i]]
    newno = {o: i for i, o in enumerate(live)}
    return [newno[remap[i]] for i in range(n)], [keys[i] for i in live]


def pack_fighter(idx, f):
    mirror = idx > 0
    bank0 = FOE_BANK if mirror else HERO_BANK
    limit = (FOE_BANKS if mirror else HERO_BANKS) * 128
    frs = F.frames(f, mirror)
    glyphs = {}
    uses = []
    raw = []
    info = {}
    anchor = F.CW - 1 - F.AC if mirror else F.AC
    for name, ink, col, jt in frs:
        mask = dilate8(ink)
        cc = F.cellcol(ink, col)
        cells = ink.reshape(F.CH, CELL, F.CW, 8).any(axis=(1, 3))
        ys, xs = np.where(cells)
        x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
        w, h = x1 - x0 + 1, y1 - y0 + 1
        cl = []
        for cy in range(y0, y1 + 1):
            for cx in range(x0, x1 + 1):
                if not cells[cy, cx]:
                    cl.append(None)
                    continue
                key = rowbytes(ink[cy * CELL:cy * CELL + CELL, cx * 8:cx * 8 + 8]) + rowbytes(mask[cy * CELL:cy * CELL + CELL, cx * 8:cx * 8 + 8])
                if key not in glyphs:
                    glyphs[key] = len(glyphs)
                    uses.append(0)
                uses[glyphs[key]] += 1
                cl.append((glyphs[key], int(cc[cy, cx])))
        raw.append(((w, h, anchor - x0, y0), cl))
        # how far this frame reaches towards the opponent, from the anchor cell's centre
        px = np.where(ink.any(axis=0))[0]
        ax = anchor * 8 + 4
        info[name] = (ax - px.min()) if mirror else (px.max() + 1 - ax)
    nraw = len(glyphs)
    keys = list(glyphs.keys())
    remap, keys = merge_glyphs(keys, uses, limit)
    glyphs = {k: i for i, k in enumerate(keys)}
    recs = []
    for hdr, cl in raw:
        rec = bytearray(hdr)
        for c in cl:
            if c is None:
                rec += bytes([0, 0, 0])
            else:
                g = remap[c[0]]
                rec += bytes([0x80 | (g & 127), bank0 + (g >> 7), c[1]])
        recs.append(bytes(rec))
    if nraw > len(keys):
        print('  %-8s %d glyphs merged into near neighbours' % (f.key, nraw - len(keys)))
    assert len(glyphs) <= limit, '%s: %d glyphs, room for %d' % (f.key, len(glyphs), limit)
    # the front of the body: the standing frame, from the hips up
    name, ink, col, jt = frs[F.NAMES.index('stand')]
    top = np.where(ink.any(axis=1))[0].min()
    body = ink[top:top + 36]
    px = np.where(body.any(axis=0))[0]
    ax = anchor * 8 + 4
    front = (ax - px.min()) if mirror else (px.max() + 1 - ax)
    blk = bytearray(0x8000)
    blk[0:2] = len(glyphs).to_bytes(2, 'little')
    blk[2] = info['punch']
    blk[3] = info['kick']
    blk[4] = front
    off = FR_BASE
    for i, r in enumerate(recs):
        blk[0x10 + i * 2:0x12 + i * 2] = off.to_bytes(2, 'little')
        blk[off:off + len(r)] = r
        off += len(r)
    assert off <= GL_BASE
    for key, g in glyphs.items():
        blk[GL_BASE + g * 2 * CELL:GL_BASE + (g + 1) * 2 * CELL] = key
    used = GL_BASE + len(glyphs) * 2 * CELL
    assert used <= 0x8000
    print('  %-8s %4d glyphs (room %d), frames %5d bytes, punch %2d px, kick %2d px, body %2d px' % (
        f.key, len(glyphs), limit, off - FR_BASE, info['punch'], info['kick'], front))
    return bytes(blk[:used]), dict(punch=info['punch'], kick=info['kick'], body=front)


def build_fighters():
    stats = []
    for i, f in enumerate(F.FIGHTERS):
        data, st = pack_fighter(i, f)
        (BUILD / ('F%d.BNK' % i)).write_bytes(data)
        stats.append(st)
    return stats


def build_gfx():
    """GFX0.BNK: the font (400h), then the title and the ending. A
    picture slot: codes, banks, colours (1000 each), the glyph count,
    then 512 x 10 bytes of glyphs."""
    blks = [bytearray(art.font_bytes())]
    for i, (name, fn) in enumerate([p for p in art.PICS if p[0] in ('title', 'ending')]):
        codes, banks, cols, gl, n = fn().pack(name)
        rec = codes + banks + cols + bytes([n & 255, n >> 8]) + bytes(6) + gl
        assert len(rec) <= PIC_SLOT
        rec += bytes(PIC_SLOT - len(rec))
        blks[0] += rec
        print('  picture %-7s %3d glyphs' % (name, n))
    for k, b in enumerate(blks):
        assert len(b) <= 0x8000
        (BUILD / ('GFX%d.BNK' % k)).write_bytes(bytes(b))


def pack_stage(i):
    """STGn.BNK, a stage:
      00 dw glyphs            02 db MIDW, FARW, DUEL_C, END_C
      06 dw far planes        08 dw midground planes   0A dw floor cells
      0C dw floor strips      0E dw floor phases       10 dw glyphs
    far: code, bank, colour planes of 7 rows x FARW (rows 1..7)
    mid: the same for 8 rows x MIDW (rows 8..15)
    floor cells: the same for 8 rows x 40 (rows 16..23), never moving
    floor strips: per row k, first glyph (dw), 0, dw table; a table holds
      8 shifts x k positions x 10 bytes
    floor phases: 48 x 8 bytes, the pixel offset of each row's strip for
      each camera position mod 48 pixels (the floor tile at the feet)"""
    f, m = SG.STAGES[i]()
    fi, fc, fp = f.cells()
    mi, mc, mp = m.cells()

    def pat(ink, r, c):
        cell = ink[r * CELL:r * CELL + CELL, c * 8:c * 8 + 8]
        return bytes(int(sum(128 >> x for x in range(8) if cell[y, x])) for y in range(CELL))
    glyphs = {bytes(CELL): 0}
    uses = [0]
    grid = []                       # (layer, row, col, glyph)
    for layer, ink, rows, w in (('f', fi, range(1, 8), SG.FARW), ('m', mi, range(8, 16), SG.MIDW)):
        for r in rows:
            for c in range(w):
                k = pat(ink, r, c)
                if k not in glyphs:
                    glyphs[k] = len(glyphs)
                    uses.append(0)
                uses[glyphs[k]] += 1
                grid.append((layer, r, c, glyphs[k]))
    nraw = len(glyphs)
    room = SCN_GLYPHS - sum(SG.KS)
    keys = list(glyphs.keys())
    remap, keys = merge_glyphs(keys, uses, room)
    n = len(keys)
    # planes
    def planes(rows, w, layer, ci, cp):
        code = bytearray(len(rows) * w)
        bank = bytearray(len(rows) * w)
        col = bytearray(len(rows) * w)
        return code, bank, col
    far = [bytearray(7 * SG.FARW) for _ in range(3)]
    mid = [bytearray(8 * SG.MIDW) for _ in range(3)]
    for layer, r, c, g in grid:
        g = remap[g]
        if layer == 'f':
            o = (r - 1) * SG.FARW + c
            pl, ci, cp = far, fc, fp
        else:
            o = (r - 8) * SG.MIDW + c
            pl, ci, cp = mid, mc, mp
        pl[0][o] = 0x80 | (g & 127)
        pl[1][o] = SCN_BANK + (g >> 7)
        pl[2][o] = (int(cp[r, c]) << 4) | int(ci[r, c])
    # the floor
    fl = SG.stage_floor(i)
    fcell = [bytearray(8 * 40) for _ in range(3)]
    strips = bytearray()
    tables_ = []
    g0 = n
    desc = bytearray()
    for r in range(SG.FLOOR_ROWS):
        k = SG.KS[r]
        P = 8 * k
        st = fl.strip(r)
        tab = bytearray()
        for sh in range(8):
            for q in range(k):
                for y in range(CELL):
                    v = 0
                    for b in range(8):
                        if st[y, (8 * q + sh + b) % P]:
                            v |= 128 >> b
                    tab.append(v)
        tables_.append(tab)
        colour = (fl.rows_paper[r] << 4) | fl.rows_ink[r]
        for c in range(40):
            g = g0 + (c % k)
            fcell[0][r * 40 + c] = 0x80 | (g & 127)
            fcell[1][r * 40 + c] = SCN_BANK + (g >> 7)
            fcell[2][r * 40 + c] = colour
        desc += bytes([k, g0 & 255, g0 >> 8, 0, 0, 0])      # table offset patched below
        g0 += k
    total = g0
    assert total <= SCN_GLYPHS, total
    phases = bytearray()
    for ph in range(T_FLOOR):
        for r in range(SG.FLOOR_ROWS):
            P = 8 * SG.KS[r]
            phases.append(int(round(ph * P / T_FLOOR)) % P)
    # the glyph patterns, floor glyphs at phase 0
    gl = bytearray(total * CELL)
    for k_, idx in zip(keys, range(n)):
        gl[idx * CELL:(idx + 1) * CELL] = k_
    for r in range(SG.FLOOR_ROWS):
        k = SG.KS[r]
        g = int.from_bytes(desc[r * 6 + 1:r * 6 + 3], 'little')
        gl[g * CELL:(g + k) * CELL] = tables_[r][:k * CELL]
    # lay it out
    blk = bytearray(0x20)
    def put(data):
        nonlocal blk
        o = len(blk)
        blk += data
        return o
    o_far = put(b''.join(far))
    o_mid = put(b''.join(mid))
    o_fc = put(b''.join(fcell))
    o_desc = put(desc)
    for r in range(SG.FLOOR_ROWS):
        o = put(tables_[r])
        blk[o_desc + r * 6 + 4:o_desc + r * 6 + 6] = o.to_bytes(2, 'little')
    o_ph = put(phases)
    o_gl = put(gl)
    blk[0:2] = total.to_bytes(2, 'little')
    blk[2:6] = bytes([SG.MIDW, SG.FARW, SG.DUEL_C, SG.END_C])
    for j, o in enumerate((o_far, o_mid, o_fc, o_desc, o_ph, o_gl)):
        blk[6 + j * 2:8 + j * 2] = o.to_bytes(2, 'little')
    assert len(blk) <= 0x8000, len(blk)
    (BUILD / ('STG%d.BNK' % (i + 1))).write_bytes(bytes(blk))
    print('  stage %d %-18s %3d glyphs (%d merged), %5d bytes' % (i + 1, SG.NAMES[i], total, nraw - n, len(blk)))


T_FLOOR = SG.T


def build_stages():
    for i in range(len(SG.STAGES)):
        pack_stage(i)


def tables(stats):
    """names, hints and ranges for the game (src/ftab.inc)"""
    L = ['; generated by tools/build.py', 'F_FRAMES equ %d' % len(F.POSES)]
    for i, n in enumerate(F.NAMES):
        L.append('FR_%s equ %d' % (n.upper(), i))
    hero = stats[0]
    L.append('; ranges in cells: an attack lands when the fighters are this close')
    L.append('rangetab:')
    for i, st in enumerate(stats[1:], 1):
        # hero's punch and kick against this body; this foe's against the hero's
        hp = (hero['punch'] + st['body'] + 3) // 8
        hk = (hero['kick'] + st['body'] + 3) // 8
        fp = (st['punch'] + hero['body'] + 3) // 8
        fk = (st['kick'] + hero['body'] + 3) // 8
        # the rules, not the rulers: only Old Reed's long legs out-reach
        # Wren. Against the others Wren's blows reach as far as theirs (a
        # few pixels of a bigger fighter's limb should not decide a duel)
        if F.FIGHTERS[i].key != 'REED':
            hp, hk = max(hp, fp), max(hk, fk)
        L.append('\tdb %d,%d,%d,%d\t; %s' % (hp, hk, fp, fk, F.FIGHTERS[i].key))
        print('  ranges vs %-8s hero punch %d kick %d, foe punch %d kick %d' % (F.FIGHTERS[i].key, hp, hk, fp, fk))
    L.append('nametab:')
    for i, f in enumerate(F.FIGHTERS):
        L.append('\tdw name%d' % i)
    for i, f in enumerate(F.FIGHTERS):
        L.append('name%d:\tdb "%s",0' % (i, f.name))
    L.append('hinttab:')
    for i, f in enumerate(F.FIGHTERS[1:], 1):
        L.append('\tdw hint%da,hint%db' % (i, i))
    for i, f in enumerate(F.FIGHTERS[1:], 1):
        L.append('hint%da:\tdb "%s",0' % (i, f.hint[0]))
        L.append('hint%db:\tdb "%s",0' % (i, f.hint[1]))
    L.append('stagetab:')
    for i, n in enumerate(SG.NAMES):
        L.append('\tdw stage%d' % i)
    for i, n in enumerate(SG.NAMES):
        L.append('stage%d:\tdb "%s",0' % (i, n))
    (SRC / 'ftab.inc').write_text('\n'.join(L) + '\n')


def loadfiles():
    names = [('STG_PROG', 0, 'STORM', 'BIN')]
    for i in range(len(F.FIGHTERS)):
        names.append((BLK_FIGHT + i, 0, 'F%d' % i, 'BNK'))
    names.append((BLK_GFX, 0, 'GFX0', 'BNK'))
    for i in range(len(SG.STAGES)):
        names.append((BLK_STG + i, 0, 'STG%d' % (i + 1), 'BNK'))
    for b, o, n, e in names:
        assert b == 'STG_PROG' or 4 <= b <= 22, b      # the blocks proven safe while CP/M is alive
    lines = ['\tDB %s, $%02X, "%-8s%s"' % (b, o, n, e) for b, o, n, e in names]
    (SRC / 'loadfiles.inc').write_text('\n'.join(lines) + '\n')
    return names


def assemble():
    zasm = str(HERE / 'zasm.py')
    subprocess.check_call([sys.executable, zasm, 'main.asm', '--sym=../build/main.sym'], cwd=SRC)
    sz = (BUILD / 'STORM.BIN').stat().st_size
    plen = (sz + 255) // 256 * 256
    (SRC / 'proglen.inc').write_text('PROG_LEN    EQU $%04X\n' % plen)
    print('STORM.BIN %d bytes (8000h-%04Xh)' % (sz, 0x8000 + sz))
    subprocess.check_call([sys.executable, zasm, 'loader.asm', '--sym=../build/loader.sym'], cwd=SRC)


def disk(names):
    import build_disk as BD
    sysdisk = (ROOT / 'resources' / 'boot_tracks.bin').read_bytes()
    files = {'STORM.COM': (BUILD / 'STORM.COM').read_bytes()}
    for b, o, n, e in names:
        files['%s.%s' % (n, e)] = (BUILD / ('%s.%s' % (n, e))).read_bytes()
    files['CCP.SYS'] = (ROOT / 'resources' / 'CCP.SYS').read_bytes()
    readme = ROOT / 'docs' / 'DISK_README.TXT'
    files['README.TXT'] = readme.read_text().replace('\r\n', '\n').replace('\n', '\r\n').encode('ascii') + b'\x1a'
    used = BD.build_disk(sysdisk, files, BUILD / 'STORM.DS8')
    # read the image back and check every file
    back = BD.read_dir(BD.unskew((BUILD / 'STORM.DS8').read_bytes()))
    for n, d in files.items():
        assert back[n][:len(d)] == d, n
    print('STORM.DS8: %d of 196 blocks used, %d files, read back and checked' % (used, len(files)))


if __name__ == '__main__':
    print('pictures')
    build_gfx()
    print('stages')
    build_stages()
    print('fighters')
    stats = build_fighters()
    tables(stats)
    music.build(SRC / 'snd.inc')
    names = loadfiles()
    if '--art' not in sys.argv:
        assemble()
        disk(names)
