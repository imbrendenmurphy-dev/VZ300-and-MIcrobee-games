"""MICROBEE MEGADEMO: build the parts' graphics into RAM-block files and
src/assets.inc (constants, setup job lists).

A part's video set-up is a list of jobs, streamed into video RAM by the
demo while the music plays: (kind, destination, length, block, offset).
kind: 0 screen RAM, 1 attribute RAM, 2 colour RAM, 10h + n PCG bank n;
+40h only in mono, +20h only in colour.
"""
import sys
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gfx import *  # noqa

BLK_DATA = 4            # data blocks from here (the loader puts DATAn.BNK in BLK_DATA + n)
K_SCR, K_ATTR, K_COL, K_PCG = 0, 1, 2, 0x10
F_MONO, F_COLOUR = 0x40, 0x20


N_SMALL = 5             # blocks 4-8: the small data; whole 32K blocks from 9


class Packer:
    def __init__(self):
        self.blocks = [bytearray()]
        self.full = []

    def add_full(self, data):
        assert len(data) == 32768
        self.full.append(bytes(data))
        return BLK_DATA + N_SMALL + len(self.full) - 1, 0

    def all_blocks(self):
        assert len(self.blocks) <= N_SMALL, 'small data needs %d blocks' % len(self.blocks)
        small = [bytes(b) for b in self.blocks] + [b''] * (N_SMALL - len(self.blocks))
        return [b if b else bytes(1) for b in small] + self.full

    def add_aligned(self, data, align):
        cur = len(self.blocks[-1])
        pad = (-cur) % align
        if cur + pad + len(data) > 32768:
            self.blocks.append(bytearray())
            pad = 0
        self.blocks[-1] += bytes(pad)
        return self.add(data)

    def add(self, data):
        data = bytes(data)
        if len(data) == 32768:
            return self.add_full(data)
        assert len(data) <= 32768
        if len(self.blocks[-1]) + len(data) > 32768:
            self.blocks.append(bytearray())
        off = len(self.blocks[-1])
        self.blocks[-1] += data
        return BLK_DATA + len(self.blocks) - 1, off


class Part:
    def __init__(self, name, packer):
        self.name = name
        self.pk = packer
        self.jobs = []
        self.consts = {}
        self.tables = []        # asm text

    def job(self, kind, dst, data, flags=0):
        blk, off = self.pk.add(data)
        self.jobs.append((kind | flags, dst, len(data), blk, off))

    def screen(self, scr, pcgbanks, mono_differs=True):
        """upload a whole Screen and PCG banks (only the used parts)"""
        used = [i for i in range(2048) if scr.owner[i]]
        lo, hi = (min(used), max(used) + 1) if used else (0, 0)
        # contiguous runs of used cells
        runs = []
        i = 0
        while i < 2048:
            if scr.owner[i]:
                j = i
                while j < 2048 and scr.owner[j]:
                    j += 1
                runs.append((i, j))
                i = j
            else:
                i += 1
        for a, b in runs:
            self.job(K_SCR, a, scr.code[a:b])
            self.job(K_ATTR, a, scr.attr[a:b])
            if mono_differs and not np.array_equal(scr.col[a:b], scr.mcol[a:b]):
                self.job(K_COL, a, scr.col[a:b], F_COLOUR)
                self.job(K_COL, a, scr.mcol[a:b], F_MONO)
            else:
                self.job(K_COL, a, scr.col[a:b])
        for bank, data in pcgbanks.items():
            data = bytes(data)
            n = len(data.rstrip(b'\0'))
            n = (n + 15) // 16 * 16
            if n:
                self.job(K_PCG + bank, 0, data[:n])

    def asm(self):
        out = ['; ---- part %s' % self.name]
        for k, v in self.consts.items():
            out.append('%s\tequ %d' % (k, v))
        out.append('%s_jobs:' % self.name)
        for kind, dst, n, blk, off in self.jobs:
            out.append('\tdb $%02X\n\tdw %d, %d\n\tdb %d\n\tdw $%04X' % (kind, dst, n, blk, off))
        out.append('\tdb $FF')
        out += self.tables
        return '\n'.join(out) + '\n'


