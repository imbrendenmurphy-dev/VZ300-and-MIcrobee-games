"""THE LANTERN DEEP - title illustration.

Painted in full colour at screen proportions (640 x 352 "visual" pixels,
the 192 real lines are about 1.83x taller than wide), reduced to the
640 x 192 Premium raster, then converted cell by cell: for every 8x8 cell
the best pair of the 16 Premium colours is chosen and the pixels are
ordered-dithered between them. Identical cells share a PCG glyph.

Animation: the torch flames are re-painted in 4 frames - their cells get
private PCG glyphs that the title code rewrites. The logo glint, rune
glow and the shimmer from the depths are colour-only animations.

Output: build/TITLE.BNK and src/gen/title_data.asm
"""
import math
import random
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
PAL = np.array([(0, 0, 0), (192, 0, 0), (0, 192, 0), (192, 192, 0), (0, 0, 192), (192, 0, 192), (0, 192, 192), (192, 192, 192),
                (96, 96, 96), (255, 0, 0), (0, 255, 0), (255, 255, 0), (0, 0, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255)], dtype=np.float32)
VW, VH = 640, 352
COLS, ROWS = 80, 24
ART_ROWS = 18                  # rows 0..17 illustration, 18..23 menu and credit
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16 + 1 / 32
FONT = '/usr/share/fonts/opentype/noto/NotoSerifCJK-Black.ttc'

ARCH_CX, ARCH_W, ARCH_TOP, ARCH_BOT = 320, 220, 118, 262
TORCH_X = (150, 490)
TORCH_Y = 170


def vy(row):
    return row * 8 * VH / 192.0


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def torch_light(x, y):
    """warm light from the two torches at a visual pixel"""
    v = 0.0
    for tx in TORCH_X:
        d = math.hypot((x - tx) / 1.0, (y - TORCH_Y) / 1.0)
        v += max(0.0, 1.0 - d / 230.0) ** 1.6
    return min(1.0, v)


