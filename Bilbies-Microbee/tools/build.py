"""Build the native bring-up. Requires sjasmplus 1.20.3 and ZX0 on PATH."""
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
B = ROOT / 'build'


def run(*args, cwd=ROOT):
    subprocess.run(args, cwd=cwd, check=True)


def tiles():
    # Two logical pixels across and two down per 8x6 PCG cell.
    # Every possible four-pixel pattern has a precomputed glyph. This is
    # a compatibility renderer, not the final upgraded art architecture.
    colour, mono, pairs = bytearray(), bytearray(), bytearray()
    palette = (10, 11, 4, 1)
    for key in range(256):
        pixels = [(key >> s) & 3 for s in (6, 4, 2, 0)]
        common = sorted(set(pixels), key=lambda c: (-pixels.count(c), c))
        bg = 2 if 2 in common else common[-1]
        fg = next((c for c in common if c != bg), bg)
        pairs.append(palette[bg] * 16 + palette[fg])
        cr, mr = [], []
        for y in range(6):
            cb = mb = 0
            for x in range(8):
                p = pixels[(y // 3) * 2 + x // 4]
                on = p == fg if p in (fg, bg) else (x + y) % 2 == 0
                cb = cb * 2 + on
                # Sky black, yellow white, green outline-weighted checker,
                # red horizontal stripes: structure survives without colour.
                on = (p == 1 or (p == 0 and (x + y) % 2 == 0)
                      or (p == 3 and y % 3 == 1))
                mb = mb * 2 + on
            cr.append(cb)
            mr.append(mb)
        colour.extend(cr + [0] * 10)
        mono.extend(mr + [0] * 10)
    (B / 'PCG.BNK').write_bytes(colour + mono)
    (B / 'colours.bin').write_bytes(pairs)


if __name__ == '__main__':
    B.mkdir(exist_ok=True)
    # Original generator expects a sibling tools directory; load it from
    # its preserved location but point its output at this project's src/build.
    gen = (ROOT / 'original-tools/gen.py').read_text()
    gen = gen.replace("W = os.path.dirname(os.path.abspath(__file__)) + '/..'",
                      'W = ' + repr(str(ROOT)))
    # Audio driver is not ported yet. Keep song labels but omit unused streams.
    gen = gen.replace('music.emit_all(e)',
                      "e('SONG_T: db 0\\nSONG_J: db 0\\nSONG_W: db 0\\nSONG_L: db 0\\nSONG_F: db 0')")
    sys.path.insert(0, str(ROOT / 'original-tools'))
    exec(compile(gen, str(ROOT / 'original-tools/gen.py'), 'exec'),
         {'__file__': str(ROOT / 'original-tools/gen.py')})
    tiles()
    run('sjasmplus', '--nologo', '--sym=../build/bilbies.sym',
        '--lst=../build/bilbies.lst', 'main.asm', cwd=ROOT / 'src')
    run('sjasmplus', '--nologo', 'loader.asm', cwd=ROOT / 'src')
