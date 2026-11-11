"""Pack one area's native maze art (maze_native.py) into the run-time atlas.

Layout of the packet (unpacked into RAM block 2):
  0   dw  glyph count (glyph data, 8 bytes each, starts the second packet in RAM block 31)
  4   db  decorations            5  db objects
  8   12 x (code, attr, colour)  panel/bar symbols
  46  dw  skyline piece (0 = none)
  48  dw  object table in the second packet: per object 3 words (depth 1..3), 0 = none
  50  dw  viewport background, 3 planes of 26x24 exactly as the work buffer wants them
  64  dw  piece pointers: 0..2 full-screen bases (old run format), then
          3+kind*20+pos walls and 43+((decor-1)*2+kind)*20+pos decorations
Wall/decor runs: count, dw address in the work buffer, codes, attrs, colours.
Object cells:   dw address, colour, 8 mask bytes, 8 pattern bytes; ends dw $FFFF.
"""
from pathlib import Path
import sys
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
import maze_native as MN

VPBUF = 0xDA60            # work buffer in the game's upper memory
PLANE = 640               # spacing of its code / attribute / colour planes
ATLAS_MAX = 13 * 128 + 64  # PCG banks 0..12 plus the unused tails of the two font banks
SLOTS = {1: (0, 80), 2: (80, 32), 3: (112, 16)}   # bank 13: run-time object glyphs


def glyph_ref(i):
    if i < 13 * 128:
        return (i & 127) | 128, i >> 7
    j = i - 13 * 128
    return 128 | (96 + (j & 31)), 14 + (j >> 5)