def paint_base(rnd_seed=3):
    rnd = random.Random(rnd_seed)
    im = Image.new('RGB', (VW, VH), (0, 0, 0))
    d = ImageDraw.Draw(im)
    art_h = vy(ART_ROWS)
    # ---- masonry: large ashlar blocks, lit by the torches
    y = 82
    course = 0
    while y < art_h:
        h = rnd.choice((22, 24, 26))
        x = -rnd.randint(0, 40)
        while x < VW:
            w = rnd.randint(46, 84)
            cx, cy = x + w / 2, y + h / 2
            L = torch_light(cx, cy)
            # tones that sit on the Premium palette: black > dark grey >
            # ochre > yellow, highlights a step brighter
            if L > 0.62:
                base, hi = (205, 205, 20), (255, 255, 120)
            elif L > 0.40:
                base, hi = (150, 150, 10), (230, 230, 60)
            elif L > 0.22:
                base, hi = (85, 82, 40), (180, 180, 20)
            elif L > 0.08:
                base, hi = (48, 48, 48), (100, 100, 70)
            else:
                base, hi = (14, 14, 14), (60, 60, 60)
            d.rectangle([x + 2, y + 2, x + w - 2, y + h - 2], fill=base)
            d.line([x + 2, y + 2, x + w - 2, y + 2], fill=hi, width=2)      # lit top edge
            d.line([x + 2, y + 2, x + 2, y + h - 2], fill=hi, width=1)
            # pits and cracks
            for _ in range(rnd.randint(0, 3)):
                px, py = rnd.randint(x + 6, x + max(7, w - 6)), rnd.randint(y + 6, y + max(7, h - 6))
                d.ellipse([px - 2, py - 1, px + 2, py + 1], fill=lerp(base, (0, 0, 0), 0.6))
            x += w
        y += h
        course += 1
    # ---- the archway: dark mouth with stairs descending into a cyan glow
    ax0, ax1 = ARCH_CX - ARCH_W // 2, ARCH_CX + ARCH_W // 2
    r = ARCH_W // 2
    mouth = Image.new('L', (VW, VH), 0)
    md = ImageDraw.Draw(mouth)
    md.rectangle([ax0, ARCH_TOP + r, ax1, ARCH_BOT], fill=255)
    md.ellipse([ax0, ARCH_TOP, ax1, ARCH_TOP + 2 * r], fill=255)
    inner = Image.new('RGB', (VW, VH), (0, 0, 0))
    idr = ImageDraw.Draw(inner)
    # glow from the depths
    for yy in range(ARCH_TOP, ARCH_BOT + 1):
        t = (yy - ARCH_TOP) / (ARCH_BOT - ARCH_TOP)
        g = t ** 2.2
        idr.line([ax0, yy, ax1, yy], fill=lerp((0, 0, 0), (0, 150, 190), g))
    # stairs: receding steps
    for k in range(9):
        t = k / 8
        yy = ARCH_BOT - (1 - t) ** 1.5 * 0 - k * 13
        wv = (ax1 - ax0) * (0.95 - 0.07 * k)
        x0 = ARCH_CX - wv / 2
        col = lerp((0, 210, 255), (0, 40, 70), t)
        idr.line([x0, yy, x0 + wv, yy], fill=col, width=3)
        idr.line([x0, yy + 3, x0 + wv, yy + 3], fill=lerp(col, (0, 0, 0), 0.6), width=4)
    # a lone small light far below - the lantern?
    idr.ellipse([ARCH_CX - 4, ARCH_BOT - 128, ARCH_CX + 4, ARCH_BOT - 120], fill=(255, 255, 200))
    im.paste(inner, (0, 0), mouth)
    # ---- voussoirs round the arch, some carved with runes
    n = 15
    for i in range(n):
        a0 = math.pi + i * math.pi / n
        a1 = math.pi + (i + 1) * math.pi / n
        cy = ARCH_TOP + r
        pts = []
        for a in (a0, a1):
            pts.append((ARCH_CX + math.cos(a) * (r + 4), cy + math.sin(a) * (r + 4)))
        for a in (a1, a0):
            pts.append((ARCH_CX + math.cos(a) * (r + 34), cy + math.sin(a) * (r + 34)))
        L = torch_light(sum(p[0] for p in pts) / 4, sum(p[1] for p in pts) / 4)
        fill = lerp((70, 70, 70), (215, 215, 200), min(1, L + 0.25))
        d.polygon(pts, fill=fill, outline=(0, 0, 0))
        if i in (2, 5, 9, 12):
            # carved rune, glowing faintly cyan
            mx = sum(p[0] for p in pts) / 4
            my = sum(p[1] for p in pts) / 4
            d.line([mx - 4, my - 6, mx + 4, my + 6], fill=(0, 230, 255), width=3)
            d.line([mx + 4, my - 6, mx - 4, my + 6], fill=(0, 230, 255), width=3)
    # jambs
    for side in (-1, 1):
        x0 = ARCH_CX + side * (r + 4) if side > 0 else ARCH_CX - r - 34
        for k in range(5):
            yy = ARCH_TOP + r + k * 28
            if yy > ARCH_BOT:
                break
            L = torch_light(x0 + 15, yy + 14)
            d.rectangle([x0, yy, x0 + 30, min(ARCH_BOT, yy + 26)], fill=lerp((70, 70, 70), (215, 215, 200), min(1, L + 0.25)),
                        outline=(0, 0, 0))
    # keystone with the lantern sigil
    d.polygon([(ARCH_CX - 22, ARCH_TOP - 36), (ARCH_CX + 22, ARCH_TOP - 36), (ARCH_CX + 15, ARCH_TOP + 8), (ARCH_CX - 15, ARCH_TOP + 8)],
              fill=(230, 230, 220), outline=(0, 0, 0))
    # the lantern sigil carved in the keystone
    d.rectangle([ARCH_CX - 7, ARCH_TOP - 22, ARCH_CX + 7, ARCH_TOP - 2], fill=(255, 255, 60), outline=(20, 20, 20), width=3)
    d.line([ARCH_CX - 9, ARCH_TOP - 24, ARCH_CX + 9, ARCH_TOP - 24], fill=(20, 20, 20), width=3)
    d.line([ARCH_CX, ARCH_TOP - 32, ARCH_CX, ARCH_TOP - 24], fill=(20, 20, 20), width=3)
    # ---- floor threshold
    fy = ARCH_BOT + 2
    d.rectangle([0, fy, VW, art_h], fill=(10, 8, 6))
    for k in range(4):
        yy = fy + 6 + k * 9
        d.line([0, yy, VW, yy], fill=lerp((30, 24, 20), (110, 80, 40), 0.6 - k * 0.12), width=2)
    # ---- iron sconces
    for tx in TORCH_X:
        d.rectangle([tx - 4, TORCH_Y + 4, tx + 4, TORCH_Y + 40], fill=(70, 60, 50))
        d.polygon([(tx - 14, TORCH_Y - 2), (tx + 14, TORCH_Y - 2), (tx + 8, TORCH_Y + 10), (tx - 8, TORCH_Y + 10)], fill=(110, 90, 70))
    return im


