"""MICROBEE MEGADEMO: textures for the live rotozoomer and the prerendered
effects (tunnel, perspective floor, swirl, twist).

Live textures are 64 x 32 tiles of COLOUR BYTES whose paper is a bright
colour (8-15), so every byte is 80h-FFh: in colour it goes into the colour
RAM over a checker glyph (half ink, half paper); in mono the same byte is
a screen code whose glyph (PCG bank 0) has the byte's brightness as dots.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from gfx import *  # noqa

PAL = np.array([(0, 0, 0), (192, 0, 0), (0, 192, 0), (192, 96, 0), (0, 0, 192), (192, 0, 192), (0, 192, 192), (192, 192, 192),
                (96, 96, 96), (255, 64, 64), (64, 255, 64), (255, 255, 64), (64, 64, 255), (255, 64, 255), (64, 255, 255), (255, 255, 255)],
               np.float32)
LUM = PAL @ np.array([0.30, 0.59, 0.11], np.float32)

BAYER8 = np.array([[0, 32, 8, 40, 2, 34, 10, 42], [48, 16, 56, 24, 50, 18, 58, 26], [12, 44, 4, 36, 14, 46, 6, 38],
                   [60, 28, 52, 20, 62, 30, 54, 22], [3, 35, 11, 43, 1, 33, 9, 41], [51, 19, 59, 27, 49, 17, 57, 25],
                   [15, 47, 7, 39, 13, 45, 5, 37], [63, 31, 55, 23, 61, 29, 53, 21]])


def byte_rgb(b):
    return (PAL[b & 15] + PAL[b >> 4]) / 2


# the 128 bytes 80h-FFh: their mixed colours
LIVE_RGB = np.array([byte_rgb(b) for b in range(128, 256)])


def live_quantize(rgb):
    """an RGB image -> the nearest live bytes (80h-FFh)"""
    h, w, _ = rgb.shape
    d = ((rgb.reshape(-1, 1, 3).astype(np.float32) - LIVE_RGB[None]) ** 2).sum(-1)
    return (np.argmin(d, 1) + 128).reshape(h, w).astype(np.uint8)


def live_mono_glyphs():
    """PCG bank 0 for mono: glyph k (code 80h + k) = the brightness of byte 80h + k as dots"""
    data = bytearray(2048)
    for k in range(128):
        b = 128 + k
        y = (LUM[b & 15] + LUM[b >> 4]) / 2 / 255.0
        lv = int(round(min(1.0, y * 1.15) * 64))
        for line in range(16):
            v = 0
            for x in range(8):
                if BAYER8[line & 7][x] < lv:
                    v |= 0x80 >> x
            data[k * 16 + line] = v if line < 8 else 0
    return bytes(data)


def _font(size):
    for f in ('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf'):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    return ImageFont.load_default()


def _tile(draw_fn, ss=4):
    """draw at ss x, box-filter down to 64 x 32"""
    im = Image.new('RGB', (64 * ss, 32 * ss))
    draw_fn(im, ImageDraw.Draw(im), ss)
    im = im.resize((64, 32), Image.BOX)
    return np.array(im)


def tile_bpm():
    """two BPM signs, staggered like bricks (so the tile repeats as a wall)"""
    def d(im, dr, s):
        a = np.zeros((32 * s, 64 * s, 3), np.uint8)
        yy, xx = np.mgrid[0:32 * s, 0:64 * s]
        t = np.abs(((yy % (16 * s)) + 0.5) / (16 * s) - 0.5) * 2
        a[..., 0] = (60 + 100 * t).astype(np.uint8)
        a[..., 1] = 0
        a[..., 2] = (220 - 80 * t).astype(np.uint8)
        im.paste(Image.fromarray(a))
        dr = ImageDraw.Draw(im)
        f = _font(14 * s)
        txt = 'BPM'
        bb = dr.textbbox((0, 0), txt, font=f)
        w, h = bb[2] - bb[0], bb[3] - bb[1]
        for cx, cy in ((32, 8), (0, 24), (64, 24)):
            x0 = cx * s - w // 2 - bb[0]
            y0 = cy * s - h // 2 - bb[1]
            dr.text((x0 + s, y0 + s), txt, font=f, fill=(0, 0, 0))
            dr.text((x0, y0), txt, font=f, fill=(255, 255, 64))
        for y in (0, 16):
            dr.rectangle([0, y * s, 64 * s - 1, y * s + s - 1], fill=(64, 255, 255))
    return _tile(d)


def tile_honey():
    def d(im, dr, s):
        dr.rectangle([0, 0, 64 * s, 32 * s], fill=(60, 30, 0))
        r = 8 * s
        hexw = r * np.sqrt(3)
        for row in range(-1, 4):
            for col in range(-1, 6):
                cx = col * 16 * s + (8 * s if row % 2 else 0)
                cy = row * 16 * s
                pts = [(cx + 0.92 * r * np.cos(np.pi / 6 + k * np.pi / 3), cy + 0.92 * r * np.sin(np.pi / 6 + k * np.pi / 3)) for k in range(6)]
                dr.polygon(pts, fill=(255, 200, 40))
                pts2 = [(cx - 2 * s + 0.45 * r * np.cos(np.pi / 6 + k * np.pi / 3), cy - 2 * s + 0.45 * r * np.sin(np.pi / 6 + k * np.pi / 3)) for k in range(6)]
                dr.polygon(pts2, fill=(255, 255, 140))
    # the hex grid above has period 16 x ~30: make it tile exactly in 64 x 32 by drawing on a torus
    return _tile(d)


def tile_checker():
    yy, xx = np.mgrid[0:32, 0:64].astype(np.float32)
    c = ((xx // 16) + (yy // 16)) % 2 == 1
    qx = (xx % 16) - 7.5
    qy = (yy % 16) - 7.5
    r = np.sqrt(qx * qx + qy * qy)
    img = np.zeros((32, 64, 3), np.float32)
    img[c] = (255, 64, 64)
    img[~c] = (64, 64, 255)
    ring = (r > 3.5) & (r < 6)
    img[ring & c] = (255, 255, 64)
    img[ring & ~c] = (64, 255, 255)
    return img.astype(np.uint8)


def tile_smiley():
    def d(im, dr, s):
        dr.rectangle([0, 0, 64 * s, 32 * s], fill=(160, 0, 200))
        for cy in (8, 24):
            for cx in (8, 24, 40, 56):
                X, Y = (cx + (8 if cy == 24 else 0)) * s, cy * s
                for ox in ((-64, 0, 64) if cy == 24 else (0,)):
                    x = X + ox * s
                    R = 7 * s
                    dr.ellipse([x - R, Y - R, x + R, Y + R], fill=(255, 255, 40))
                    for ex in (-3, 2):
                        dr.rectangle([x + ex * s, Y - 4 * s, x + (ex + 1) * s, Y - 1 * s], fill=(0, 0, 0))
                    dr.arc([x - 5 * s, Y - 4 * s, x + 5 * s, Y + 5 * s], 25, 155, fill=(0, 0, 0), width=s)
    return _tile(d)


def tile_tartan():
    yy, xx = np.mgrid[0:32, 0:64]
    img = np.zeros((32, 64, 3), np.float32)
    img[:] = (20, 90, 30)
    v = ((xx % 16) < 5)
    h = ((yy % 16) < 5)
    img[v] += (150, 0, 0)
    img[h] += (150, 0, 0)
    thin_v = (xx % 16) == 10
    thin_h = (yy % 16) == 10
    img[thin_v | thin_h] = (255, 255, 120)
    img[(xx % 32) == 26] = (40, 40, 255)
    img[(yy % 32) == 26] = (40, 40, 255)
    return np.clip(img, 0, 255).astype(np.uint8)


LIVE_TILES = [('BPM', tile_bpm), ('HONEYCOMB', tile_honey), ('CHECKERS', tile_checker),
              ('SMILEY', tile_smiley), ('TARTAN', tile_tartan)]


def live_tile_bytes(fn):
    return live_quantize(fn())


def live_texture_block(tile):
    """the whole 32K texture: 128 rows of 256, the tile repeated"""
    t = np.tile(tile, (4, 4))
    assert t.shape == (128, 256)
    return t.astype(np.uint8).tobytes()


# =====================================================================
#  PRERENDERED EFFECTS: texel = shade (0-7) << 5 | hue (0-31). The block's
#  ramp pages map it: 16 colour pages (the hue families cycle), 1 mono.
# =====================================================================
FAMILIES = [(BLUE, BBLUE), (CYAN, BCYAN), (GREEN, BGREEN), (BROWN, YELLOW), (RED, BRED), (MAGENTA, BMAGENTA),
            (DGREY, WHITE), (BLUE, BMAGENTA)]


def shade_byte(shade, fam):
    dk, br = FAMILIES[fam % len(FAMILIES)]
    pairs = [(BLACK, BLACK), (BLACK, dk), (dk, dk), (dk, br), (br, br), (br, WHITE), (WHITE, br), (WHITE, WHITE)]
    a, b = pairs[shade]
    return (b << 4) | a


def fx_ramp_pages(cycle=True):
    pages = []
    for k in range(16):
        pg = []
        for t in range(256):
            shade, hue = t >> 5, t & 31
            fam = (hue // 4 + (k if cycle else 0) // 2) % len(FAMILIES)
            pg.append(shade_byte(shade, fam))
        pages.append(bytes(pg))
    mono = bytes(0x81 + [0, 1, 2, 3, 5, 6, 7, 8][t >> 5] for t in range(256))
    return pages, mono


def _grid(ss=1):
    """block centres (ss = 1) or ss x ss subsamples per block, in screen
    units (a block is 16 x 12): arrays of shape (24 ss, 32 ss)"""
    xs = (np.arange(32 * ss) + 0.5) / ss * 16.0 - 256.0
    ys = (np.arange(24 * ss) + 0.5) / ss * 12.0 - 144.0
    return np.meshgrid(xs, ys)


def _pool(a, ss):
    return a.reshape(24, ss, 32, ss).mean(axis=(1, 3))


def _texel(shade, hue):
    sh = np.clip(np.round(shade), 0, 7).astype(int)
    return ((sh << 5) | (hue.astype(int) & 31)).astype(np.uint8)


SS = 4


def fx_tunnel(n):
    X, Y = _grid(SS)
    Xc, Yc = _grid(1)
    out = []
    for f in range(n):
        ph = f / n
        cx = 70 * np.sin(2 * np.pi * ph) + 30 * np.sin(4 * np.pi * ph)
        cy = 40 * np.cos(2 * np.pi * ph)
        def field(X, Y):
            dx, dy = X - cx, Y - cy
            r = np.sqrt(dx * dx + dy * dy) + 1e-3
            ang = np.arctan2(dy, dx) / (2 * np.pi)
            v = 6000.0 / r + 64 * ph * 6
            u = ang * 12 + ph
            ring = np.floor(v / 32).astype(int)
            seg = (np.floor(u * 2) % 2).astype(int)
            return r, ring, (ring + seg) & 1
        r, ring, chk = field(X, Y)
        fog = np.clip((r - 12) / 200.0, 0, 1)
        shade = np.where(r < 14, 0.0, 1 + fog * 3.2 + chk * 2.2)
        rc, ringc, _ = field(Xc, Yc)
        out.append(_texel(_pool(shade, SS), ((ringc >> 1) * 4)))
    return out


def fx_floor(n):
    X, Y = _grid(SS)
    Xc, Yc = _grid(1)
    out = []
    horizon = -36.0
    for f in range(n):
        ph = f / n
        sway = 0.35 * np.sin(2 * np.pi * ph)
        ca, sa = np.cos(sway), np.sin(sway)
        def field(X, Y):
            h = Y - horizon
            floor = h > 0
            ah = np.maximum(np.abs(h), 0.5)
            z = np.where(floor, 7000.0 / ah, 5000.0 / ah)      # camera 7000/f above the floor
            xw = X * z / 180.0
            u = xw * ca - z * sa + 40 * np.sin(2 * np.pi * ph)
            v = xw * sa + z * ca + 64 * 3 * ph                 # 3 tiles a loop
            chk = ((np.floor(u / 64) + np.floor(v / 64)) % 2).astype(int)
            fog = np.clip(1.0 - z / 1500.0, 0, 1)
            return floor, chk, fog
        floor, chk, fog = field(X, Y)
        shade = fog * (1.5 + chk * 4.5)
        fc, _, _ = field(Xc, Yc)
        hue = np.where(fc, 8, 20)
        out.append(_texel(_pool(shade, SS), hue))
    return out


def bpm_big():
    """a big BPM sign, 192 x 96 (luminance 0-1)"""
    im = Image.new('L', (192, 96), 40)
    dr = ImageDraw.Draw(im)
    f = _font(70)
    bb = dr.textbbox((0, 0), 'BPM', font=f)
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    dr.text(((192 - w) // 2 - bb[0], (96 - h) // 2 - bb[1]), 'BPM', font=f, fill=255)
    dr.rectangle([0, 0, 191, 3], fill=150)
    dr.rectangle([0, 92, 191, 95], fill=150)
    return np.array(im, np.float32) / 255.0


def fx_swirl(n, tile=None):
    """a big BPM sign twirled about the centre, the twirl breathing"""
    X, Y = _grid(SS)
    Xc, Yc = _grid(1)
    img = bpm_big()
    th, tw = img.shape
    r = np.sqrt(X * X + Y * Y)
    rc = np.sqrt(Xc * Xc + Yc * Yc)
    out = []
    for f in range(n):
        ph = f / n
        k = 2.4 * np.sin(2 * np.pi * ph)
        a = k * np.exp(-r / 170.0)
        ca, sa = np.cos(a), np.sin(a)
        u = (X * ca - Y * sa) * 0.42 + tw / 2
        v = (X * sa + Y * ca) * 0.42 / 1.0 + th / 2
        L = img[np.floor(v).astype(int) % th, np.floor(u).astype(int) % tw]
        shade = 0.6 + L * 6.4
        ac = k * np.exp(-rc / 170.0)
        hue = ((rc / 40 + ac * 2).astype(int) * 4) & 31
        out.append(_texel(_pool(shade, SS), hue))
    return out


def fx_twist(n):
    """stripes twisted down the screen, each row turned a little more"""
    X, Y = _grid(SS)
    Xc, Yc = _grid(1)
    out = []
    for f in range(n):
        ph = f / n
        def field(X, Y):
            a = 2 * np.pi * ph + 1.4 * np.sin(Y / 70.0 + 2 * np.pi * ph * 2)
            ca, sa = np.cos(a), np.sin(a)
            u = X * ca + Y * 0.2 * sa
            band = np.floor(u / 48 + 0.5).astype(int)
            frac = (u / 48 + 0.5) % 1
            edge = np.abs(frac - 0.5) * 2
            return band, (1 - edge ** 2) * 6.5 * (0.55 + 0.45 * np.abs(ca)) + 0.5
        band, shade = field(X, Y)
        bc, _ = field(Xc, Yc)
        out.append(_texel(_pool(shade, SS), bc * 4))
    return out


def fx_blocks(frames, per=36, cycle=True):
    pages, mono = fx_ramp_pages(cycle)
    blocks = []
    for b in range(len(frames) // per):
        blk = bytearray(32768)
        for k in range(16):
            blk[k * 256:(k + 1) * 256] = pages[k]
        blk[16 * 256:17 * 256] = mono
        for j in range(per):
            o = (20 + 3 * j) * 256
            blk[o:o + 768] = frames[b * per + j].tobytes()
        blocks.append(bytes(blk))
    return blocks


def preview_fx(frame, page=0):
    pages, mono = fx_ramp_pages()
    cb = np.frombuffer(pages[page], np.uint8)[frame]
    rgb = np.array([[byte_rgb(b) for b in row] for row in cb], np.uint8)
    return Image.fromarray(rgb).resize((32 * 16, 24 * 12), Image.NEAREST)
