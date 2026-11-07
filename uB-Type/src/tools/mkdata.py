"""Build uB-TYPE data: per-stage terrain glyphs + scroll tables, sprite sets,
parallax band, boss bodies, and the VZ-derived game tables.

Outputs (build/):
  vzdata.inc      game tables shared with the VZ logic (sprite ids, hit boxes,
                  random/sine/direction tables, level names)
  STAGEn.PCG      glyphs for PCG banks 2-9 (terrain, band, boss)  -> block 8+2n
  STAGEn.TAB      level blob + tables + sprite set (WORK at 2000h) -> block 9+2n
"""
import math
import struct
import sys
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(ROOT / 'vz'))
sys.path.insert(0, str(HERE))
import mbart as A
import levels as LV
import tiles as VT
import art as VA
import gen as VG
import lzb
import mbsprites as SPR

BUILD = ROOT / 'build'
BUILD.mkdir(exist_ok=True)

NBANK_TERR = 4      # banks 2-5
BK_TERR = 2
BK_BAND = 6
BK_BOSS = 7
STAB = 0x2000       # WORK block address of the stage tables


def glyph_alloc():
    store = {}
    order = []

    def get(g):
        if g not in store:
            store[g] = len(order)
            order.append(g)
        return store[g]
    return get, order


def stage_terrain(i, L, pal, mono=False):
    theme = L.theme
    timg = {k: A.tile_image(theme, k) for k in range(64)}
    # full tile grid as the Z80 decoder builds it
    grid = [VG.decode_column(L, x) for x in range(L.n)]
    used = set()
    pairs = set()
    for x in range(L.n):
        nx = min(x + 1, L.n - 1)
        for y in range(14):
            a, b = grid[x][y], grid[nx][y]
            used.add(a)
            used.add(b)
            pairs.add((a, b))
    used.add(0)
    pairs.add((0, 0))
    get, order = glyph_alloc()
    get(bytes(32))                       # local glyph 0 = blank (colour + mono)
    t0 = {}
    for k in sorted(used):
        lv, ac = timg[k]
        for h in range(2):
            sl = (slice(None), slice(h * 8, h * 8 + 8))
            g, c = A.quantise(lv[sl], ac[sl], pal)
            t0[(k, h)] = (get(g + A.quantise_mono(lv[sl], ac[sl])), c)
    t1 = {}
    for k in sorted(used):
        lv, ac = timg[k]
        g, c = A.quantise(lv[:, 4:12], ac[:, 4:12], pal)
        t1[k] = (get(g + A.quantise_mono(lv[:, 4:12], ac[:, 4:12])), c)
    px = {}
    plist = []
    for (a, b) in sorted(pairs):
        la, aa = timg[a]
        lb, ab = timg[b]
        lv = np.concatenate([la[:, 12:16], lb[:, 0:4]], axis=1)
        ac = np.concatenate([aa[:, 12:16], ab[:, 0:4]], axis=1)
        g, c = A.quantise(lv, ac, pal)
        key = (get(g + A.quantise_mono(lv, ac)), c)
        if key not in px:
            px[key] = len(plist)
            plist.append(key)
        px[(a, b)] = px[key]
    assert len(order) <= 128 * NBANK_TERR, 'terrain glyphs %d' % len(order)
    assert len(plist) <= 256, 'pair entries %d' % len(plist)

    def cab(gid, colr, blank_bank=0):
        if gid == 0:
            return 0x80, 0, pal['star']     # blank -> font bank glyph 0, star ink
        gid -= 1
        return 0x80 | (gid & 127), BK_TERR + (gid >> 7), colr
    # glyph store: local 1.. -> bank/code (local 0 = blank uses BK_FONT)
    glyphs = order[1:]
    T0 = [cab(*t0.get((k >> 1, k & 1), (0, 0))) for k in range(128)]
    T1 = [cab(*t1.get(k, (0, 0))) for k in range(64)]
    PX = [cab(*e) for e in plist] + [(0x80, 0, 0)] * (256 - len(plist))
    PXI = bytearray(4096)
    for (a, b) in pairs:
        PXI[a * 64 + b] = px[(a, b)]
    return dict(glyphs=glyphs, T0=T0, T1=T1, PX=PX, PXI=bytes(PXI), npairs=len(plist), used=used, grid=grid)


