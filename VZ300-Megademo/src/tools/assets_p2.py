"""Part 2 assets: plasma fields (32 x 76 chars), colour LUTs, big scroller streams, speech."""
import numpy as np, os
from vzgfx import *
import speech

FIELD_ROWS = 64

def field(kind):
    y, x = np.mgrid[0:FIELD_ROWS, 0:32].astype(float)
    yy = y * 1.5                      # chars are 8x12 pixels
    if kind == 0:
        v = (np.sin(x / 5.5) + np.sin(yy / 7.0) + np.sin((x + yy) / 9.0)
             + np.sin(np.sqrt((x - 16) ** 2 + (yy - 40) ** 2) / 4.5))
    elif kind == 1:
        r = np.sqrt((x - 16) ** 2 + ((yy - 57) * 0.9) ** 2)
        a = np.arctan2(yy - 57, x - 16)
        v = np.sin(r / 3.5) * 1.5 + np.sin(a * 2 + r / 9.0)
    else:
        r1 = np.sqrt((x - 6) ** 2 + (yy - 20) ** 2)
        r2 = np.sqrt((x - 26) ** 2 + (yy - 80) ** 2)
        v = np.sin(r1 / 4.0) + np.sin(r2 / 4.5) + 0.5 * np.sin(x / 7.0 - yy / 9.0)
    v = (v - v.min()) / (v.max() - v.min())
    return (v * 255).astype(int) & 255

COV = [0x0, 0x8, 0x9, 0xB, 0xF]       # coverage 0..4 blocks
def lut(cols, black_gap=True):
    """cols: colours spread over 0..255 (cyclic). Solid centres, dithered edges."""
    out = []
    n = len(cols)
    for v in range(256):
        t = v / 256 * n
        i = int(t); f = t - i
        c = cols[i % n]
        if black_gap:
            if f < 0.12: m = 0x9          # checker
            elif f < 0.22: m = 0xB
            elif f > 0.92: m = 0x6
            elif f > 0.82: m = 0xE
            else: m = 0xF
        else:
            m = 0xF if f < 0.85 else 0x9
        out.append(0x80 | (c << 4) | m)
    return bytes(out)

def sparkle(seed, density):
    rnd = np.random.RandomState(seed)
    out = []
    for v in range(256):
        if rnd.rand() < density:
            out.append(0x80 | (rnd.randint(8) << 4) | (1 << rnd.randint(4)))
        else:
            out.append(0x80)
    return bytes(out)

def scroller(text):
    bm = text_bitmap(text, spacing=1)        # 7 x W
    bm = np.pad(bm, ((0, 1), (64, 64)))     # 8 x (W+128)
    W = bm.shape[1]
    if W % 2: bm = np.pad(bm, ((0, 0), (0, 1))); W += 1
    rowcol = [BUFF, YELLOW, ORANGE, RED]
    streams = []
    for ph in range(2):
        for r in range(4):
            s = bytearray()
            for k in range((W - 2) // 2):
                cx = 2 * k + ph
                m = 0
                if bm[2*r, cx]: m |= 8
                if bm[2*r, cx+1]: m |= 4
                if bm[2*r+1, cx]: m |= 2
                if bm[2*r+1, cx+1]: m |= 1
                s.append(0x80 | (rowcol[r] << 4) | m)
            streams.append(bytes(s))
    return streams, W

TEXT = ("   VZ300 MEGADEMO 2026 ...  THIS PLASMA IS COMPUTED LIVE AT 50 FRAMES A SECOND "
        "WHILE THE SAME Z80 PLAYS MUSIC ON EVERY SCANLINE ...  NO EXTRA HARDWARE ...  "
        "HELLO TO EVERY VZ OWNER WHO NEVER GAVE UP!   ")

def build(out):
    os.makedirs(out, exist_ok=True)
    flds = b''.join(bytes(field(k).flatten().tolist()) for k in range(3))
    open(f'{out}/fields.bin', 'wb').write(flds)
    luts = [
        lut([BLUE, MAGENTA, RED, ORANGE, YELLOW, GREEN, CYAN]),           # 0 rainbow
        lut([RED, ORANGE, YELLOW, BUFF, YELLOW, ORANGE]),                  # 1 fire
        lut([BLUE, CYAN, BUFF, CYAN, BLUE, MAGENTA]),                      # 2 ice
        lut([GREEN, YELLOW, GREEN, CYAN, BLUE, CYAN], black_gap=False),    # 3 toxic (solid)
        lut([MAGENTA, BLUE, MAGENTA, RED, ORANGE, RED], black_gap=False),  # 4 sunset (solid)
        sparkle(1, 0.25),                                                  # 5 dissolve 1
        sparkle(2, 0.08),                                                  # 6 dissolve 2
        bytes([0x80] * 256),                                               # 7 black
    ]
    open(f'{out}/luts.bin', 'wb').write(b''.join(luts))
    st, W = scroller(TEXT)
    L = len(st[0])
    open(f'{out}/scroll.bin', 'wb').write(b''.join(st))
    with open(f'{out}/p2const.inc', 'w') as f:
        f.write(f'SCR_LEN EQU {L}\nSCR_CELLS EQU {W - 66}\nFIELD_BYTES EQU {32*FIELD_ROWS}\n')
    sine = bytes(int(round(26 + 25.5 * np.sin(2 * np.pi * i / 256))) for i in range(256))
    open(f'{out}/sine64.bin', 'wb').write(sine)
    # speech screen: big text
    bits, dur = speech.make('Four colours.  No limits.', f'{out}/s2.wav', speed=118)
    open(f'{out}/bank1.bin', 'wb').write(bits)
    open(f'{out}/p2const.inc', 'a').write(f'SPEECH2_LEN EQU {len(bits)}\n')
    speech.preview_wav(bits, f'{out}/speech2_vz.wav')
    scr = np.full((32, 64), BLACK)
    for i, (txt, col, y0) in enumerate((("4 COLOURS", ORANGE, 6), ("NO LIMITS", CYAN, 18))):
        bm = text_bitmap(txt)
        x0 = (64 - bm.shape[1]) // 2
        for yy in range(7):
            for xx in range(bm.shape[1]):
                if bm[yy, xx]:
                    scr[y0 + yy, x0 + xx] = col
    open(f'{out}/sayscr.bin', 'wb').write(sg4_from_index(scr))
    # preview
    v = field(0)[:12]
    lut0 = luts[0]
    prev = bytes(lut0[x] for x in v.flatten()) + b''.join(bytes(s[:32]) for s in st[:4])
    sg4_preview(prev, rows=16).save(f'{out}/preview.png')
    print(f'p2: fields {len(flds)}  luts {8*256}  scroller {len(st)*L} ({W} cells)  speech {len(bits)} ({dur:.2f}s)')

if __name__ == '__main__':
    import sys
    build(sys.argv[1])
