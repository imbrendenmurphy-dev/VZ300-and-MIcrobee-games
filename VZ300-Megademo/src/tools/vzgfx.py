"""VZ300 graphics helpers: palette, SG4 (mode 0 semigraphics) and CG2 (mode 1) encoders,
text conversion, 5x7 pixel font."""
import numpy as np
from PIL import Image

# 6847 colours (index 0..7 = green yellow blue red buff cyan magenta orange), 8 = black
PAL = np.array([
    (0x07, 0xFF, 0x00), (0xFF, 0xFF, 0x00), (0x3B, 0x08, 0xFF), (0xCC, 0x00, 0x3B),
    (0xFF, 0xFF, 0xFF), (0x07, 0xE3, 0x99), (0xFF, 0x1C, 0xFF), (0xFF, 0x81, 0x00),
    (0, 0, 0)], dtype=float)
GREEN, YELLOW, BLUE, RED, BUFF, CYAN, MAGENTA, ORANGE, BLACK = range(9)
SET0 = [GREEN, YELLOW, BLUE, RED]
SET1 = [BUFF, CYAN, MAGENTA, ORANGE]

def vztext(s):
    """ASCII -> 6847 screen codes (normal video)."""
    out = []
    for ch in s.upper():
        c = ord(ch)
        if 64 <= c <= 95:
            out.append(c - 64)
        elif 32 <= c <= 63:
            out.append(c)
        else:
            out.append(32)
    return bytes(out)

def vztext_inv(s):
    return bytes(b | 0x40 for b in vztext(s))

