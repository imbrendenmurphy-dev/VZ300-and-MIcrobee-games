"""ROBOT RIOT 2086: build everything into build/ (VIBED BY BPM 2026).

  python3 tools/build.py

1. icons, shots, font -> PCG bank 0; the border glyphs in every bank
2. sprite frames (16 glyphs each: 4 grid offsets x 4 cells) -> banks 1-7
3. the gallery's double-size frames and the title logo -> banks 8 up
   (all of it in GFX.BNK) and src/gen.inc
4. music -> src/music.inc
5. the program (src/main.asm), the loader (src/loader.asm), the disk
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

NBANKS = 16
CH = 10                    # lines in a character cell (the 8 x 10 MODES mode)
FRAMES_PER_BANK = 7        # glyphs 16..127; glyph 0 of every bank stays blank
PIC_BASE = 2048 * CH       # the glyphs are stored CH bytes each


class Store:
    """the 2048 PCG glyphs (8 rows each). In every bank glyph 0 is blank and
    glyphs 1-8 are the arena border, so an erased cell needs no bank."""

    def __init__(self):
        self.g = [bytes(CH)] * (NBANKS * 128)
        self.used = [False] * (NBANKS * 128)
        self.key = {}
        for b in range(NBANKS):
            self.used[b * 128] = True
            for i, pat in enumerate(BORDER10):
                self.g[b * 128 + 1 + i] = pat
                self.used[b * 128 + 1 + i] = True
        self.key[bytes(CH)] = 0

    def put(self, n, pat, share=True):
        assert not self.used[n] or self.g[n] == pat, n
        self.g[n] = bytes(pat)
        self.used[n] = True
        if share:
            self.key.setdefault(bytes(pat), n)

    def alloc(self, pat, first_bank):
        pat = bytes(pat)
        if pat in self.key and self.key[pat] >= first_bank * 128:
            return self.key[pat]
        for n in range(first_bank * 128, NBANKS * 128):
            if not self.used[n]:
                self.put(n, pat)
                return n
        raise SystemExit('out of glyphs')

    def data(self):
        return b''.join(self.g)


def frame_glyphs(a):
    """12 x 16 bool -> 16 glyphs: (oy*2 + ox)*4 + cell (TL, TR, BL, BR)"""
    out = []
    for oy in range(2):
        for ox in range(2):
            c = np.zeros((2 * CH, 16), bool)
            w = 16 - 4 * ox
            c[5 * oy:5 * oy + 12, 4 * ox:4 * ox + w] = a[:, :w]
            for cy in range(2):
                for cx in range(2):
                    out.append(cell_bytes(c, cx, cy))
    return out


def cell_bytes(bits, cx, cy):
    out = bytearray(CH)
    for y in range(CH):
        v = 0
        for x in range(8):
            if bits[cy * CH + y, cx * 8 + x]:
                v |= 128 >> x
        out[y] = v
    return bytes(out)


class Pic:
    """a 40 x 25 picture: text and free bitmap areas"""

    def __init__(self, st):
        self.st = st
        self.g = np.zeros((25, 40), int)
        self.col = np.full((25, 40), A.WHITE, int)
        self.bits = np.zeros((25 * CH, 320), bool)
        self.ink = np.full((25, 40), -1, int)

    def text(self, c, r, s, colour):
        for i, ch in enumerate(s):
            self.g[r, c + i] = 64 + ord(ch) - 32
            self.col[r, c + i] = colour

    def ctext(self, r, s, colour):
        self.text((40 - len(s)) // 2, r, s, colour)

    def blit(self, x, y, a, colour):
        h, w = a.shape
        self.bits[y:y + h, x:x + w] |= a
        for r in range(y // CH, (y + h + CH - 1) // CH):
            for c in range(x // 8, (x + w + 7) // 8):
                self.ink[r, c] = colour

    def bake(self, first_bank):
        for r in range(25):
            for c in range(40):
                if self.ink[r, c] < 0:
                    continue
                p = cell_bytes(self.bits, c, r)
                self.g[r, c] = self.st.alloc(p, first_bank) if any(p) else 64
                self.col[r, c] = self.ink[r, c]
        lo = bytes(0x80 | (int(v) & 127) for v in self.g.flat)
        hi = bytes(int(v) >> 7 for v in self.g.flat)
        col = bytes(int(v) for v in self.col.flat)
        return lo + hi + col


def big_text(text, sx, sy, stripes=True):
    rows = []
    for r in range(7):
        line = []
        for ch in text:
            for b in A.FD[ch].split()[r]:
                line += [b == '1'] * sx
            line += [False] * sx
        rows += [line] * sy
    a = np.array(rows, bool)[:, :-sx]
    if stripes:
        a[sy - 1::sy, :] = False                # scan-line stripes
    return a


def to10(b):
    """an 8-line glyph centred in a 10-line cell"""
    b = bytes(b)
    return b if len(b) == CH else bytes(1) + b + bytes(CH - 9)


def quad10(pat4):
    """a 4 x 4 pattern in each quarter (4 x 5) of a cell -> 4 glyphs"""
    out = []
    rows = pat4.split()
    for qy in range(2):
        for qx in range(2):
            b = bytearray(CH)
            for y, r in enumerate(rows):
                for x, c in enumerate(r):
                    if c == '#':
                        b[qy * 5 + y] |= 128 >> (qx * 4 + x)
            out.append(bytes(b))
    return out


BORDER10 = [bytes([0xFF] + [0] * 9), bytes([0] * 9 + [0xFF]), bytes([0x80] * 10), bytes([0x01] * 10),
            bytes([0xFF] + [0x80] * 9), bytes([0xFF] + [0x01] * 9), bytes([0x80] * 9 + [0xFF]), bytes([0x01] * 9 + [0xFF])]


def icons10():
    ic = {k: to10(v) for k, v in A.ICONS.items()}
    ic['dith1'] = bytes([0xAA, 0x55] * 5)
    ic['dith2'] = bytes([0x55, 0xAA] * 5)
    ic['block'] = bytes([0xFF] * 10)
    return ic


def build_gfx():
    st = Store()
    equ = {}
    # ---- bank 0: icons and shots at 9-63, the font at 64-127 (char = ASCII + A0h)
    n = 9
    for name, pat in icons10().items():
        st.put(n, pat)
        equ['G_' + name.upper()] = 0x80 | n
        n += 1
    for name, pats in (('SHOT', quad10(".... #### #### ....") + quad10(".##. .##. .##. .##.") + quad10("##.. ###. .### ..##") + quad10("..## .### ###. ##..")),
                       ('SPARK', quad10("#..# .##. .##. #..#") + quad10(".##. #..# #..# .##."))):
        equ['G_' + name] = 0x80 | n
        for pat in pats:
            st.put(n, pat, share=False)
            n += 1
    assert n <= 64, n
    for i, f in enumerate(A.font_glyphs()):
        st.put(64 + i, bytes(1) + f[:7] + bytes(2))
    for i, nm in enumerate(('TOP', 'BOT', 'LEFT', 'RIGHT', 'TL', 'TR', 'BL', 'BR')):
        equ['G_B' + nm] = 0x81 + i
    # ---- banks 1..: sprite frames
    F = A.frames()
    fnum = {}
    ftab = []
    for i, (name, a) in enumerate(F):
        if name:
            fnum[name] = i
        bank = 1 + i // FRAMES_PER_BANK
        base = 16 + (i % FRAMES_PER_BANK) * 16
        for k, pat in enumerate(frame_glyphs(a)):
            st.put(bank * 128 + base + k, pat, share=False)
        ftab.append((0x80 | base, bank))
    first_free = 1 + (len(F) + FRAMES_PER_BANK - 1) // FRAMES_PER_BANK
    print('sprites: %d frames in banks 1..%d' % (len(F), first_free - 1))
    # ---- the gallery's double-size frames: 3 x 3 cells, (char, bank) each
    bigtab = []
    bnum = {}
    for i, (name, a) in enumerate(A.big_frames()):
        if name:
            bnum[name] = i
        bits = np.zeros((3 * CH, 24), bool)
        bits[3:27, :] = np.kron(a[:, :12], np.ones((2, 2), bool))
        cells = []
        for cy in range(3):
            for cx in range(3):
                p = cell_bytes(bits, cx, cy)
                g = st.alloc(p, first_free) if any(p) else first_free * 128
                cells.append((0x80 | (g & 127), g >> 7))
        bigtab.append(cells)
    # ---- the title picture (the logo; balls, colours and sprites are added live)
    import logo
    p = Pic(st)
    main, year = logo.title_logo()
    p.blit((320 - main.shape[1]) // 2, 15, main, A.WHITE)
    p.blit((320 - year.shape[1]) // 2, 66, year, A.WHITE)
    p.ctext(12, 'THE ROBOTS HAVE RISEN', A.BCYAN)
    p.ctext(18, 'MOVE WASD   FIRE IJKL OR ARROWS', A.BGREEN)
    p.ctext(19, 'SPACE FIRES AHEAD  P PAUSE  M SOUND', A.GREY)
    p.ctext(22, 'VIBED BY BPM 2026', A.BMAGENTA)
    title = p.bake(first_free)
    # the logo's cells, each with a reverse-video twin, for the glint that
    # sweeps across it; sorted along the glint (which leans with the letters)
    cells = []
    for r in range(1, 11):
        for c in range(1, 39):
            if p.ink[r, c] < 0:
                continue
            pat = cell_bytes(p.bits, c, r)
            if not any(pat):
                continue
            n = int(p.g[r, c])
            inv = st.alloc(bytes(b ^ 0xFF for b in pat), first_free)
            d = c - (r - 1) // 2 + 5
            cells.append((d, r * 40 + c, n, inv))
    cells.sort()
    L2 = ['logotab:\t\t; address, glint column, char, bank, reverse char, bank']
    for d, off, n, inv in cells:
        L2.append('\tdw $%04X\n\tdb %d,$%02X,%d,$%02X,%d' % (0xF000 + off, d, 0x80 | (n & 127), n >> 7, 0x80 | (inv & 127), inv >> 7))
    L2.append('logostart:\t\t; first logotab entry of each glint column 0-48')
    idx = 0
    starts = []
    for d in range(50):
        while idx < len(cells) and cells[idx][0] < d:
            idx += 1
        starts.append('logotab+%d' % (idx * 7))
    L2.append('\tdw ' + ','.join(starts))
    logo_inc = '\n'.join(L2) + '\n'
    print('logo: %d cells (max glint column %d)' % (len(cells), max(c[0] for c in cells)))
    print('glyphs used: %d of 2048' % sum(st.used))

    blk = bytearray(st.data())
    assert len(blk) == PIC_BASE
    blk += title
    open(os.path.join(BUILD, 'GFX.BNK'), 'wb').write(blk)

    # ---- gen.inc
    L = ['; generated by tools/build.py']
    for k, v in equ.items():
        L.append('%s equ $%02X' % (k, v))
    for k, v in fnum.items():
        L.append('F_%s equ %d' % (k, v))
    for k, v in bnum.items():
        L.append('BF_%s equ %d' % (k, v))
    L.append('PIC_TITLE equ $%04X' % PIC_BASE)
    open(os.path.join(SRC, 'gen.inc'), 'w').write('\n'.join(L) + '\n')
    # ---- tables (page aligned): frames; cell offset of each arena row
    L = ['; generated by tools/build.py', '\tALIGN 256', 'frametab:\t\t; char of the first glyph, bank']
    for ch, bank in ftab:
        L.append('\tdb $%02X,%d' % (ch, bank))
    off = [(1 + y // 2) * 40 for y in range(48)]
    L += ['\tALIGN 256', 'ytlo:\t\t\t; arena row y (4-pixel units) -> screen offset of column 0',
          '\tdb ' + ','.join(str(o & 255) for o in off), '\tds 256-48', 'ythi:',
          '\tdb ' + ','.join(str(o >> 8) for o in off)]
    # the arena border (rows 1-24), clockwise from the top left, and its glyphs
    per = [(1, c) for c in range(40)] + [(r, 39) for r in range(2, 24)] + \
          [(24, c) for c in range(39, -1, -1)] + [(r, 0) for r in range(23, 1, -1)]
    assert len(per) == 124

    def bch(r, c):
        if r == 1:
            return 0x85 if c == 0 else 0x86 if c == 39 else 0x81
        if r == 24:
            return 0x87 if c == 0 else 0x88 if c == 39 else 0x82
        return 0x83 if c == 0 else 0x84
    L += ['arenaperim:\t\t; 124 screen offsets', '\tdw ' + ','.join(str(r * 40 + c) for r, c in per),
          'arenachars:', '\tdb ' + ','.join('$%02X' % bch(r, c) for r, c in per)]
    # the whole screen's edge (attract screens), clockwise from the top left
    per = [(0, c) for c in range(40)] + [(r, 39) for r in range(1, 24)] + \
          [(24, c) for c in range(39, -1, -1)] + [(r, 0) for r in range(23, 0, -1)]
    assert len(per) == 126
    L += ['edgeperim:\t\t; 126 screen offsets', '\tdw ' + ','.join(str(r * 40 + c) for r, c in per)]
    rb = [A.BRED, A.BROWN, A.YELLOW, A.BGREEN, A.BCYAN, A.BBLUE, A.BMAGENTA, A.WHITE]
    gl = [A.BRED | A.RED << 4, A.YELLOW | A.BROWN << 4, A.BGREEN | A.GREEN << 4, A.BCYAN | A.CYAN << 4,
          A.BBLUE | A.BLUE << 4, A.BMAGENTA | A.MAGENTA << 4, A.WHITE | A.GREY << 4, A.YELLOW | A.RED << 4]
    L += ['\tALIGN 256', 'rainbow:\t\t; 256 colours, 8 bright colours two cells each',
          '\tdb ' + ','.join(str(rb[(i // 2) % 8]) for i in range(256)),
          'glowtab:\t\t; 256 ink + paper pairs for the glowing dither',
          '\tdb ' + ','.join('$%02X' % gl[(i // 2) % 8] for i in range(256))]
    L.append(logo_inc)
    L += ['bigtab:\t\t\t; gallery frames: 9 cells of (char, bank)']
    for cells in bigtab:
        L.append('\tdb ' + ','.join('$%02X,%d' % c for c in cells))
    open(os.path.join(SRC, 'tables.inc'), 'w').write('\n'.join(L) + '\n')
    return st, F


def sheet(st, F):
    """a contact sheet of the frames, for checking the art"""
    from PIL import Image
    k = 5
    cols = 16
    rows = (len(F) + cols - 1) // cols
    img = np.zeros((rows * 16 * k, cols * 16 * k), np.uint8)
    for i, (n, a) in enumerate(F):
        y, x = divmod(i, cols)
        img[y * 16 * k:y * 16 * k + 12 * k, x * 16 * k:(x + 1) * 16 * k] = np.kron(a, np.ones((k, k), np.uint8)) * 255
    Image.fromarray(img).save(os.path.join(BUILD, 'sheet.png'))


# ---------------------------------------------------------------- program, loader, disk
LOADFILES = [('STG_PROG', 0x00, 'RR', 'BIN'), (7, 0x00, 'GFX', 'BNK')]


def assemble():
    zasm = os.path.join(HERE, 'zasm.py')
    subprocess.check_call([sys.executable, zasm, 'main.asm', '--sym=../build/main.sym'], cwd=SRC)
    lines = ['\tDB %s, $%02X, "%-8s%s"' % (b, o, n, e) for b, o, n, e in LOADFILES]
    open(os.path.join(SRC, 'loadfiles.inc'), 'w').write('\n'.join(lines) + '\n')
    subprocess.check_call([sys.executable, zasm, 'loader.asm', '--sym=../build/loader.sym'], cwd=SRC)


def disk():
    import build_disk as BD
    from pathlib import Path
    B = Path(BUILD)
    sysdisk = (Path(ROOT) / 'resources' / 'boot_tracks.bin').read_bytes()
    files = {'RIOT.COM': (B / 'RIOT.COM').read_bytes()}
    for b_, o, n, e in LOADFILES:
        files['%s.%s' % (n, e)] = (B / ('%s.%s' % (n, e))).read_bytes()
    files['CCP.SYS'] = (Path(ROOT) / 'resources' / 'CCP.SYS').read_bytes()
    readme = Path(ROOT) / 'docs' / 'DISK_README.TXT'
    files['README.TXT'] = readme.read_text().replace('\r\n', '\n').replace('\n', '\r\n').encode('ascii') + b'\x1a'
    used = BD.build_disk(sysdisk, files, B / 'RIOT.DS8')
    print('RIOT.DS8: %d of 196 blocks used (%dK free), %d files' % (used, (196 - used) * 4, len(files)))


if __name__ == '__main__':
    st, F = build_gfx()
    sheet(st, F)
    import music
    music.build(os.path.join(SRC, 'music.inc'))
    if '--noasm' not in sys.argv:
        assemble()
        disk()