def paint_flames(im, frame):
    """two torch flames, frame 0..3"""
    rnd = random.Random(100 + frame)
    d = ImageDraw.Draw(im)
    for tx in TORCH_X:
        lean = (-6, 2, 7, -2)[frame] + rnd.uniform(-2, 2)
        hgt = (50, 58, 46, 54)[frame]
        base_y = TORCH_Y - 2
        # outer red, middle yellow, white core
        for col, wf, hf in (((255, 0, 0), 1.0, 1.0), ((255, 255, 0), 0.62, 0.78), ((255, 255, 255), 0.3, 0.45)):
            w = 16 * wf
            h = hgt * hf
            pts = [(tx - w, base_y), (tx - w * 0.7, base_y - h * 0.45), (tx + lean * hf, base_y - h),
                   (tx + w * 0.7, base_y - h * 0.5), (tx + w, base_y)]
            d.polygon(pts, fill=col)
        # sparks
        for k in range(3):
            sx = tx + rnd.uniform(-14, 14) + lean
            sy = base_y - hgt - rnd.uniform(4, 30)
            d.ellipse([sx - 1.5, sy - 2.5, sx + 1.5, sy + 2.5], fill=(255, 220, 80))


def paint_logo(im):
    d = ImageDraw.Draw(im)
    big = ImageFont.truetype(FONT, 66)
    small = ImageFont.truetype(FONT, 26)
    # carved gold lettering: shadow, body gradient, highlight
    text = 'LANTERN DEEP'
    bbox = d.textbbox((0, 0), text, font=big)
    tw = bbox[2] - bbox[0]
    x0 = (VW - tw) // 2 - bbox[0]
    y0 = 6
    mask = Image.new('L', (VW, VH), 0)
    ImageDraw.Draw(mask).text((x0, y0), text, font=big, fill=255)
    shadow = Image.new('L', (VW, VH), 0)
    ImageDraw.Draw(shadow).text((x0 + 3, y0 + 4), text, font=big, fill=255)
    # gradient body
    grad = Image.new('RGB', (VW, VH))
    gd = ImageDraw.Draw(grad)
    for yy in range(VH):
        t = (yy - y0 - 10) / 60.0
        t = max(0.0, min(1.0, t))
        gd.line([0, yy, VW, yy], fill=lerp((255, 255, 235), (190, 190, 0), t))
    im.paste((60, 30, 0), (0, 0), shadow)
    im.paste(grad, (0, 0), mask)
    # 'THE' above, flanked by rules
    t2 = 'THE'
    b2 = d.textbbox((0, 0), t2, font=small)
    tx = (VW - (b2[2] - b2[0])) // 2 - b2[0]
    d.text((tx, -6), t2, font=small, fill=(220, 220, 220))
    for side in (-1, 1):
        xa = VW // 2 + side * 40
        xb = VW // 2 + side * 170
        d.line([xa, 10, xb, 10], fill=(190, 190, 0), width=2)
        d.ellipse([xb - 3, 7, xb + 3, 13], fill=(255, 255, 60))
    return mask


