"""ROGUE MUSTER: build everything into build/ (VIBED BY BPM 2026).

  python3 tools/build.py

1. font, HUD icons, fence, shots -> PCG bank 0
2. sprite frames (16 glyphs each: 4 grid offsets x 4 cells) -> banks 1-5
3. the title and "rogue mob" pictures -> banks 6 up, picture maps
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
FRAMES_PER_BANK = 7        # glyphs 16..127; glyph 0 of every bank stays blank
PIC_BASE = 0x4000
PIC_LEN = 3000


class Store:
    """the 2048 PCG glyphs (8 rows each)"""

    def __init__(self):
        self.g = [bytes(8)] * (NBANKS * 128)
        self.used = [False] * (NBANKS * 128)
        self.key = {}
        for b in range(NBANKS):
            self.used[b * 128] = True          # blank in every bank
        self.key[bytes(8)] = 0

    def put(self, n, pat, share=True):
        assert not self.used[n] or self.g[n] == pat, n
        self.g[n] = bytes(pat)
        self.used[n] = True
        if share:
            self.key.setdefault(bytes(pat), n)

    def alloc(self, pat, first_bank):
        pat = bytes(pat)
        if pat in self.key:
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
            c = np.zeros((16, 16), bool)
            w = 16 - 4 * ox
            c[4 * oy:4 * oy + 12, 4 * ox:4 * ox + w] = a[:, :w]
            for cy in range(2):
                for cx in range(2):
                    out.append(cell_bytes(c, cx, cy))
    return out


def cell_bytes(bits, cx, cy):
    out = bytearray(8)
    for y in range(8):
        v = 0
        for x in range(8):
            if bits[cy * 8 + y, cx * 8 + x]:
                v |= 128 >> x
        out[y] = v
    return bytes(out)


class Pic:
    """a 40 x 25 picture: text, sprite frames and free bitmap areas"""

    def __init__(self, st, frames):
        self.st, self.frames = st, frames
        self.g = np.zeros((25, 40), int)
        self.col = np.full((25, 40), A.WHITE, int)
        self.bits = np.zeros((200, 320), bool)
        self.ink = np.full((25, 40), -1, int)

    def text(self, c, r, s, colour):
        for i, ch in enumerate(s):
            self.g[r, c + i] = ord(ch) - 32
            self.col[r, c + i] = colour

    def ctext(self, r, s, colour):
        self.text((40 - len(s)) // 2, r, s, colour)

    def sprite(self, c, r, name, colour, add=0):
        f = self.frames[name] + add
        n = (1 + f // FRAMES_PER_BANK) * 128 + 16 + (f % FRAMES_PER_BANK) * 16
        for k, (dx, dy) in enumerate(((0, 0), (1, 0), (0, 1), (1, 1))):
            self.g[r + dy, c + dx] = n + k
            self.col[r + dy, c + dx] = colour

    def glyph(self, c, r, n, colour):
        self.g[r, c] = n
        self.col[r, c] = colour

    def blit(self, x, y, a, colour):
        h, w = a.shape
        self.bits[y:y + h, x:x + w] |= a
        for r in range(y // 8, (y + h + 7) // 8):
            for c in range(x // 8, (x + w + 7) // 8):
                self.ink[r, c] = colour

    def bake(self, first_bank):
        for r in range(25):
            for c in range(40):
                if self.ink[r, c] < 0:
                    continue
                p = cell_bytes(self.bits, c, r)
                self.g[r, c] = self.st.alloc(p, first_bank)
                self.col[r, c] = self.ink[r, c]
        lo = bytes(0x80 | (int(v) & 127) for v in self.g.flat)
        hi = bytes(int(v) >> 7 for v in self.g.flat)
        col = bytes(int(v) for v in self.col.flat)
        return lo + hi + col


def big_text(text, sx, sy):
    rows = []
    for r in range(7):
        line = []
        for ch in text:
            for b in A.FD[ch].split()[r]:
                line += [b == '1'] * sx
            line += [False] * sx
        rows += [line] * sy
    a = np.array(rows, bool)[:, :-sx]
    a[3::4, :] = False                      # scan-line stripes
    return a


def scale(a, k):
    return np.kron(a[:, :12], np.ones((k, k), bool))


def build_gfx():
    st = Store()
    # ---- bank 0: font (glyph = char - 32), icons, fence, shots, bolts
    for i, f in enumerate(A.font_glyphs()):
        st.put(i, f)
    equ = {}
    n = 64
    for name, pat in A.ICONS.items():
        st.put(n, pat)
        equ['G_' + name.upper()] = 0x80 | n
        n += 1
    equ['G_SHOT'] = 0x80 | n
    for pat in A.SHOT_H + A.SHOT_V + A.SHOT_D1 + A.SHOT_D2:
        st.put(n, pat, share=False)
        n += 1
    equ['G_BOLT'] = 0x80 | n
    for pat in A.BOLT_A + A.BOLT_B:
        st.put(n, pat, share=False)
        n += 1
    assert n <= 128
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
    first_pic_bank = 1 + (len(F) + FRAMES_PER_BANK - 1) // FRAMES_PER_BANK
    print('sprites: %d frames in banks 1..%d' % (len(F), first_pic_bank - 1))

    # ---- the title picture
    p = Pic(st, fnum)
    t = big_text('ROGUE', 4, 4)
    p.blit((320 - t.shape[1]) // 2 // 8 * 8 + 4, 8, t, A.BRED)
    t = big_text('MUSTER', 4, 4)
    p.blit((320 - t.shape[1]) // 2 // 8 * 8 + 4, 40, t, A.YELLOW)
    p.ctext(10, 'KOOLABAH STATION - 2186', A.BCYAN)
    scene = [(2, A.HARV1, A.YELLOW), (7, A.HEEL1, A.BRED), (12, A.SHEAR1, A.BMAGENTA),
             (18, A.JO_D1, A.WHITE), (22, A.HAND_A1, A.BGREEN),
             (26, A.SHEAR3, A.BMAGENTA), (30, A.MAG2, A.BCYAN), (35, A.mirror(A.HEEL2), A.BRED)]
    for c, a, colour in scene:
        p.blit(c * 8, 12 * 8, scale(a, 2), colour)
    p.ctext(16, 'THE MUSTERING MACHINES HAVE GONE ROGUE', A.WHITE)
    p.ctext(17, 'BRING THE STATION HANDS HOME, JO', A.WHITE)
    p.ctext(19, 'MOVE  W A S D       FIRE  I J K L', A.BGREEN)
    p.ctext(20, 'HOLD A FIRE KEY TO KEEP SHOOTING', A.GREY)
    p.ctext(22, 'VIBED BY BPM 2026', A.BCYAN)
    for c in range(40):
        p.glyph(c, 15, 64 + (4 if c % 4 == 0 else 3), A.BROWN)       # a run of fence
    title = p.bake(first_pic_bank)

    # ---- the rogue mob
    p = Pic(st, fnum)
    p.ctext(0, 'THE ROGUE MOB', A.YELLOW)
    rows = [('HEELER', 0, A.BRED, 'HEELER', '100', 'RUNS YOU DOWN. THEY COME IN PACKS'),
            ('SHEARER', 0, A.BMAGENTA, 'SHEARER', '200', 'LINES YOU UP AND THROWS BLADES'),
            ('HARV', 0, A.YELLOW, 'HARVESTER', '500', 'FOUR HITS. FLATTENS STATION HANDS'),
            ('MAGGIE', 1, A.BCYAN, 'MAGGIE', '150', 'SWOOPS FROM CORNER TO CORNER'),
            ('PYLON', 1, A.BBLUE, 'LIVE PYLON', '25', 'ZAPS YOU - AND ANY HEELER'),
            ('HUMAN', 0, A.BGREEN, 'STATION HAND', '1000-5000', 'WALK INTO THEM TO BRING THEM HOME')]
    for i, (fr, add, colour, name, pts, desc) in enumerate(rows):
        r = 2 + i * 3
        p.sprite(2, r, fr, colour, add)
        p.text(6, r, name, colour)
        p.text(38 - len(pts), r, pts, A.WHITE)
        p.text(6, r + 1, desc, A.GREY)
    p.glyph(3, 20, equ['G_PIP'] & 127, A.YELLOW)
    p.text(6, 20, '3 CHARGE CELLS A LIFE', A.WHITE)
    p.ctext(22, 'P PAUSE    M SOUND    ESC TITLE', A.BCYAN)
    info = p.bake(first_pic_bank)
    print('glyphs used: %d of 2048' % sum(st.used))

    blk = bytearray(st.data())
    assert len(blk) == PIC_BASE
    blk += title + info
    open(os.path.join(BUILD, 'GFX.BNK'), 'wb').write(blk)

    # ---- gen.inc
    L = ['; generated by tools/build.py']
    for k, v in equ.items():
        L.append('%s equ $%02X' % (k, v))
    for k, v in fnum.items():
        L.append('F_%s equ %d' % (k, v))
    L.append('PIC_TITLE equ $%04X' % PIC_BASE)
    L.append('PIC_INFO equ $%04X' % (PIC_BASE + PIC_LEN))
    open(os.path.join(SRC, 'gen.inc'), 'w').write('\n'.join(L) + '\n')
    # ---- tables (page aligned): frames; cell offset of each grid row
    L = ['; generated by tools/build.py', '\tALIGN 256', 'frametab:\t\t; char of the first glyph, bank']
    for ch, bank in ftab:
        L.append('\tdb $%02X,%d' % (ch, bank))
    off = [(2 + y // 2) * 40 + 1 for y in range(44)]
    L += ['\tALIGN 256', 'ytlo:\t\t\t; arena row y (4-pixel units) -> screen offset of column 1',
          '\tdb ' + ','.join(str(o & 255) for o in off), '\tds 256-44', 'ythi:',
          '\tdb ' + ','.join(str(o >> 8) for o in off)]
    open(os.path.join(SRC, 'tables.inc'), 'w').write('\n'.join(L) + '\n')
    return st, F


def sheet(st, F):
    """a contact sheet of the frames, for checking the art"""
    from PIL import Image
    k = 6
    img = np.zeros((16 * k, len(F) * 16 * k), np.uint8)
    for i, (n, a) in enumerate(F):
        img[:12 * k, i * 16 * k:(i + 1) * 16 * k] = np.kron(a, np.ones((k, k), np.uint8)) * 255
    Image.fromarray(img).save(os.path.join(BUILD, 'sheet.png'))


# ---------------------------------------------------------------- program, loader, disk
LOADFILES = [('STG_PROG', 0x00, 'RM', 'BIN'), (7, 0x00, 'GFX', 'BNK')]


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
    files = {'MUSTER.COM': (B / 'MUSTER.COM').read_bytes()}
    for b_, o, n, e in LOADFILES:
        files['%s.%s' % (n, e)] = (B / ('%s.%s' % (n, e))).read_bytes()
    files['CCP.SYS'] = (Path(ROOT) / 'resources' / 'CCP.SYS').read_bytes()
    readme = Path(ROOT) / 'docs' / 'DISK_README.TXT'
    files['README.TXT'] = readme.read_text().replace('\r\n', '\n').replace('\n', '\r\n').encode('ascii') + b'\x1a'
    used = BD.build_disk(sysdisk, files, B / 'MUSTER.DS8')
    print('MUSTER.DS8: %d of 196 blocks used (%dK free), %d files' % (used, (196 - used) * 4, len(files)))


if __name__ == '__main__':
    st, F = build_gfx()
    sheet(st, F)
    import music
    music.build(os.path.join(SRC, 'music.inc'))
    if '--noasm' not in sys.argv:
        assemble()
        disk()
