"""Part 1 assets: boot screen, glitch tables, VZ300 logo frames, FLD tables, speech."""
import numpy as np, os, random
from vzgfx import *
import speech

def build(out):
    os.makedirs(out, exist_ok=True)
    rnd = random.Random(300)

    # ---------- boot screen lines (filled at run time, 32 chars each) ----------
    lines = [
        "VIDEO TECHNOLOGY",
        "BASIC V2.0",
        "",
        "READY",
        'LOAD"VZMEGA"',
        "",
        "VZ300 MEGADEMO 2026  BOOTING",
        "SCANLINES PER FIELD  ...",
        "SRAM BANK 1 TEST     ...",
        "SD DATA STREAM       ...",
        "LINE KERNEL 228T     OK",
        "1-BIT AUDIO ENGINE   OK",
        "",
        "PREPARING TO BREAK THE LIMITS",
    ]
    scr = bytearray(vztext(' ' * 512))
    tl = bytearray()
    for ln in lines:
        tl += vztext(ln.ljust(32)[:32])
    open(f'{out}/bootlines.bin', 'wb').write(tl)

    # ---------- glitch raster tables ----------
    # each line: v1, v2  (bit5 set always)
    def entry(kind):
        if kind == 0: return (0x20, 0x20)
        if kind == 1: return (0x30, 0x30)          # orange text
        if kind == 2: return (0x28, 0x20)          # hold (A/G toggle)
        if kind == 3: return (0x28, 0x28)          # mode(1) garbage
        if kind == 4: return (0x38, 0x38)          # mode(1) css1
        if kind == 5: return (0x38, 0x30)          # hold css
    g = bytearray()
    k = 0
    while len(g) < 3200:
        kind = rnd.choice([0, 0, 0, 1, 2, 2, 3, 4, 5])
        run = rnd.choice([1, 2, 3, 4, 6, 8, 12, 20])
        for _ in range(run):
            g += bytes(entry(kind))
    open(f'{out}/glitch.bin', 'wb').write(g[:3200])

    # ---------- VZ300 logo frames (8 char rows = 16 cell rows, 64 cells) ----------
    bm = text_bitmap('VZ3OO', spacing=1)       # 7 x 30
    big = np.zeros((16, 64), dtype=int)  # 1 letter, 2 shadow
    H, W = bm.shape
    for y in range(H):
        for x in range(W):
            if bm[y, x]:
                for dy in range(2):
                    for dx in range(2):
                        yy, xx = 1 + 2*y + dy, 2 + 2*x + dx
                        if yy < 16 and xx < 64:
                            big[yy, xx] = 1
    # shadow
    sh = np.zeros_like(big)
    sh[1:, 1:] = big[:-1, :-1]
    ramp = [RED, ORANGE, YELLOW, BUFF, CYAN, GREEN, BLUE, MAGENTA]
    frames = bytearray()
    for f in range(8):
        cells = np.full((16, 64), BLACK)
        for y in range(16):
            for x in range(64):
                if big[y, x]:
                    cells[y, x] = ramp[((y // 2) + f) % 8]
                elif sh[y, x]:
                    cells[y, x] = BLUE if ramp[((y // 2) + f) % 8] != BLUE else MAGENTA
        frames += sg4_from_index(cells) + bytes([0x80]*8)
    open(f'{out}/logo.bin', 'wb').write(frames)
    sg4_preview(frames[:256], rows=8).save(f'{out}/logo_preview.png')

    # ---------- FLD table: holds then normal ----------
    MAXP = 200
    fld = bytearray()
    for i in range(MAXP):
        fld += bytes((0x28, 0x20))
    for i in range(320):
        fld += bytes((0x20, 0x20))
    open(f'{out}/fld.bin', 'wb').write(fld)

    # ---------- jelly tables: 8 phases, logo rows 4..11 wobble ----------
    # table covers display lines from row 0: rows 0-3 normal (48 lines), rows 4..11
    # each row gets extra hold lines inserted at its first line; total extra <= 24
    jel = bytearray()
    for ph in range(8):
        t = bytearray((0x20, 0x20)) * 2   # segment switch is at line D-2
        for r in range(16):
            if 2 <= r <= 9:
                extra = int(round(1.0 + 1.0 * np.sin(2 * np.pi * (ph / 8.0 + (r - 2) / 8.0))))
            else:
                extra = 0
            for _ in range(extra):
                t += bytes((0x28, 0x20))
            for l in range(12):
                v = 0x20
                if r >= 11:        # subtitle text rows: orange/green stripes
                    v = 0x30 if ((l + ph) // 2) % 2 else 0x20
                t += bytes((v, v))
        t = t[:2*230]
        t += bytes((0x20, 0x20)) * (240 - len(t)//2)
        jel += t
    jel += bytes((0x20, 0x20)) * 64
    open(f'{out}/jelly.bin', 'wb').write(jel)

    # ---------- logo entrance trajectory: rise from below, damped spring around 24 ----------
    traj = bytearray()
    p, v = 200.0, -4.0
    for i in range(200):
        v -= 0.55            # 'gravity' pulls the logo up to its resting place
        p += v
        if p < 0:
            p = -p * 0.3
            v = -v * 0.55
            if abs(v) < 1.0:
                break
        traj.append(max(0, min(200, int(round(p)))))
    traj.append(0); traj.append(0xFF)
    open(f'{out}/traj.bin', 'wb').write(traj)

    # ---------- subtitle text ----------
    sub = vztext("     VZ300 MEGADEMO  2026     ".ljust(32)) + vztext(" " * 32) + vztext("        ViBED  BY  BPM".ljust(32))
    sub = bytearray(sub)
    # make "ViBED" have lowercase i -> use inverse 'I'? keep plain
    open(f'{out}/sub.bin', 'wb').write(sub)

    # ---------- speech ----------
    bits, dur = speech.make('V Z three hundred!', f'{out}/s1.wav')
    open(f'{out}/speech1.bin', 'wb').write(bits)
    speech.preview_wav(bits, f'{out}/speech1_vz.wav')
    print(f'p1: logo {len(frames)}  glitch {len(g)}  fld {len(fld)}  jelly {len(jel)}  speech {len(bits)} ({dur:.2f}s)')

if __name__ == '__main__':
    import sys
    build(sys.argv[1])