def band_glyphs(i, L, pal, mono=False):
    """the distant skyline: one character row (16 lines), 256 px pattern,
    two glyph sets (0 / 4 pixel shift) of 32 cells"""
    rows = VT.farband(L.theme, seed=['hull', 'flesh', 'rock', 'cryst', 'ship'].index(L.theme) + 3)
    lvmap = {' ': 0, 'a': 3, 'b': 2, 'c': 1}
    small = np.array([[lvmap.get(ch, 0) for ch in r.ljust(64)[:64]] for r in rows], np.uint8)
    big = np.repeat(np.repeat(small, 2, axis=0), 4, axis=1)   # 16 x 256
    bp = dict(pal)
    bp['light'] = pal['band']
    bp['rim'] = pal['band']
    out = []
    for s in range(2):
        sh = np.roll(big, -4 * s, axis=1)
        for c in range(32):
            lv = sh[:, c * 8:c * 8 + 8]
            g, col = A.quantise(lv, np.zeros_like(lv), bp)
            out.append((g + A.quantise_mono(lv, np.zeros_like(lv)), (A.BLACK << 4) | pal['band']))
    return out


BOSS_PAL = {   # per boss: dark (interior paper), light (ink), rim
    0: dict(dark=A.BLUE, light=A.GREY, rim=A.WHITE, acc=[A.BRED, A.YELLOW, A.BCYAN]),
    1: dict(dark=A.RED, light=A.BMAGENTA, rim=A.YELLOW, acc=[A.YELLOW, A.BGREEN, A.WHITE]),
    3: dict(dark=A.BLUE, light=A.BCYAN, rim=A.WHITE, acc=[A.BMAGENTA, A.WHITE, A.YELLOW]),
    4: dict(dark=A.DGREY, light=A.GREY, rim=A.WHITE, acc=[A.YELLOW, A.BRED, A.BCYAN]),
    5: dict(dark=A.RED, light=A.BRED, rim=A.YELLOW, acc=[A.YELLOW, A.WHITE, A.BGREEN]),
    6: dict(dark=A.GREEN, light=A.BGREEN, rim=A.WHITE, acc=[A.YELLOW, A.BCYAN, A.WHITE]),
    7: dict(dark=A.MAGENTA, light=A.BMAGENTA, rim=A.WHITE, acc=[A.BCYAN, A.YELLOW, A.WHITE]),
}


def boss_glyphs(i):
    """the stage's huge boss body as cells of glyphs at its resting y offset"""
    import bossart as BA
    if i not in BA.BYLEVEL:
        return None
    b = BA.BOSSES[BA.BYLEVEL[i]]
    wb = (b['w'] + 3) // 4
    H = b['h']
    rows = [r.ljust(wb * 4, '.') for r in b['rows']]
    small = np.array([[0 if ch == '.' else int(ch) for ch in r] for r in rows], np.uint8)
    # VZ logical 1 = lit, 2 = hot, 3 = body -> levels light/mid/dark
    lvmap = np.array([0, 3, 2, 1], np.uint8)
    big = SPR.epx(SPR.epx(lvmap[small]))
    c = (56 - H) // 2                    # resting y (VZ px) inside the playfield
    yo = (c & 3) * 4
    row0 = c >> 2
    nrow = (yo + 4 * H + 15) // 16
    ncol = (4 * wb * 4) // 8
    canvas = np.zeros((nrow * 16, ncol * 8), np.uint8)
    canvas[yo:yo + 4 * H, :] = big[:, :ncol * 8]
    pal = BOSS_PAL[i]
    get, order = glyph_alloc()
    get(bytes(32))
    cells = []
    for r in range(nrow):
        for cc in range(ncol):
            lv = canvas[r * 16:r * 16 + 16, cc * 8:cc * 8 + 8]
            if not (lv > 0).any():
                cells.append((0x80, 0, 0, 0))      # transparent
                continue
            g, col = A.quantise(lv, np.zeros_like(lv), pal)
            gid = get(g + A.quantise_mono(lv, np.zeros_like(lv))) - 1
            cells.append((0x80 | (gid & 127), 7 + (gid >> 7), col, 1))
    assert len(order) - 1 <= 384, 'boss glyphs %d' % (len(order) - 1)
    return dict(glyphs=order[1:], cells=cells, nrow=nrow, ncol=ncol, row0=row0, yo=yo, name=b['name'])


def stage_data(i, L, pal):
    return stage_terrain(i, L, pal), band_glyphs(i, L, pal)


def w16(v):
    return struct.pack('<H', v & 0xFFFF)