# ------------------------------------------------------------------ SG4
def sg4_from_index(cells):
    """cells: int array (32 rows x 64 cols) or (2R x 2C) of palette indices 0..8 (8=black)
    -> bytes (R*C). Each char gets the most common non-black colour; other cells -> black."""
    cells = np.asarray(cells)
    H, W = cells.shape
    out = bytearray()
    for r in range(H // 2):
        for c in range(W // 2):
            q = [cells[2*r, 2*c], cells[2*r, 2*c+1], cells[2*r+1, 2*c], cells[2*r+1, 2*c+1]]
            cols = [x for x in q if x != BLACK]
            if not cols:
                out.append(0x80)
                continue
            # choose colour: most common, tie -> first
            best = max(set(cols), key=lambda x: (cols.count(x), -q.index(x)))
            m = 0
            for bit, x in zip((8, 4, 2, 1), q):
                if x == best:
                    m |= bit
            out.append(0x80 | (best << 4) | m)
    return bytes(out)

def sg4_from_rgb(img, black_thresh=40.0):
    """img: float array (2R x 2C x 3) RGB 0..255 -> best SG4 bytes (min squared error per char)."""
    img = np.asarray(img, dtype=float)
    H, W, _ = img.shape
    R, C = H // 2, W // 2
    blocks = img.reshape(R, 2, C, 2, 3).transpose(0, 2, 1, 3, 4).reshape(R, C, 4, 3)
    # cost of each cell being colour k (0..7) or black
    d = ((blocks[:, :, :, None, :] - PAL[None, None, None, :, :]) ** 2).sum(-1)  # R,C,4,9
    best_cost = None
    best_byte = np.zeros((R, C), dtype=np.uint8)
    for col in range(8):
        for m in range(16):
            bits = [(m >> 3) & 1, (m >> 2) & 1, (m >> 1) & 1, m & 1]
            cost = np.zeros((R, C))
            for i, b in enumerate(bits):
                cost += d[:, :, i, col] if b else d[:, :, i, 8]
            if best_cost is None:
                best_cost = cost.copy(); best_byte[:] = 0x80 | (col << 4) | m
            else:
                better = cost < best_cost
                best_cost = np.where(better, cost, best_cost)
                best_byte = np.where(better, 0x80 | (col << 4) | m, best_byte)
    return bytes(best_byte.flatten().tolist())

def sg4_preview(data, rows=16, scale=4):
    """render SG4/text bytes to an RGB image (for checking)."""
    data = bytes(data)
    img = np.zeros((rows * 12, 256, 3), dtype=np.uint8)
    for r in range(rows):
        for c in range(32):
            b = data[r*32 + c]
            if b & 0x80:
                col = PAL[(b >> 4) & 7]
                for i, (dy, dx) in enumerate(((0, 0), (0, 4), (6, 0), (6, 4))):
                    if b & (8 >> i):
                        img[r*12+dy:r*12+dy+6, c*8+dx:c*8+dx+4] = col
            else:
                img[r*12:r*12+12, c*8:c*8+8] = (0, 58, 0)
    return Image.fromarray(img).resize((256 * scale // 2, rows * 12 * scale // 2), Image.NEAREST)

# ------------------------------------------------------------------ CG2 (mode 1)
BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0

def cg2_from_index(px):
    """px: int array (rows x 128) of values 0..3 -> bytes."""
    px = np.asarray(px, dtype=np.uint8)
    H, W = px.shape
    out = bytearray()
    for y in range(H):
        for x in range(0, W, 4):
            out.append((px[y, x] << 6) | (px[y, x+1] << 4) | (px[y, x+2] << 2) | px[y, x+3])
    return bytes(out)

def cg2_quant(img, cset=0, dither=True, pal_idx=None):
    """img float (H x W x 3) -> index array. Ordered dither between the best pair of palette colours."""
    pal = PAL[(SET0 if cset == 0 else SET1) if pal_idx is None else pal_idx]
    img = np.asarray(img, dtype=float)
    H, W, _ = img.shape
    thr = np.tile(BAYER4, (H // 4 + 1, W // 4 + 1))[:H, :W] + 1/32
    best_err = np.full((H, W), 1e18); out = np.zeros((H, W), dtype=int)
    n = len(pal)
    for i in range(n):
        for j in range(n):
            if j < i: continue
            a, b = pal[i], pal[j]
            d = b - a
            dd = (d * d).sum()
            if dd == 0:
                t = np.zeros((H, W))
            else:
                t = np.clip(((img - a) * d).sum(-1) / dd, 0, 1)
            mix = a + t[..., None] * d
            err = ((img - mix) ** 2).sum(-1)
            if not dither:
                t = np.round(t)
            pick = np.where(t > thr, j, i)
            better = err < best_err - 1e-6
            best_err = np.where(better, err, best_err)
            out = np.where(better, pick, out)
    return out

def cg2_preview(data, cset=0, rows=64, scale=4):
    data = bytes(data)
    pal = PAL[SET0 if cset == 0 else SET1].astype(np.uint8)
    img = np.zeros((rows * 3, 256, 3), dtype=np.uint8)
    for y in range(rows):
        for x in range(32):
            b = data[y*32 + x]
            for k in range(4):
                v = (b >> (6 - 2*k)) & 3
                img[y*3:y*3+3, x*8+k*2:x*8+k*2+2] = pal[v]
    return Image.fromarray(img).resize((256 * scale // 2, rows * 3 * scale // 2), Image.NEAREST)

# ------------------------------------------------------------------ 5x7 font
FONT5x7 = {
 'A': ["01110","10001","10001","11111","10001","10001","10001"],
 'B': ["11110","10001","10001","11110","10001","10001","11110"],
 'C': ["01110","10001","10000","10000","10000","10001","01110"],
 'D': ["11110","10001","10001","10001","10001","10001","11110"],
 'E': ["11111","10000","10000","11110","10000","10000","11111"],
 'F': ["11111","10000","10000","11110","10000","10000","10000"],
 'G': ["01110","10001","10000","10111","10001","10001","01111"],
 'H': ["10001","10001","10001","11111","10001","10001","10001"],
 'I': ["11111","00100","00100","00100","00100","00100","11111"],
 'J': ["00111","00010","00010","00010","00010","10010","01100"],
 'K': ["10001","10010","10100","11000","10100","10010","10001"],
 'L': ["10000","10000","10000","10000","10000","10000","11111"],
 'M': ["10001","11011","10101","10101","10001","10001","10001"],
 'N': ["10001","11001","10101","10011","10001","10001","10001"],
 'O': ["01110","10001","10001","10001","10001","10001","01110"],
 'P': ["11110","10001","10001","11110","10000","10000","10000"],
 'Q': ["01110","10001","10001","10001","10101","10010","01101"],
 'R': ["11110","10001","10001","11110","10100","10010","10001"],
 'S': ["01111","10000","10000","01110","00001","00001","11110"],
 'T': ["11111","00100","00100","00100","00100","00100","00100"],
 'U': ["10001","10001","10001","10001","10001","10001","01110"],
 'V': ["10001","10001","10001","10001","10001","01010","00100"],
 'W': ["10001","10001","10001","10101","10101","10101","01010"],
 'X': ["10001","10001","01010","00100","01010","10001","10001"],
 'Y': ["10001","10001","01010","00100","00100","00100","00100"],
 'Z': ["11111","00001","00010","00100","01000","10000","11111"],
 '0': ["01110","10001","10011","10101","11001","10001","01110"],
 '1': ["00100","01100","00100","00100","00100","00100","01110"],
 '2': ["01110","10001","00001","00010","00100","01000","11111"],
 '3': ["11111","00010","00100","00010","00001","10001","01110"],
 '4': ["00010","00110","01010","10010","11111","00010","00010"],
 '5': ["11111","10000","11110","00001","00001","10001","01110"],
 '6': ["00110","01000","10000","11110","10001","10001","01110"],
 '7': ["11111","00001","00010","00100","01000","01000","01000"],
 '8': ["01110","10001","10001","01110","10001","10001","01110"],
 '9': ["01110","10001","10001","01111","00001","00010","01100"],
 ' ': ["00000"] * 7,
 '.': ["00000","00000","00000","00000","00000","01100","01100"],
 ',': ["00000","00000","00000","00000","01100","00100","01000"],
 '!': ["00100","00100","00100","00100","00100","00000","00100"],
 '?': ["01110","10001","00001","00010","00100","00000","00100"],
 '-': ["00000","00000","00000","11111","00000","00000","00000"],
 ':': ["00000","01100","01100","00000","01100","01100","00000"],
 "'": ["00100","00100","01000","00000","00000","00000","00000"],
 '/': ["00001","00010","00010","00100","01000","01000","10000"],
 '&': ["01100","10010","10100","01000","10101","10010","01101"],
 '(': ["00010","00100","01000","01000","01000","00100","00010"],
 ')': ["01000","00100","00010","00010","00010","00100","01000"],
 '*': ["00000","10101","01110","11111","01110","10101","00000"],
 '+': ["00000","00100","00100","11111","00100","00100","00000"],
 '=': ["00000","00000","11111","00000","11111","00000","00000"],
 '#': ["01010","01010","11111","01010","11111","01010","01010"],
}
FONT5x7['i'] = ["00100","00000","01100","00100","00100","00100","01110"]   # lowercase i for "ViBED"

def text_bitmap(s, spacing=1):
    """return 7 x N boolean array for string using 5x7 font."""
    cols = []
    for ch in s:
        g = FONT5x7.get(ch, FONT5x7.get(ch.upper(), FONT5x7[' ']))
        w = len(g[0])
        for x in range(w):
            cols.append([g[y][x] == '1' for y in range(7)])
        for _ in range(spacing):
            cols.append([False] * 7)
    return np.array(cols, dtype=bool).T

def save_png(img, path, scale=1):
    if isinstance(img, np.ndarray):
        img = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    if scale != 1:
        img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    img.save(path)