# ------------------------------------------------------------------ conversion
def to_raster(im):
    """visual 640x352 -> real 640x192 (area average)"""
    return np.asarray(im.resize((640, 192), Image.BOX), dtype=np.float32)


ALLOWED = [0, 1, 3, 4, 6, 7, 8, 9, 11, 14, 15]       # no greens or magentas on the title
PAIRS = [(a, b) for a in ALLOWED for b in ALLOWED if a < b]


def convert(raster, rows=ART_ROWS):
    """-> list per cell (glyph bytes, fg, bg)"""
    out = {}
    for cy in range(rows):
        for cx in range(COLS):
            px = raster[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8].reshape(64, 3)
            best = None
            # single colour
            for c in ALLOWED:
                e = ((px - PAL[c]) ** 2).sum()
                if best is None or e < best[0]:
                    best = (e, c, c, None)
            for a, b in PAIRS:
                ca, cb = PAL[a], PAL[b]
                v = cb - ca
                vv = (v * v).sum()
                t = np.clip(((px - ca) @ v) / vv, 0, 1)
                e = ((px - (ca + t[:, None] * v)) ** 2).sum() * 1.15
                if e < best[0]:
                    best = (e, a, b, t)
            _, a, b, t = best
            if t is None:
                bits = np.zeros(64, dtype=np.uint8)
                fg = bg = a
            else:
                th = np.tile(BAYER, (2, 2)).reshape(64)
                bits = (t > th).astype(np.uint8)            # 1 -> colour b
                fg, bg = b, a
                if bits.sum() == 0:
                    fg = bg = a
                elif bits.sum() == 64:
                    fg = bg = b
                    bits[:] = 0
            g = tuple(int(''.join(str(x) for x in bits[r * 8:r * 8 + 8]), 2) for r in range(8))
            if fg == bg:
                g = (0,) * 8
            out[(cx, cy)] = (g, fg, bg)
    return out


def preview(cells, path, extra=None):
    img = np.zeros((192, 640, 3), dtype=np.uint8)
    for (cx, cy), (g, fg, bg) in cells.items():
        for r in range(8):
            for b in range(8):
                on = (g[r] >> (7 - b)) & 1
                img[cy * 8 + r, cx * 8 + b] = PAL[fg if on else bg]
    Image.fromarray(img).resize((1280, 768), Image.NEAREST).save(path)


def build():
    base = paint_base()
    logo_mask = paint_logo(base)
    frames = []
    for f in range(4):
        im = base.copy()
        paint_flames(im, f)
        frames.append(convert(to_raster(im)))
    cells0 = frames[0]
    # animated cells: pattern or colour differ between flame frames
    anim = sorted(k for k in cells0 if any(fr[k] != cells0[k] for fr in frames[1:]))
    # logo cells (for the glint): cells where the logo mask covers pixels
    lm = np.asarray(logo_mask.resize((640, 192), Image.BOX))
    logo = sorted((cx, cy) for (cx, cy) in cells0 if lm[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8].mean() > 40
                  and cells0[(cx, cy)][1] in (3, 11, 15, 7))
    # depth shimmer: cyan cells inside the arch mouth
    glow = sorted(k for k, (g, fg, bg) in cells0.items() if fg in (6, 14) or bg in (6, 14))
    print('animated %d, logo %d, glow %d' % (len(anim), len(logo), len(glow)))
    return frames, anim, logo, glow