def derock(L):
    """Microbee: take out the clusters of three round 2 x 2 'rocks' that
    float in the flight path (BPM: too obstructive in stage 1)"""
    sq = [b for b in L.blocks if b[2:] == (2, 2)]
    gone = set()
    for b in sq:
        n1 = [c for c in sq if c[0] == b[0] + 4]
        n2 = [c for c in sq if c[0] == b[0] + 8]
        if n1 and n2:
            gone |= {b, n1[0], n2[0]}
    # and the single two-wide blocks, which draw as round lumps
    gone |= {b for b in L.blocks if b[2] == 2}
    L.blocks = [b for b in L.blocks if b not in gone]
    L.grid = LV.build_grid(L, L.theme)
    objs = [(bx, by, bw, bh, 0) for (bx, by, bw, bh) in L.blocks]
    objs += [(fx, fy, 1, 1, 1) for (fx, fy, t) in L.feat if t == VT.F0]
    objs += list(L.xobjs)
    objs.sort()
    L.objs = objs
    return len(gone)


_vz_prep_levels = VG.prep_levels


def mb_levels():
    """VZ-TYPE's levels with the Microbee's changes (used for everything,
    including the packed level data the game decodes)"""
    Ls = _vz_prep_levels()
    mb_levels.gone = derock(Ls[0])
    return Ls


VG.prep_levels = mb_levels


def main():
    Ls = VG.prep_levels()
    print('stage 1: %d round blocks taken out' % mb_levels.gone)
    names = list(VA.SPR.keys())
    # ---------------- shared game tables
    out = []
    emit = out.append
    for k, n in enumerate(names):
        emit('SP_%s equ %d' % (n.upper(), k))
    emit('NSPR equ %d' % len(names))
    emit('spr_px:')
    for n in names:
        rows = VA.SPR[n]
        emit('\tdb %d,%d' % (max(len(r) for r in rows), len(rows)))
    emit('\talign 256')
    emit('rndt:')
    for k in range(0, 256, 16):
        emit('\tdb ' + ','.join('$%02x' % v for v in VG.RNDT[k:k + 16]))
    sint = [int(round(127 * math.sin(2 * math.pi * k / 256))) & 255 for k in range(256)]
    emit('sint:')
    for k in range(0, 256, 16):
        emit('\tdb ' + ','.join('$%02x' % v for v in sint[k:k + 16]))
    d = []
    for k in range(16):
        a = 2 * math.pi * k / 16
        d += [int(round(24 * math.cos(a))) & 255, int(round(24 * math.sin(a))) & 255]
    emit('dirtab:\n\tdb ' + ','.join('$%02x' % v for v in d))
    # ---------------- enemy bullets over open space: ready-made glyphs in
    # the font bank (glyphs 96..125, screen codes 224..253), one per piece of each position.
    # bultab: [frame][x offset 0/4][y offset 0/4/8/12] -> 4 cells (row-major
    # 2 x 2): code (0 = none), ink
    import mbfont, mbsprart
    fontb = bytearray(mbfont.font_bank())
    code = 96
    tab = []
    for f in range(2):
        c = mbsprart.ebul(f)
        bits, col = c.bits(), c.col
        for xo in range(2):
            for yo in range(4):
                B = np.zeros((32, 16), bool)
                C = np.zeros((32, 16), np.uint8)
                B[4 * yo:4 * yo + 8, 4 * xo:4 * xo + 8] = bits
                C[4 * yo:4 * yo + 8, 4 * xo:4 * xo + 8] = np.where(bits, col, 0)
                ent = []
                for r in range(2):
                    for cc in range(2):
                        pb = B[16 * r:16 * r + 16, 8 * cc:8 * cc + 8]
                        if not pb.any():
                            ent += [0, 0]
                            continue
                        pc = C[16 * r:16 * r + 16, 8 * cc:8 * cc + 8]
                        vals, cnt = np.unique(pc[pc > 0], return_counts=True)
                        fontb[code * 16:code * 16 + 16] = mbfont.pack(pb.astype(np.uint8))
                        ent += [0x80 | code, int(vals[np.argmax(cnt)])]   # PCG: code + 128
                        code += 1
                tab.append(ent)
    assert code <= 128, code
    emit('bultab:')
    for e in tab:
        emit('\tdb ' + ','.join('%d' % v for v in e))
    (BUILD / 'vzdata.inc').write_text('\n'.join(out) + '\n')

    # ---------------- per stage
    (BUILD / 'GFX.BNK').write_bytes(bytes(fontb) + bytes(2048))
    sprlib = SPR.build_all()
    for i, L in enumerate(Ls):
        pal = A.STAGE_PAL[i]
        ter, band = stage_data(i, L, pal)
        write_stage(dict(i=i, L=L, pal=pal, ter=ter, band=band), sprlib, names)
        print('stage %d: terrain glyphs %d, pair entries %d' % (i, len(ter['glyphs']), ter['npairs']))


