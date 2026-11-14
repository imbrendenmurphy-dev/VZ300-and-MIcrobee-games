"""GHOST HUNTER '26: build everything into build/ (VIBED BY BPM 2026).

  python3 tools/build.py            everything, down to GHOST26.DS8
  python3 tools/build.py --preview  also build/preview_maze*.png

1. dots, walls, items, font and HUD icons -> PCG glyphs (colour and mono
   sets), GFX.BNK, src/tiles.inc, src/tiledata.inc
2. the six mazes -> MAZE.BNK (picture, dot map, lane table, way-home table)
3. sprite frames (pre-shifted, masked) -> SPR0.BNK, SPR1.BNK, src/sprtab.inc
4. the title picture -> in GFX.BNK
5. music -> src/music.inc
6. the program (src/main.asm), the loader (src/loader.asm), the disk
"""
import os
import sys
import subprocess
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BUILD = os.path.join(ROOT, 'build')
SRC = os.path.join(ROOT, 'src')
sys.path.insert(0, HERE)
os.makedirs(BUILD, exist_ok=True)

import art as A
import mazes as MZ

STORE_N = 512          # glyphs 0..511 (banks 0-3) are kept in every sprite block
G_DOT = 1              # 16 dot glyphs, then 4 x 16 with an energiser quarter
G_FONT = 384           # font: chars 32..90 (bank 3)
G_ICON = 448           # HUD icons
G_TITLE = 512          # title picture glyphs: banks 4..13
SPR_DATA = 0x3000
GFX_STORE_C = 0x0000   # GFX block: colour store (512 x 16)
GFX_STORE_M = 0x2000   #            mono store
GFX_TITLE = 0x4000     #            title: 1000 lo, 1000 hi, 1000 colour, then dw n, n x 16 colour, n x 16 mono
MAZE_REC = 0x1400      # MAZE block: one record a maze
MZ_LO, MZ_HI, MZ_COL, MZ_DMAP, MZ_EDGES, MZ_HOME, MZ_INFO = 0, 880, 1760, 2640, 4112, 4203, 4294


def wfile(name, data):
    open(os.path.join(BUILD, name), 'wb').write(bytes(data))


CH = A.CH              # lines in a cell


def cell_bytes(bits, cx, cy):
    out = bytearray(CH)
    for y in range(CH):
        v = 0
        for x in range(8):
            if bits[cy * CH + y, cx * 8 + x]:
                v |= 128 >> x
        out[y] = v
    return bytes(out)


def mono_of(pat, ink, paper):
    """the mono monitor shows only the pixel bits: where the paper is the
    brighter colour, the pattern is inverted so the picture reads the same"""
    if A.LUM[paper] > A.LUM[ink]:
        return bytes(255 - b for b in pat)
    return pat


class Glyphs:
    def __init__(self, first, limit):
        self.first, self.limit = first, limit
        self.key = {}
        self.pats = []

    def add(self, pat, mono, unique=False):
        k = (pat, mono)
        if unique or k not in self.key:
            assert len(self.pats) < self.limit - self.first, 'out of glyphs'
            self.key.setdefault(k, self.first + len(self.pats))
            self.pats.append(k)
            if unique:
                return self.first + len(self.pats) - 1
        return self.key[k]


# ---------------------------------------------------------------- the glyph store and the mazes
def dot_index(d, c, r):
    """glyph offset (from G_DOT) of corridor cell (c, r) for the dot lattice d"""
    vals = [d.get((c, r), 0), d.get((c + 1, r), 0), d.get((c, r + 1), 0), d.get((c + 1, r + 1), 0)]
    mask = sum(1 << k for k in range(4) if vals[k])
    if 2 in vals:
        return 16 + vals.index(2) * 16 + mask
    return mask