def tab(name, values, kind='db'):
    lines = ['%s:' % name]
    for i in range(0, len(values), 16):
        lines.append('\t%s %s' % (kind, ','.join(str(int(v)) for v in values[i:i + 16])))
    return '\n'.join(lines)


# ---------------------------------------------------------------------
#  permanent: font (bank 15), line-0 patterns (banks 13, 14)
# ---------------------------------------------------------------------
def common(pk):
    p = Part('common', pk)
    font = font8x16()
    fb = bytearray(2048)
    fb[:96 * 16] = font.tobytes()
    p.job(K_PCG + BK_FONT, 0, fb[:96 * 16])
    pat0, pat1 = bytearray(2048), bytearray(2048)
    for g in range(128):
        pat0[g * 16] = g
        pat1[g * 16] = 128 + g
    p.job(K_PCG + BK_PAT0, 0, pat0)
    p.job(K_PCG + BK_PAT1, 0, pat1)
    p.tables.append('font_ram:\n\tINCBIN "../build/font.bin"')
    # pre-shifted font for 2-pixel-step scrollers: phase q (0-3) at q x 4K:
    # left part (font << 2q) at +0, right part (font >> (8 - 2q)) at +2K
    sf = bytearray(16384)
    for q in range(4):
        for c in range(96):
            for r in range(16):
                v = int(font[c][r])
                sf[q * 4096 + c * 16 + r] = (v << (2 * q)) & 255
                sf[q * 4096 + 2048 + c * 16 + r] = (v >> (8 - 2 * q)) if q else 0
    blk, off = pk.add_aligned(sf, 4096)
    p.consts['SF_BLK'] = blk
    p.consts['SF_OFF'] = off
    sn = [int(round(127 * np.sin(2 * np.pi * i / 256))) & 255 for i in range(256)]
    p.tables.append('\tALIGN 256\n' + tab('sin_tab', sn))
    sv = [int(round(127 * np.sin(2 * np.pi * i / 256))) for i in range(256)]
    p.tables.append(tab('t_bcentre', [196 + (v >> 2) + (v >> 5) for v in sv]))
    # Kefrens: line steps baked in (index = line): 14 sin(2 x 2y) and 30 + 13 sin(2 x 5y)
    p.tables.append('\tALIGN 256\n' + tab('kf_sin14', [int(round(14 * np.sin(2 * np.pi * 2 * i / 256))) & 255 for i in range(256)]))
    p.tables.append(tab('kf_sin13', [int(round(30 + 13 * np.sin(2 * np.pi * 5 * i / 256))) & 255 for i in range(256)]))
    p.tables.append('\tALIGN 256\n' + tab('t_div5', [i // 5 for i in range(256)]))
    (BUILD / 'font.bin').write_bytes(font.tobytes())
    return p


def pat_cell(byte):
    """the (bank, code) of the glyph whose line 0 is byte"""
    return (BK_PAT0, 0x80 | byte) if byte < 128 else (BK_PAT1, 0x80 | (byte - 128))


if __name__ == '__main__':
    import parts
    pk = Packer()
    out = ['; generated by tools/assets.py']
    out.append(common(pk).asm())
    for mk in parts.ALL:
        out.append(mk(pk).asm())
    (ROOT / 'src' / 'assets.inc').write_text('\n'.join(out))
    for f in BUILD.glob('DATA*.BNK'):
        f.unlink()
    blocks = pk.all_blocks()
    for i, b in enumerate(blocks):
        (BUILD / ('DATA%d.BNK' % i)).write_bytes(bytes(b))
    print('data: %d blocks (%d-%d), %d bytes' % (len(blocks), BLK_DATA, BLK_DATA + len(blocks) - 1, sum(len(b) for b in blocks)))
