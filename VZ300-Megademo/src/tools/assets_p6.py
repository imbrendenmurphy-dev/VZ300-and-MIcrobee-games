"""Part 6 (finale) assets: tunnel + plasma + rotozoom (bank 1) + kefrens for rapid cuts,
credits scroller, closing logo, speech."""
import numpy as np, os
from vzgfx import *
import speech, assets_p2 as P2, assets_p4b as P4B, assets_p5 as P5, assets_p1 as P1

from vzcfg import D

def build(out):
    os.makedirs(out, exist_ok=True)
    # tunnel 12 frames (every 2nd of the 24-frame loop)
    tun, _ = P4B.tunnel_frames()
    tun12 = b''.join(tun[i*512:(i+1)*512] for i in range(0, 24, 2))
    open(f'{out}/tunnel.bin', 'wb').write(tun12)
    # rotozoom 12 frames -> bank 1
    rz = P5.rotozoom(12)
    rzb = P5.frames_to_bytes(rz)
    # plasma: one field (32 x 64) + two LUTs (rainbow, fire)
    fld = P2.field(0)
    open(f'{out}/field.bin', 'wb').write(bytes(fld.flatten().tolist()))
    luts = P2.lut([BLUE, MAGENTA, RED, ORANGE, YELLOW, GREEN, CYAN]) + P2.lut([RED, ORANGE, YELLOW, BUFF, YELLOW, ORANGE])
    open(f'{out}/luts.bin', 'wb').write(luts)
    sine = bytes(int(round(26 + 25.5 * np.sin(2 * np.pi * i / 256))) for i in range(256))
    open(f'{out}/sine64.bin', 'wb').write(sine)
    # credits scroller
    text = ("   VZ300 - STILL BREAKING LIMITS IN 2026 ... CODE & CONCEPT: BPM / VIBED ...   ")
    st, W = P2.scroller(text)
    open(f'{out}/scroll.bin', 'wb').write(b''.join(st))
    # kefrens full-screen: sine + raster table (all display lines hold, css bands)
    i = np.arange(256)
    x = 13.5 + 10.0 * np.sin(2 * np.pi * i / 128) + 4.0 * np.sin(2 * np.pi * i / 37)
    x = np.clip(np.round(x), 0, 29).astype(int)
    open(f'{out}/ksine.bin', 'wb').write(bytes(x.tolist()))
    kt = bytearray()
    for ln in range(400):
        dl = ln - D
        if 0 <= dl < 192 or ln >= 300:
            c = 0x38 if (ln // 4) % 5 == 0 else 0x28
            kt += bytes((0x20, c))
        else:
            kt += bytes((0x28, 0x28))
    open(f'{out}/ktab.bin', 'wb').write(kt)
    # closing logo frames (reuse part 1 generator output) + credits text rows
    P1.build(f'{out}/p1tmp')
    logo = open(f'{out}/p1tmp/logo.bin', 'rb').read()
    open(f'{out}/logo.bin', 'wb').write(logo[:264*4])
    open(f'{out}/fld.bin', 'wb').write(open(f'{out}/p1tmp/fld.bin', 'rb').read())
    open(f'{out}/traj.bin', 'wb').write(open(f'{out}/p1tmp/traj.bin', 'rb').read())
    cred = (vztext("  STILL BREAKING LIMITS IN 2026 ".ljust(32)) + vztext(" " * 32) +
            vztext("   CODE & CONCEPT: BPM / VIBED  ".ljust(32)))
    open(f'{out}/credits.bin', 'wb').write(cred)
    # end table: copper stripes on the credit rows (rows 11..13), 16 phases offset trick
    et = bytearray()
    for ln in range(300 + 32):
        dl = ln - D
        v = 0x20
        if 11 * 12 <= dl < 14 * 12:
            v = 0x30 if (ln // 2) % 4 in (1, 2) else 0x20
        et += bytes((v, v))
    open(f'{out}/etab.bin', 'wb').write(et)
    bits, dur = speech.make('You thought this was impossible?', f'{out}/s3.wav', speed=120)
    assert len(rzb) + len(bits) <= 10240, (len(rzb), len(bits))
    open(f'{out}/bank1.bin', 'wb').write(rzb + bits)
    speech.preview_wav(bits, f'{out}/speech3_vz.wav')
    with open(f'{out}/p6const.inc', 'w') as f:
        f.write(f'SCR_LEN EQU {len(st[0])}\nSCR_CELLS EQU {W - 66}\nSPEECH3 EQU $4000+{len(rzb)}\nSPEECH3_LEN EQU {len(bits)}\n')
    print(f'p6: tunnel {len(tun12)} roto(bank1) {12*512} scroll {len(st)*len(st[0])} speech {len(bits)} ({dur:.2f}s)')

if __name__ == '__main__':
    import sys
    build(sys.argv[1])
