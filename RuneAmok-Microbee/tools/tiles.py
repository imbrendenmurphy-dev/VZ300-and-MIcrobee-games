"""Tile dictionary and the binary tile lists the Z80 composes views from.

A tile is (glyph, colour). Glyph g lives in PCG bank g >> 7 at slot
g & 127; on screen its code is 80h | (g & 127) and its attribute the bank.
Glyph 0 is blank.
"""
import struct

MAXG = 14 * 128 + 64     # banks 0-13, then bank 15 slots 0-63


class Dict:
    def __init__(self):
        self.pats = [bytes(10)]
        self.index = {bytes(10): 0}

    def add(self, pat):
        g = self.index.get(pat)
        if g is None:
            g = len(self.pats)
            self.pats.append(pat)
            self.index[pat] = g
        return g

    def tile(self, pat, colour):
        g = self.add(pat)
        if g >= 14 * 128:
            return (0x80 | (g - 14 * 128), 15, colour)
        return (0x80 | (g & 127), g >> 7, colour)

    def blob(self):
        assert len(self.pats) <= MAXG, 'too many glyphs: %d' % len(self.pats)
        return b''.join(self.pats)


class Blob:
    """a 32K block image with simple allocation"""
    def __init__(self, size=0x8000):
        self.data = bytearray()
        self.size = size

    def here(self):
        return len(self.data)

    def put(self, b):
        a = len(self.data)
        self.data += b
        assert len(self.data) <= self.size, 'block full'
        return a

    def align(self, n):
        while len(self.data) % n:
            self.data.append(0)

    def poke_w(self, at, v):
        struct.pack_into('<H', self.data, at, v)

    def bytes(self):
        return bytes(self.data)
