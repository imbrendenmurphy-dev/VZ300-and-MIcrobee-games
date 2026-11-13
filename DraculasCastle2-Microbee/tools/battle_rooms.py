"""Ordinary monsters fight in the room the hero is standing in.

The ghoulies are drawn cell-exact: every 8x8 cell a monster touches holds only
the monster and black, never a pixel of the room. So a battle screen is the
area's room map with the monster's cells laid over it, and the Microbee can
compose any monster into any room when the battle loads.

Room packet:   dw glyph bytes, glyphs (16 bytes each, PCG banks 0..4),
               map 3840 (codes, banks, colours).
Sprite packet: dw glyph bytes, glyphs (PCG banks 5..13), then 20x23-cell
               windows (rows 2..24, columns 10..29) of codes, banks and
               colours, 460 bytes each plane; code 0 leaves the room showing.
               Frames 0..2, then the Ghost's eight idle phases.
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
import native_art as art
import ghoulies

ORDINARY = (1, 2, 3, 6, 7, 9, 12)       # bat, skeleton, ghost, zombie, slime, knight, bride
ROOM_GLYPHS = 640                         # PCG banks 0..4
SPRITE_BASE = 640                         # PCG banks 5..13
SPRITE_GLYPHS = 13 * 128 + 128 - SPRITE_BASE
WIN_ROW, WIN_COL, WIN_H, WIN_W = 2, 10, 23, 20
AT = (80, 18)


def panel(im):
    d = ImageDraw.Draw(im); P = art.PAL
    d.rectangle((0, 200, 319, 255), fill=(0, 0, 0))
    d.line((1, 199, 318, 199), fill=tuple(P[11])); d.line((1, 249, 318, 249), fill=tuple(P[11]))
    d.line((1, 199, 1, 249), fill=tuple(P[11])); d.line((318, 199, 318, 249), fill=tuple(P[11]))
    for x in (5, 310):
        for y in (204, 220, 236):
            d.polygon([(x, y), (x + 3, y + 4), (x, y + 8), (x - 3, y + 4)], outline=tuple(P[12]))


def ref(i):
    return (i & 127) | 128, i >> 7


def room_image(area, mono):
    im = art.backdrop(area, mono).crop((0, 0, 320, 256))
    panel(im)
    return im


def room(area, mono):
    raw, pic = art.encode(room_image(area, mono), mono, 8)
    glyphs = [raw[k * 16:k * 16 + 16] for k in range(1280)]
    order = list(dict.fromkeys(glyphs))
    assert len(order) <= ROOM_GLYPHS, (area, mono, len(order))
    index = {g: i for i, g in enumerate(order)}
    codes = bytes(ref(index[g])[0] for g in glyphs)
    banks = bytes(ref(index[g])[1] for g in glyphs)
    data = len(order) * 16
    return data.to_bytes(2, 'little') + b''.join(order) + codes + banks + raw[20480:], pic


def poses(monster):
    i = monster - 1
    out = [ghoulies.monster(i, f, art.PAL) for f in range(3)]
    if monster == 3:
        out += [ghoulies.ghost(0, p).image(art.PAL) for p in range(8)]
    return out


def sprite(monster, mono):
    windows, glyphs, order = [], [], {}
    for sp in poses(monster):
        im = Image.new('RGB', (320, 256))
        im.paste(sp, AT, sp)
        alpha = np.zeros((256, 320), bool)
        a = np.asarray(sp)[:, :, 3] > 0
        alpha[AT[1]:AT[1] + a.shape[0], AT[0]:AT[0] + a.shape[1]] = a[:256 - AT[1], :320 - AT[0]]
        raw, _ = art.encode(im, mono, 8)
        planes = [bytearray(WIN_H * WIN_W) for _ in range(3)]
        for r in range(WIN_H):
            for c in range(WIN_W):
                y, x = WIN_ROW + r, WIN_COL + c
                if not alpha[y * 8:y * 8 + 8, x * 8:x * 8 + 8].any():
                    continue
                k = y * 40 + x
                g = raw[k * 16:k * 16 + 16]
                if g not in order:
                    order[g] = SPRITE_BASE + len(order); glyphs.append(g)
                code, bank = ref(order[g])
                planes[0][r * WIN_W + c], planes[1][r * WIN_W + c], planes[2][r * WIN_W + c] = code, bank, raw[20480 + k]
        # nothing the monster touches may fall outside the window
        rows, cols = np.nonzero(alpha.reshape(32, 8, 40, 8).any((1, 3)))
        assert rows.min() >= WIN_ROW and rows.max() < WIN_ROW + WIN_H and cols.min() >= WIN_COL and cols.max() < WIN_COL + WIN_W
        windows.append(b''.join(map(bytes, planes)))
    assert len(glyphs) <= SPRITE_GLYPHS, (monster, mono, len(glyphs))
    data = len(glyphs) * 16
    return data.to_bytes(2, 'little') + b''.join(glyphs) + b''.join(windows)


def preview(monster, area, mono, frame=0):
    """Reference composition, exactly what the Z80 builds at load time."""
    im = room_image(area, mono)
    sp = poses(monster)[frame]
    a = np.asarray(sp)[:, :, 3] > 0
    d = ImageDraw.Draw(im)
    for y in range(32):
        for x in range(40):
            sy, sx = y * 8 - AT[1], x * 8 - AT[0]
            if a[max(0, sy):max(0, sy + 8), max(0, sx):max(0, sx + 8)].any():
                d.rectangle((x * 8, y * 8, x * 8 + 7, y * 8 + 7), fill=(0, 0, 0))
    im.paste(sp, AT, sp)
    return art.encode(im, mono, 8)[1]


def encode_room(area, mono):
    return art.encode(room_image(area, mono), mono, 8)[1]
