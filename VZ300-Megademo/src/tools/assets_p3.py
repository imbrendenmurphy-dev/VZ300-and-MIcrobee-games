"""Part 3 assets: raster insanity.
Kefrens bars (mode 1 line-hold), rolling colour-set bands, synthwave mode(1) picture,
FLD rubber stretch tables, copper text."""
import numpy as np, os
from vzgfx import *

from vzcfg import D
KEF_ROW = 5       # text rows above kefrens

def build(out):
    os.makedirs(out, exist_ok=True)
    # ---------- top logo (5 rows) : "RASTER" in SG4 ----------
    cells = np.full((10, 64), BLACK)
    bm = text_bitmap('RASTER')
    x0 = (64 - bm.shape[1]) // 2
    rampc = [MAGENTA, RED, ORANGE, YELLOW, BUFF]
    big = np.zeros((10, 64), bool)
    for y in range(7):
        for x in range(bm.shape[1]):
            if bm[y, x]:
                big[1 + y, x0 + x] = True
    for y in range(10):
        for x in range(64):
            if big[y, x]:
                cells[y, x] = rampc[y // 2]
    logo = sg4_from_index(cells)
    open(f'{out}/klogo.bin', 'wb').write(logo)

    # ---------- kefrens sine path (values = byte offset within the buffer row) ----------
    i = np.arange(256)
    x = 13.5 + 9.0 * np.sin(2 * np.pi * i / 128) + 4.5 * np.sin(2 * np.pi * i / 51 + 1.0)
    x = np.clip(np.round(x), 0, 29).astype(int)
    base = (KEF_ROW * 32) & 255
    open(f'{out}/ksine.bin', 'wb').write(bytes((base + v) & 255 for v in x))
    x2 = 14 + 13 * np.sin(2 * np.pi * i / 256 * 3) * np.cos(2 * np.pi * i / 256)
    x2 = np.clip(np.round(x2), 0, 29).astype(int)
    open(f'{out}/ksine2.bin', 'wb').write(bytes((base + v) & 255 for v in x2))

    # ---------- static table A: text lines, then kefrens css0 (until S2 takes over) ----------
    ta = bytearray()
    for ln in range(130):
        if ln < D + KEF_ROW * 12:
            ta += bytes((0x20, 0x20))
        else:
            ta += bytes((0x20, 0x28))
    open(f'{out}/ktabA.bin', 'wb').write(ta)
    # ---------- band table: kefrens lines with rolling CSS bands (period 64 lines) ----------
    tb = bytearray()
    pat = [0]*6 + [1]*2 + [0]*2 + [1]*6 + [0]*2 + [1]*2 + [0]*4 + [1]*8 + [0]*3 + [1]*1 + [0]*3 + [1]*1 + [0]*24
    for ln in range(64 * 6):
        c = pat[ln % len(pat)]
        tb += bytes((0x20, 0x38 if c else 0x28))
    open(f'{out}/kband.bin', 'wb').write(tb)

    # ---------- synthwave picture (mode 1, CSS1: buff cyan magenta orange) ----------
    H, W = 64, 128
    img = np.zeros((H, W, 3))
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    horizon = 38
    sky = yy < horizon
    t = yy / horizon
    c_top = np.array((255, 28, 255)); c_mid = np.array((255, 129, 0)); c_low = np.array((255, 255, 255))
    for k in range(3):
        img[..., k] = np.where(t < 0.55, c_top[k] * (1 - t / 0.55) + c_mid[k] * (t / 0.55),
                               c_mid[k] * (1 - (t - 0.55) / 0.45) + c_low[k] * ((t - 0.55) / 0.45))
    # sun
    r = np.sqrt(((xx - 64) / 1.0) ** 2 + ((yy - 30) * 1.5) ** 2)
    sun = (r < 22) & sky
    stripes = (yy > 24) & ((yy.astype(int) % 4) < 1)
    img[sun & ~stripes] = (255, 255, 255)
    img[sun & stripes] = (255, 28, 255)
    # ground: magenta with orange perspective grid
    g = ~sky
    img[g] = (7, 227, 153)
    gy = yy - horizon
    z = 30.0 / np.maximum(gy + 1.0, 0.5)
    lines_h = (np.abs(np.sin(z * 2.2)) < 0.12 + 0.004 * gy) & g
    xw = (xx - 64) * z / 30.0
    lines_v = (np.abs(np.sin(xw * 3.0)) < 0.06 + 0.012 * gy) & g
    img[lines_h | lines_v] = (255, 28, 255)
    img[(yy.astype(int) == horizon)] = (255, 129, 0)
    q = cg2_quant(img, cset=1, dither=True)
    pic = cg2_from_index(q)
    open(f'{out}/pic.bin', 'wb').write(pic)
    cg2_preview(pic, cset=1).save(f'{out}/pic_preview.png')

    # ---------- picture tables: rolling CSS raster bars (each 300 lines), 16 phases ----------
    # bar profile in CSS terms: 1 = css1 (synthwave colours), 0 = css0 (green/yellow/blue/red)
    pt = bytearray()
    period = 96
    prof = []
    for k in range(period):
        v = 0x38
        for (pos, w) in ((0, 16), (40, 8), (64, 4), (74, 2)):
            kk = k - pos
            if 0 <= kk < w:
                edge = kk == 0 or kk == w - 1
                if not edge or k % 2 == 0:
                    v = 0x28
        prof.append(v)
    for ln in range(300 + period):
        v = prof[ln % period]
        pt += bytes((v, v))
    open(f'{out}/ptab.bin', 'wb').write(pt)

    # ---------- rubber stretch tables (mode 1 picture, holds), 8 phases x 300 lines ----------
    st = bytearray()
    for ph in range(8):
        t = bytearray()
        ln = 0
        holdsum = 0
        for ln in range(300):
            dl = ln - D
            if 0 <= dl < 192:
                # hold probability follows a moving sine -> rubbery vertical stretch
                s = 0.5 + 0.5 * np.sin(2 * np.pi * (dl / 96.0 - ph / 8.0))
                holdsum += 0.28 * s
                if holdsum >= 1.0:
                    holdsum -= 1.0
                    t += bytes((0x28, 0x38))      # hold (A/G toggle via css change? no: same mode)
                    continue
            t += bytes((0x38, 0x38))
        st += t
    # NB: hold needs an A/G toggle: rewrite holds as (0x30, 0x38): A then G
    st2 = bytearray(st)
    for k in range(0, len(st2), 2):
        if st2[k] == 0x28 and st2[k+1] == 0x38:
            st2[k] = 0x30
    open(f'{out}/stab.bin', 'wb').write(st2)

    # ---------- copper text line for section C (bottom 3 text rows) ----------
    msg = ("   RASTER INSANITY ... EVERY SCANLINE HAS ITS OWN MODE, COLOUR SET AND HOLD BIT ... "
           "  THE 6847 NEVER SAW THIS COMING ...      ")
    open(f'{out}/ctext.bin', 'wb').write(vztext(msg))
    # C tables: picture rows 0..51 (156 lines) mode1, then text rows with copper stripes
    ct = bytearray()
    for ln in range(150):
        c = 0x30 if (ln // 2) % 3 else 0x20
        ct += bytes((c, c))
    open(f'{out}/ctab.bin', 'wb').write(ct)
    print(f'p3: logo {len(logo)} pic {len(pic)} ptab {len(pt)} stab {len(st2)} ctab {len(ct)} kband {len(tb)}')

if __name__ == '__main__':
    import sys
    build(sys.argv[1])