def build_store():
    gs = Glyphs(0, G_FONT)
    gs.add(bytes(CH), bytes(CH))               # glyph 0: blank
    for m in range(16):
        p = A.dot_glyph(m, None)
        gs.add(p, p, unique=True)
    for corner in range(4):
        for m in range(16):
            p = A.dot_glyph(m, corner)
            gs.add(p, p, unique=True)
    assert len(gs.pats) == G_DOT + 80
    g_door = gs.add(A.DOOR, A.DOOR)
    # the mazes
    mz = MZ.all_mazes()
    blk = bytearray()
    pics = []
    for m in mz:
        o = m.open_cells()
        d = m.dots()
        ink, paper = A.STYLE_COL[m.style]
        lo, hi, col = bytearray(880), bytearray(880), bytearray(880)
        for r in range(22):
            for c in range(40):
                if o[r][c]:
                    g = G_DOT + dot_index(d, c, r)
                    cl = m.dotcol
                elif r == 9 and c in (19, 20):
                    g = g_door
                    cl = A.DOOR_COL[0] | (A.DOOR_COL[1] << 4)
                else:
                    def w(cc, rr):
                        return 0 <= cc < 40 and 0 <= rr < 22 and not o[rr][cc]
                    mask = (A.MU if w(c, r - 1) else 0) | (A.MD if w(c, r + 1) else 0) | \
                           (A.ML if w(c - 1, r) else 0) | (A.MR if w(c + 1, r) else 0)
                    if r == 8 and c in (19, 20):
                        mask &= ~A.MD
                    p = A.pat8(A.wall_bits(m.style, mask, c, r))
                    g = gs.add(p, mono_of(p, ink, paper))
                    cl = ink | (paper << 4)
                lo[r * 40 + c] = 0x80 | (g & 127)
                hi[r * 40 + c] = g >> 7
                col[r * 40 + c] = cl
        dm = bytearray(23 * 64)
        for (lx, ly), v in d.items():
            dm[ly * 64 + lx] = v
        rec = bytes(lo) + bytes(hi) + bytes(col) + bytes(dm) + m.edge_table() + m.home_table()
        assert len(rec) == MZ_INFO
        rec += len(d).to_bytes(2, 'little') + bytes([m.dotcol, A.WALL_FLASH[m.style]])
        rec += m.name.encode('ascii') + b'\0'
        assert len(rec) <= MAZE_REC
        blk += rec + bytes(MAZE_REC - len(rec))
        pics.append((lo, hi, col))
        print('maze %-16s %d dots' % (m.name, len(d)))
    wfile('MAZE.BNK', blk)
    nwall = len(gs.pats)
    # items: 2 x 2 cells each
    item_recs = []
    for name, c_top, c_bot, rows in A.ITEMS:
        bits = np.vstack([np.zeros((2, 16), bool), A.art(rows), np.zeros((2, 16), bool)])   # 16 x 20
        cells = []
        for q, (cx, cy) in enumerate(((0, 0), (1, 0), (0, 1), (1, 1))):
            p = cell_bytes(bits, cx, cy)
            g = gs.add(p, p)
            cells.append((g, c_top if cy == 0 else c_bot))
        item_recs.append((name, cells))
    print('store: %d glyphs (%d by the mazes), limit %d' % (len(gs.pats), nwall, G_FONT))
    store_c = bytearray(STORE_N * 16)
    store_m = bytearray(STORE_N * 16)
    for i, (pc, pm) in enumerate(gs.pats):
        store_c[i * 16:i * 16 + CH] = pc
        store_m[i * 16:i * 16 + CH] = pm
    for i, f in enumerate(A.font_glyphs()):
        g = G_FONT + i
        f = bytes([f[0], f[1], f[1], f[2], f[3], f[4], f[5], f[5], f[6], 0])   # 5 x 7 drawn 9 lines tall
        store_c[g * 16:g * 16 + CH] = f
        store_m[g * 16:g * 16 + CH] = f
    for i, (n, f) in enumerate(A.ICONS):
        g = G_ICON + i
        store_c[g * 16:g * 16 + CH] = f
        store_m[g * 16:g * 16 + CH] = f
    L = ['; generated by tools/build.py',
         'G_DOT equ %d' % G_DOT, 'G_DOOR equ %d' % g_door, 'G_FONT equ %d' % G_FONT, 'G_ICON equ %d' % G_ICON,
         'STORE_N equ %d' % STORE_N, 'FLOOR_END equ 1', 'NMAZES equ %d' % len(mz),
         'MAZE_REC equ $%04X' % MAZE_REC, 'MZ_LO equ %d' % MZ_LO, 'MZ_HI equ %d' % MZ_HI, 'MZ_COL equ %d' % MZ_COL,
         'MZ_DMAP equ %d' % MZ_DMAP, 'MZ_EDGES equ %d' % MZ_EDGES, 'MZ_HOME equ %d' % MZ_HOME, 'MZ_INFO equ %d' % MZ_INFO,
         'NPOWER equ %d' % A.NPOWER, 'NITEMS equ %d' % len(A.ITEMS)]
    for i, (n, f) in enumerate(A.ICONS):
        L.append('IC_%s equ %d' % (n.upper(), G_ICON + i))
    for i, (n, c) in enumerate(item_recs):
        L.append('IT_%s equ %d' % (n, i + 1))
    open(os.path.join(SRC, 'tiles.inc'), 'w').write('\n'.join(L) + '\n')
    L = ['; generated by tools/build.py: item tiles, 12 bytes each (4 glyphs, 4 colours)', 'item_tab:']
    for n, c in item_recs:
        L.append('\tdw %s' % ','.join(str(g) for g, _ in c))
        L.append('\tdb %s' % ','.join('$%02X' % col for _, col in c))
    L.append('nodetab:')
    nt = [(k // 12 - 1) if (12 <= k <= 156 and k % 12 == 0) else 255 for k in range(169)]
    L.append('\tdb ' + ','.join(str(v) for v in nt))
    L.append('neartab:')
    L.append('\tdb ' + ','.join(str(min(12, max(0, (k - 6) // 12))) for k in range(169)))
    open(os.path.join(SRC, 'tiledata.inc'), 'w').write('\n'.join(L) + '\n')
    return store_c, store_m, pics, mz


# ---------------------------------------------------------------- sprites
def sprite_frame(bits, mask, ax=0, ay=0):
    """-> header: db w, h, ax, ay; dw offsets of the 4 shifts (0,2,4,6 px);
    then per shift, per byte column: db first row, db rows, rows x (and, or)"""
    bits = np.asarray(bits, bool)
    mask = np.asarray(mask, bool) | bits
    h, W = bits.shape
    w = (W + 6 + 7) // 8
    blocks = []
    for s in range(4):
        B = np.zeros((h, w * 8), bool)
        M = np.zeros((h, w * 8), bool)
        B[:, 2 * s:2 * s + W] = bits
        M[:, 2 * s:2 * s + W] = mask
        out = bytearray()
        for c in range(w):
            colm = M[:, c * 8:(c + 1) * 8].any(1)
            rows = np.nonzero(colm)[0]
            if len(rows) == 0:
                out += bytes([0, 0])
                continue
            y0, y1 = rows.min(), rows.max()
            out += bytes([y0, y1 - y0 + 1])
            for y in range(y0, y1 + 1):
                d = k = 0
                for b in range(8):
                    if B[y, c * 8 + b]:
                        d |= 128 >> b
                    if M[y, c * 8 + b]:
                        k |= 128 >> b
                out.append((~k) & 255)
                out.append(d & k)
        blocks.append(out)
    head = bytearray([w, h, ax & 255, ay & 255])
    off = 12
    for b in blocks:
        head += off.to_bytes(2, 'little')
        off += len(b)
    return bytes(head) + b''.join(blocks)


def build_sprites():
    S = A.sprites()
    data = [bytearray(), bytearray()]
    tab = []
    cur = 0
    L = ['; generated by tools/build.py: sprite frames (blocks 4 and 5)']
    for i, (n, b, m) in enumerate(S):
        fb = sprite_frame(b, m)
        if SPR_DATA + len(data[cur]) + len(fb) > 0x8000:
            cur += 1
        tab.append((SPR_DATA + len(data[cur]), cur))
        data[cur] += fb
        L.append('SF_%s equ %d' % (n, i))
    L.append('NSPRFRAMES equ %d' % len(S))
    L.append('spr_tab:')
    for a, k in tab:
        L.append('\tdw $%04X' % a)
    L.append('spr_blk:')
    for i in range(0, len(tab), 16):
        L.append('\tdb ' + ','.join(str(4 + k) for a, k in tab[i:i + 16]))
    open(os.path.join(SRC, 'sprtab.inc'), 'w').write('\n'.join(L) + '\n')
    wfile('SPR0.BNK', data[0])
    wfile('SPR1.BNK', data[1] or b'\0')
    print('sprites: %d frames, %d + %d bytes' % (len(S), len(data[0]), len(data[1])))
    return S


# ---------------------------------------------------------------- title
def build_title():
    """the title picture: 40 x 25 cells with their own glyphs (G_TITLE on)"""
    bits, ink, paper = A.title_picture()
    lo = bytearray(1000)
    hi = bytearray(1000)
    col = bytearray(1000)
    gs = Glyphs(G_TITLE, G_TITLE + 1280)
    for cy in range(25):
        for cx in range(40):
            p = cell_bytes(bits, cx, cy)
            if not any(p):
                g = 0
            else:
                g = gs.add(p, mono_of(p, ink[cy, cx], paper[cy, cx]))
            lo[cy * 40 + cx] = 0x80 | (g & 127)
            hi[cy * 40 + cx] = g >> 7
            col[cy * 40 + cx] = (int(paper[cy, cx]) << 4) | int(ink[cy, cx])
    n = len(gs.pats)
    out = bytes(lo) + bytes(hi) + bytes(col) + n.to_bytes(2, 'little')
    out += b''.join(pc + bytes(16 - CH) for pc, pm in gs.pats)
    out += b''.join(pm + bytes(16 - CH) for pc, pm in gs.pats)
    print('title: %d glyphs' % n)
    return out


def build_gfx():
    store_c, store_m, pics, mz = build_store()
    title = build_title()
    blk = bytearray(32768)
    blk[GFX_STORE_C:GFX_STORE_C + len(store_c)] = store_c
    blk[GFX_STORE_M:GFX_STORE_M + len(store_m)] = store_m
    assert GFX_TITLE + len(title) <= 32768, len(title)
    blk[GFX_TITLE:GFX_TITLE + len(title)] = title
    end = GFX_TITLE + len(title)
    wfile('GFX.BNK', blk[:end])
    open(os.path.join(SRC, 'gfx.inc'), 'w').write(
        '; generated by tools/build.py\nGFX_STORE_C equ $%04X\nGFX_STORE_M equ $%04X\nGFX_TITLE equ $%04X\nG_TITLE equ %d\n'
        % (GFX_STORE_C, GFX_STORE_M, GFX_TITLE, G_TITLE))
    return store_c, pics, mz


def preview(store_c, pics, mz):
    from PIL import Image
    from mbee import PALETTE
    pal = np.array(PALETTE, np.uint8)
    for k, (lo, hi, col) in enumerate(pics):
        img = np.zeros((22 * CH, 320, 3), np.uint8)
        for r in range(22):
            for c in range(40):
                g = (lo[r * 40 + c] & 127) | (hi[r * 40 + c] << 7)
                cl = col[r * 40 + c]
                for y in range(CH):
                    b = store_c[g * 16 + y]
                    for x in range(8):
                        img[r * CH + y, c * 8 + x] = pal[cl & 15] if b & (128 >> x) else pal[cl >> 4]
        im = Image.fromarray(img).resize((640, 422), Image.NEAREST)
        im.save(os.path.join(BUILD, 'preview_maze%d.png' % k))
    # the sprites and items on one sheet
    S = A.sprites()
    sheet = np.zeros((18 * 6, 18 * 16, 3), np.uint8)
    for i, (n, b, m) in enumerate(S[:96]):
        y0, x0 = (i // 16) * 18, (i % 16) * 18
        h, w = b.shape
        if h <= 16 and w <= 16:
            sheet[y0:y0 + h, x0:x0 + w][b] = (255, 255, 64)
    Image.fromarray(sheet).resize((18 * 16 * 3, int(18 * 6 * 3.6)), Image.NEAREST).save(os.path.join(BUILD, 'preview_sprites.png'))
    it = np.zeros((16, 16 * len(A.ITEMS), 3), np.uint8)
    for i, (n, ct, cb, rows) in enumerate(A.ITEMS):
        b = A.art(rows)
        it[:8, i * 16:(i + 1) * 16][b[:8]] = pal[ct]
        it[8:, i * 16:(i + 1) * 16][b[8:]] = pal[cb]
    Image.fromarray(it).resize((16 * len(A.ITEMS) * 3, 58), Image.NEAREST).save(os.path.join(BUILD, 'preview_items.png'))
    bits, ink, paper = A.title_picture()
    timg = np.zeros((250, 320, 3), np.uint8)
    for cy in range(25):
        for cx in range(40):
            sl = bits[cy * CH:cy * CH + CH, cx * 8:cx * 8 + 8]
            timg[cy * CH:cy * CH + CH, cx * 8:cx * 8 + 8] = np.where(sl[:, :, None], pal[ink[cy, cx]], pal[paper[cy, cx]])
    Image.fromarray(timg).resize((640, 480), Image.NEAREST).save(os.path.join(BUILD, 'preview_title.png'))


# ---------------------------------------------------------------- program, loader, disk
LOADFILES = [('STG_PROG', 0x00, 'GH', 'BIN'), (7, 0x00, 'GFX', 'BNK'), (4, 0x30, 'SPR0', 'BNK'),
             (5, 0x30, 'SPR1', 'BNK'), (8, 0x00, 'MAZE', 'BNK')]


def loadfiles():
    lines = ['\tDB %s, $%02X, "%-8s%s"' % (b, o, n, e) for b, o, n, e in LOADFILES]
    open(os.path.join(SRC, 'loadfiles.inc'), 'w').write('\n'.join(lines) + '\n')
    return LOADFILES


def assemble():
    zasm = os.path.join(HERE, 'zasm.py')
    subprocess.check_call([sys.executable, zasm, 'main.asm', '--sym=../build/main.sym'], cwd=SRC)
    loadfiles()
    subprocess.check_call([sys.executable, zasm, 'loader.asm', '--sym=../build/loader.sym'], cwd=SRC)


def disk():
    import build_disk as BD
    from pathlib import Path
    B = Path(BUILD)
    sysdisk = (Path(ROOT) / 'resources' / 'boot_tracks.bin').read_bytes()
    files = {}
    files['GHOST26.COM'] = (B / 'GHOST26.COM').read_bytes()
    for b_, o, n, e in LOADFILES:
        files['%s.%s' % (n, e)] = (B / ('%s.%s' % (n, e))).read_bytes()
    files['CCP.SYS'] = (Path(ROOT) / 'resources' / 'CCP.SYS').read_bytes()
    readme = Path(ROOT) / 'docs' / 'DISK_README.TXT'
    if readme.exists():
        files['README.TXT'] = readme.read_text().replace('\r\n', '\n').replace('\n', '\r\n').encode('ascii') + b'\x1a'
    used = BD.build_disk(sysdisk, files, B / 'GHOST26.DS8')
    print('GHOST26.DS8: %d of 196 blocks used (%dK free), %d files' % (used, (196 - used) * 4, len(files)))


if __name__ == '__main__':
    store_c, pics, mz = build_gfx()
    build_sprites()
    if '--preview' in sys.argv:
        preview(store_c, pics, mz)
    import music
    music.build(os.path.join(SRC, 'music.inc'))
    if '--noasm' not in sys.argv:
        assemble()
        disk()