def vp_addr(cell):
    return VPBUF + (cell // 40) * 26 + cell % 40


def reduce_glyphs(use, limit):
    """Fold the rarest glyphs into their nearest neighbours until the set fits.
    Returns {glyph: replacement}. Differences are a few pixels inside dither."""
    glyphs = sorted(use, key=lambda g: -use[g])
    remap = {}
    if len(glyphs) <= limit:
        return remap
    arr = np.array([int.from_bytes(g, 'big') for g in glyphs], dtype=np.uint64)
    alive = np.ones(len(glyphs), bool)
    need = len(glyphs) - limit
    for threshold in range(1, 20):
        for i in range(len(glyphs) - 1, 0, -1):
            if need <= 0:
                break
            if not alive[i] or glyphs[i] == bytes(8):
                continue
            x = np.bitwise_xor(arr[:i], arr[i])
            bits = np.zeros(i, np.uint8)
            for s in range(0, 64, 8):
                bits += POP[((x >> np.uint64(s)) & np.uint64(255)).astype(np.uint8)]
            bits[~alive[:i]] = 99
            j = int(bits.argmin())
            if bits[j] <= threshold:
                remap[glyphs[i]] = glyphs[j]
                alive[i] = False
                need -= 1
        if need <= 0:
            break
    assert need <= 0, 'glyph budget'
    for g in list(remap):                # resolve chains
        t = remap[g]
        while t in remap:
            t = remap[t]
        remap[g] = t
    return remap


POP = np.array([bin(i).count('1') for i in range(256)], np.uint8)

ICONS = [([0] * 8, 0), ([0xff, 0x81, 0x81, 0xbd, 0xa5, 0xbd, 0x81, 0xff], 12), ([0xff, 0x81, 0xbd, 0xa5, 0xa5, 0xbd, 0x81, 0xff], 11),
         ([0, 0, 0x18, 0x3c, 0x3c, 0x18, 0, 0], 13), ([0, 0, 0, 0x18, 0x18, 0, 0, 0], 8), ([0x18, 0x3c, 0x7e, 0x18, 0x18, 0x18, 0, 0], 11),
         ([0, 0x10, 0x18, 0x7c, 0x7e, 0x7c, 0x18, 0x10], 11), ([0, 0, 0x18, 0x18, 0x18, 0x7e, 0x3c, 0x18], 11),
         ([0, 8, 0x18, 0x3e, 0x7e, 0x3e, 0x18, 8], 11),
         ([0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0], 9), ([0, 0x7e, 0x42, 0x42, 0x42, 0x42, 0x7e, 0], 8),
         ([0, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0x7e, 0], 14)]


def frame_cells():
    """Panel divider and message rule: a gold double line with studs."""
    cells = {}
    rail = bytes([0x24] * 8)
    stud = bytes([0x24, 0x24, 0x3c, 0x7e, 0x7e, 0x3c, 0x24, 0x24])
    bar = bytes([0, 0, 0xff, 0, 0, 0xff, 0, 0])
    bstud = bytes([0, 0x18, 0xff, 0x3c, 0x3c, 0xff, 0x18, 0])
    for y in range(24):
        cells[y * 40 + 26] = (stud if y % 6 == 3 else rail, 11, 0)
    for x in range(40):
        cells[24 * 40 + x] = (bstud if x % 6 == 1 else bar, 11, 0)
    cells[24 * 40 + 26] = (bytes([0x24, 0x24, 0xe7, 0x24, 0x24, 0xe7, 0, 0]), 11, 0)
    return cells


def build(region):
    art = MN.build_area(region)
    ad = MN.AR.AREAS[region]
    nd, nobj = len(ad.decors), len(ad.objects)
    base = {i: (bytes(8), 0, 0) for i in range(1280)}
    base.update(art['base'])
    base.update(frame_cells())
    groups = [base] + list(art['walls'].values()) + list(art['decor'].values())
    if 'skyline' in art:
        groups.append(art['skyline'])
    use = {}
    for cells in groups:
        for rows, fg, bg in cells.values():
            use[rows] = use.get(rows, 0) + 1
    for rows, ink in ICONS:
        use[bytes(rows)] = use.get(bytes(rows), 0) + 1000
    use[bytes(8)] = 10 ** 6
    remap = reduce_glyphs(use, ATLAS_MAX)
    order = sorted((g for g in use if g not in remap), key=lambda g: -use[g])
    index = {g: i for i, g in enumerate(order)}
    assert index[bytes(8)] == 0

    def ref(cell):
        rows, fg, bg = cell
        code, attr = glyph_ref(index[remap.get(rows, rows)])
        return code, attr, bg * 16 + fg

    def old_runs(cells):
        data = bytearray()
        for y in range(32):
            xs = sorted(i % 40 for i in cells if i // 40 == y)
            while xs:
                left = xs.pop(0)
                run = [ref(cells[y * 40 + left])]
                while xs and xs[0] == left + len(run):
                    run.append(ref(cells[y * 40 + xs.pop(0)]))
                data.append(len(run)); data += (y * 40 + left).to_bytes(2, 'little')
                for plane in range(3):
                    data += bytes(t[plane] for t in run)
        return bytes(data + b'\0')

    def runs(cells):
        data = bytearray()
        for y in range(24):
            xs = sorted(i % 40 for i in cells if i // 40 == y)
            while xs:
                left = xs.pop(0)
                run = [ref(cells[y * 40 + left])]
                while xs and xs[0] == left + len(run):
                    run.append(ref(cells[y * 40 + xs.pop(0)]))
                data.append(len(run)); data += vp_addr(y * 40 + left).to_bytes(2, 'little')
                for plane in range(3):
                    data += bytes(t[plane] for t in run)
        return bytes(data + b'\0')

    pieces = [old_runs(base), old_runs(base), b'\0']
    for ki in range(2):
        for pos in range(20):
            pieces.append(runs(art['walls'][ki, pos]))
    for di in range(nd):
        for ki in range(2):
            for pos in range(20):
                cells = art['decor'].get((di, ki, pos))
                if cells is None:
                    cells = art['decor'].get((di, 1 - ki, pos), {})
                pieces.append(runs(cells))
    objects = []
    for oi in range(nobj):
        for d in (1, 2, 3):
            cells = art['objects'].get((oi, d * 5 + 2), [])
            assert len(cells) <= SLOTS[d][1], (ad.name, ad.objects[oi], d, len(cells))
            data = bytearray()
            for cell, opaque, rows, mask, fg in cells:
                data += vp_addr(cell).to_bytes(2, 'little') + bytes([fg]) + mask + rows
            objects.append(bytes(data + b'\xff\xff') if cells else b'')
    sky = runs(art['skyline']) if 'skyline' in art else b''
    vp = bytearray(3 * 624)
    for y in range(24):
        for x in range(26):
            c = ref(base[y * 40 + x])
            for plane in range(3):
                vp[plane * 624 + y * 26 + x] = c[plane]

    header = 64 + 2 * len(pieces)
    packet = bytearray(header)
    packet[0:2] = len(order).to_bytes(2, 'little')
    packet[4], packet[5] = nd, nobj
    icons = [ref((bytes(rows), ink, 0)) for rows, ink in ICONS]
    packet[8:8 + 36] = bytes(v for t in icons for v in t)

    def put(off, value):
        packet[off:off + 2] = value.to_bytes(2, 'little')

    second = bytearray(b''.join(order))        # RAM block 31: glyphs, then objects
    stored = {}
    for i, p in enumerate(pieces):
        if p not in stored:
            stored[p] = len(packet); packet += p
        put(64 + i * 2, stored[p])
    if sky:
        put(46, len(packet)); packet += sky
    put(50, len(packet)); packet += vp
    table = len(second); put(48, table); second += bytes(6 * nobj)
    for i, data in enumerate(objects):
        if data:
            second[table + i * 2:table + i * 2 + 2] = len(second).to_bytes(2, 'little'); second += data
    assert len(packet) <= 32768 and len(second) <= 32768, (ad.name, len(packet), len(second))
    report = {'area': ad.name, 'glyphs': len(order), 'folded_glyphs': len(remap), 'packet_bytes': len(packet), 'second_bytes': len(second),
              'pieces': len(pieces), 'object_cells': sum(len(o) // 19 for o in objects)}
    return bytes(packet), bytes(second), report


if __name__ == '__main__':
    for region in range(6):
        packet, second, report = build(region)
        print(report)
