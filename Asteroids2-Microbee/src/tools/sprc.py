"""Sprite compiler for the column-major PCG bitmap.

Screen layout (per page): 64 byte-columns; column cx lives in PCG bank
page*8 + cx/8 at address F800h + (cx&7)*256, one byte per scan line, so a
column is 256 contiguous bytes and 'inc l' walks down with free vertical wrap.

Every sprite gets 4 pre-shifted variants (2-pixel steps).  Each variant is a
routine: HL = top of first column, C = y0, current PCG bank selected.  Columns
are separated by  ld l,c : inc h : call z,next_bank  and the routine returns.
Bytes fully inside an opaque silhouette are stored (ld (hl),n); edge bytes
are ORed; empty bytes are skipped.  Per variant we also emit erase spans
(first row, row count) per column for the eraser.
"""
import numpy as np

BLOCK = 32768


def variant_columns(pix, mask, opaque, shift):
    h, w = pix.shape
    cols = (w + 6 + 7) // 8
    W = cols * 8
    P = np.zeros((h, W), bool); M = np.zeros((h, W), bool)
    P[:, shift:shift + w] = pix
    M[:, shift:shift + w] = mask
    out = []
    for c in range(cols):
        pb = [int(''.join('1' if v else '0' for v in P[y, c * 8:c * 8 + 8]), 2) for y in range(h)]
        mb = [int(''.join('1' if v else '0' for v in M[y, c * 8:c * 8 + 8]), 2) for y in range(h)]
        out.append((pb, mb))
    return cols, out


def compile_column(pb, mb, opaque):
    code = bytearray()
    skip = 0
    for p, m in zip(pb, mb):
        if opaque and m == 0xFF:
            kind = 'st'
        elif p:
            kind = 'or'
        else:
            kind = None
        if kind is None:
            skip += 1
            continue
        if skip:
            if skip >= 4:
                code += bytes([0x7D, 0xC6, skip, 0x6F])       # ld a,l : add a,n : ld l,a
            else:
                code += bytes([0x2C]) * skip                  # inc l
            skip = 0
        if kind == 'st':
            code += bytes([0x36, p])                          # ld (hl),n
        else:
            code += bytes([0x7E, 0xF6, p, 0x77])              # ld a,(hl) : or n : ld (hl),a
        skip = 1                                              # the pending inc l
    return code


def spans(pb, mb, opaque):
    rows = [y for y, (p, m) in enumerate(zip(pb, mb)) if p or (opaque and m == 0xFF)]
    if not rows:
        return (0, 0)
    return (rows[0], rows[-1] - rows[0] + 1)


def compile_all(sprites, next_bank_addr):
    """returns banks (list of bytearray), table entries per sprite"""
    banks = [bytearray()]
    table = []
    cache = {}
    for name, pix, mask, opaque in sprites:
        h, w = pix.shape
        variants = []
        for s in range(4):
            cols, cdata = variant_columns(pix, mask, opaque, s * 2)
            code = bytearray()
            sp = []
            for i, (pb, mb) in enumerate(cdata):
                if i:
                    code += bytes([0x69, 0x24, 0xCC, next_bank_addr & 255, next_bank_addr >> 8])  # ld l,c : inc h : call z,nb
                code += compile_column(pb, mb, opaque)
                sp.append(spans(pb, mb, opaque))
            code += bytes([0xC9])
            key = bytes(code)
            if key in cache:
                bi, addr = cache[key]
            else:
                if len(banks[-1]) + len(code) > BLOCK:
                    banks.append(bytearray())
                bi, addr = len(banks) - 1, len(banks[-1])
                banks[-1] += code
                cache[key] = (bi, addr)
            variants.append((bi, addr, sp))
        table.append((name, cols, h, w, variants))
    return banks, table