def pack(frames, anim, logo, glow):
    cells0 = frames[0]
    banks = [[] for _ in range(15)]
    index = {}
    scr = bytearray([0x80] * 1920)
    attr = bytearray([15] * 1920)
    col = bytearray(1920)

    def alloc(g, unique=False):
        if not unique and g in index:
            return index[g]
        for b in range(15):
            if len(banks[b]) < 128:
                banks[b].append(g)
                slot = (b, len(banks[b]) - 1)
                if not unique:
                    index[g] = slot
                return slot
        raise RuntimeError('title needs more than 1920 glyphs')
    blank = alloc((0,) * 8)
    animset = set(anim)
    for (cx, cy), (g, fg, bg) in sorted(cells0.items(), key=lambda kv: (kv[0][1], kv[0][0])):
        o = cy * 80 + cx
        b, s = alloc(g, unique=(cx, cy) in animset)
        scr[o] = 0x80 | s
        attr[o] = b
        col[o] = fg | (bg << 4)
    used = sum(len(x) for x in banks)
    print('title glyphs used %d of 1920' % used)
    pcg = bytearray()
    for b in range(15):
        for s in range(128):
            pcg += bytes(banks[b][s] if s < len(banks[b]) else (0,) * 8)
    # animation records: DW offset, DB bank, DB slot, then 4 x (8 rows, colour)
    an = bytearray()
    for (cx, cy) in anim:
        o = cy * 80 + cx
        an += o.to_bytes(2, 'little') + bytes([attr[o], scr[o] & 0x7F])
        for fr in frames:
            g, fg, bg = fr[(cx, cy)]
            an += bytes(g) + bytes([fg | (bg << 4)])
    lg = bytearray()
    logo_sorted = sorted(logo, key=lambda c: (c[0], c[1]))
    col_index = []
    for c in range(81):
        col_index.append(sum(1 for (cx, cy) in logo_sorted if cx < c))
    for (cx, cy) in logo_sorted:
        o = cy * 80 + cx
        lg += o.to_bytes(2, 'little') + bytes([cx, col[o]])
    lg += bytes(col_index)               # first logo cell of each column (81 bytes)
    gl = bytearray()
    for (cx, cy) in glow:
        o = cy * 80 + cx
        gl += o.to_bytes(2, 'little') + bytes([col[o], (cx * 3 + cy * 5) & 7])
    blob = pcg                                   # 0000-3BFF
    blob += bytes(0x3C00 - len(blob))
    blob += scr + attr + col                     # 3C00-528F
    off_anim = len(blob)
    blob += an
    off_logo = len(blob)
    blob += lg
    off_glow = len(blob)
    blob += gl
    assert len(blob) < 0x7FF0, hex(len(blob))
    (ROOT / 'build' / 'TITLE.BNK').write_bytes(blob)
    asm = ['; generated by tools/title.py',
           'TB_SCR EQU $3C00', 'TB_ATTR EQU $3C00+1920', 'TB_COL EQU $3C00+3840',
           'TB_ANIM EQU $%04X' % off_anim, 'TB_NANIM EQU %d' % len(anim), 'TB_ANIMREC EQU %d' % (4 + 4 * 9),
           'TB_LOGO EQU $%04X' % off_logo, 'TB_NLOGO EQU %d' % len(logo), 'TB_LOGOIDX EQU TB_LOGO+%d' % (4 * len(logo)),
           'TB_GLOW EQU $%04X' % off_glow, 'TB_NGLOW EQU %d' % len(glow),
           'TB_LEN EQU $%04X' % len(blob)]
    (ROOT / 'src' / 'gen' / 'title_data.asm').write_text('\n'.join(asm) + '\n')
    return scr, attr, col


if __name__ == '__main__':
    frames, anim, logo, glow = build()
    pack(frames, anim, logo, glow)
    preview(frames[0], ROOT / 'out' / 'title_preview.png')
