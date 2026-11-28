"""BILBIES! Microbee sprites: pack 1-bit frames with a dark outline into
pre-shifted column data for src/render.asm (draw_sprite).

A frame is a list of strings ('#' = ink, '.' or ' ' = clear, 'o' = forced
outline/paper hole). The anchor (ax, ay) is the pixel that goes to the
sprite's (x, y). Each frame is stored once per pixel shift 0-7:
    columns, then for each byte column: first row, rows, (AND, OR) pairs.
"""
import numpy as np


def grid_of(rows):
    h = len(rows)
    w = max(len(r) for r in rows)
    on = np.zeros((h, w), bool)
    hole = np.zeros((h, w), bool)
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c in '#X@':
                on[y, x] = True
            elif c == 'o':
                hole[y, x] = True
    return on, hole


def outline(on, below=True, foot_row=None):
    h, w = on.shape
    p = np.pad(on, 1)
    d = np.zeros_like(p)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy == 1 and not below:
                continue
            d |= np.roll(np.roll(p, dy, 0), dx, 1)
    o = d & ~p
    if foot_row is not None:
        o[foot_row + 2:, :] = False          # never darken the ground under the feet
    return p, o                               # padded by 1 on every side


class Frame:
    def __init__(self, rows, ax, ay, outline_on=True, foot=True):
        on, hole = grid_of(rows)
        if outline_on:
            p, o = outline(on, foot_row=ay if foot else None)
            hp = np.pad(hole, 1)
            self.on = p
            self.cut = (o | hp) & ~p
            self.ax, self.ay = ax + 1, ay + 1
        else:
            self.on = on
            self.cut = hole & ~on
            self.ax, self.ay = ax, ay

    def block(self, shift):
        """data block for pixel shift 0-7: the sprite's left edge (x - ax) is
        at byte column (x - ax) >> 3, and shift = (x - ax) & 7"""
        h, w = self.on.shape
        W = ((w + shift + 7) // 8) * 8
        on = np.zeros((h, W), bool)
        cut = np.zeros((h, W), bool)
        on[:, shift:shift + w] = self.on
        cut[:, shift:shift + w] = self.cut
        cols = []
        for c in range(W // 8):
            o = on[:, c * 8:c * 8 + 8]
            k = cut[:, c * 8:c * 8 + 8]
            used = (o | k).any(1)
            if not used.any():
                cols.append(None)
                continue
            r0 = int(np.argmax(used))
            r1 = h - int(np.argmax(used[::-1]))
            data = []
            for y in range(r0, r1):
                m = 0
                d = 0
                for b in range(8):
                    if o[y, b] or k[y, b]:
                        m |= 0x80 >> b
                    if o[y, b]:
                        d |= 0x80 >> b
                data += [(~m) & 255, d]
            cols.append((r0, r1 - r0, data))
        # trim empty columns at the ends but keep interior ones (as 0 rows)
        while cols and cols[-1] is None:
            cols.pop()
        lead = 0
        while cols and cols[0] is None:
            cols.pop(0)
            lead += 1
        out = bytearray([len(cols)])
        for c in cols:
            if c is None:
                out += bytes([0, 0])
            else:
                r0, n, data = c
                out += bytes([r0, n]) + bytes(data)
        return lead, bytes(out)


class Packer:
    """fills 32K banks with frames; each frame gets an index entry
    (bank, address of its 8-entry shift table)"""
    def __init__(self, first_bank, nbanks, base=0x0000):
        self.banks = [bytearray() for _ in range(nbanks)]
        self.first = first_bank
        self.cur = 0
        self.base = base
        self.index = []
        self.leads = []

    def add(self, fr):
        blocks = [self._nolead(fr, s) for s in range(8)]
        size = 16 + sum(len(b) for b in blocks)
        if len(self.banks[self.cur]) + size > 32768:
            self.cur += 1
            assert self.cur < len(self.banks), 'sprite banks full'
        bank = self.banks[self.cur]
        at = len(bank)
        addr = self.base + at + 16
        tab = bytearray()
        data = bytearray()
        for b in blocks:
            tab += bytes([(addr + len(data)) & 255, (addr + len(data)) >> 8])
            data += b
        bank += tab + data
        self.index.append((self.first + self.cur, self.base + at))
        return len(self.index) - 1

    def _nolead(self, fr, s):
        h, w = fr.on.shape
        W = ((w + s + 7) // 8) * 8
        on = np.zeros((h, W), bool)
        cut = np.zeros((h, W), bool)
        on[:, s:s + w] = fr.on
        cut[:, s:s + w] = fr.cut
        out = bytearray([W // 8, h])
        for c in range(W // 8):
            o = on[:, c * 8:c * 8 + 8]
            k = cut[:, c * 8:c * 8 + 8]
            used = (o | k).any(1)
            if not used.any():
                out += bytes([0, 0])
                continue
            r0 = int(np.argmax(used))
            r1 = h - int(np.argmax(used[::-1]))
            out += bytes([r0, r1 - r0])
            for y in range(r0, r1):
                m = d = 0
                for b in range(8):
                    if o[y, b] or k[y, b]:
                        m |= 0x80 >> b
                    if o[y, b]:
                        d |= 0x80 >> b
                out += bytes([(~m) & 255, d])
        return bytes(out)