def level_blobs():
    """the VZ-TYPE stage blobs, packed exactly as the original build does"""
    import os
    tmp = BUILD / 'vzgen'
    tmp.mkdir(exist_ok=True)
    cwd = os.getcwd()
    os.chdir(tmp)
    VG.out.clear()
    import contextlib, io
    with contextlib.redirect_stdout(io.StringIO()):
        VG.gen()
    os.chdir(cwd)
    blobs = {}
    cur = None
    for line in VG.out:
        if line.startswith('lvlpak'):
            cur = int(line[6:line.index(':')])
            blobs[cur] = bytearray()
            continue
        if cur is not None:
            if line.startswith('\tdb '):
                blobs[cur] += bytes(int(v[1:], 16) for v in line[4:].split(','))
            else:
                cur = None
    return blobs


BLOBS = None


def write_stage(st, sprlib, names):
    global BLOBS
    if BLOBS is None:
        BLOBS = level_blobs()
    i = st['i']
    L = st['L']
    ter = st['ter']
    # ---------------- PCG block (block 8+2n): 0000 terrain (banks 2-5),
    # 2000 band (bank 6), 2800 boss (banks 7-9); 4000-7FFF the same glyphs
    # drawn for a monochrome monitor
    pcg = bytearray(0x8000)

    def g2(off, k, g):
        pcg[off + k * 16:off + k * 16 + 16] = g[:16]
        pcg[0x4000 + off + k * 16:0x4000 + off + k * 16 + 16] = g[16:]
    for k, g in enumerate(ter['glyphs']):
        g2(0, k, g)
    for k, (g, c) in enumerate(st['band']):
        g2(0x2000, k, g)
    boss = boss_glyphs(i)
    if boss:
        for k, g in enumerate(boss['glyphs']):
            g2(0x2800, k, g)
    blob = BLOBS[i]
    assert lzb.unpack(bytes(blob)) is not None
    (BUILD / ('STAGE%d.PCG' % i)).write_bytes(bytes(pcg))
    # ---------------- table block (block 9+2n)
    tab = bytearray(0x8000)

    def put(off, data):
        tab[off:off + len(data)] = data
    T0, T1, PX = ter['T0'], ter['T1'], ter['PX']
    put(0x0000, bytes(e[0] for e in T0))
    put(0x0080, bytes(e[1] for e in T0))
    put(0x0100, bytes(e[2] for e in T0))
    put(0x0200, bytes(e[0] for e in T1))
    put(0x0240, bytes(e[1] for e in T1))
    put(0x0280, bytes(e[2] for e in T1))
    put(0x0300, bytes(e[0] for e in PX))
    put(0x0400, bytes(e[1] for e in PX))
    put(0x0500, bytes(e[2] for e in PX))
    put(0x0600, bytes(c for (g, c) in st['band']))
    bandy = getattr(L, 'bandy', 30)
    brow = max(1, min(13, int(round((bandy + 4) / 4))))
    put(0x0680, bytes([brow, (A.BLACK << 4) | st['pal']['band'], st['pal']['star']]))
    put(0x1000, ter['PXI'])
    if boss:
        n = boss['nrow'] * boss['ncol']
        cells = boss['cells']
        put(0x0700, bytes([boss['ncol'], boss['nrow'], boss['row0'], n & 255, n >> 8]))
        put(0x0710, bytes(c[0] for c in cells))
        put(0x0710 + 0x180, bytes(c[1] for c in cells))
        put(0x0710 + 0x300, bytes(c[2] for c in cells))
        assert n <= 0x180
        print('  boss', boss['name'], '%dx%d cells' % (boss['ncol'], boss['nrow']), 'glyphs', len(boss['glyphs']))
    used = VG.sprmask(i, L, names)[1] + [n for n in names if n.startswith('exh')]   # (the ship's engine flame)
    sp = SPR.pack_set(sprlib, names, used, 0x0000, 0x5800)
    put(0x2000, sp['blob'])
    assert 0x2000 + len(sp['blob']) <= 0x7800
    assert len(blob) <= 0x800
    put(0x7800, bytes(blob))           # packed level blob
    (BUILD / ('STAGE%d.TAB' % i)).write_bytes(bytes(tab))
    print('stage', i, 'sprite set bytes', len(sp['blob']), 'sprites', sp['n'], 'level blob', len(blob))


if __name__ == '__main__':
    main()
