"""Run RUNEDEEP in the Premium Plus model with the RAM blocks filled as
the loader leaves them.

    py tools/rd.py OUTDIR "keys..."    a scripted run with screenshots
Script: tokens separated by spaces: a key name (UP, SPACE, 1, ...) is
pressed for 3 frames then released for 12; 'wN' waits N frames;
'sNAME' saves OUTDIR/NAME.png.
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
from mbee import Mbee, FRAME_T

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / 'build'
BLOCKS = {8: 'UI', 9: 'TITLE', 17: 'L1A', 18: 'L1B', 19: 'L2A', 20: 'L2B', 21: 'L3A', 22: 'L3B', 23: 'L4A', 24: 'L4B'}


def blk_port(b):
    return ((b & 0x1C) << 3) | ((b & 3) ^ 2) | 4


def symbols(path=BUILD / 'main.sym'):
    S = {}
    for line in Path(path).read_text().splitlines():
        if ': equ ' in line:
            n, v = line.split(': equ ')
            S[n.strip()] = int(v, 16)
    return S


def boot():
    pp = Mbee()
    pp.S = symbols()
    d = np.frombuffer((BUILD / 'RUNE.BIN').read_bytes(), np.uint8)
    pp.blocks[0][:len(d)] = d
    for b, n in BLOCKS.items():
        d = np.frombuffer((BUILD / (n + '.BNK')).read_bytes(), np.uint8)
        pp.blocks[b][:len(d)] = d
    pp.out(0x50, blk_port(8) | 8)
    pp.cpu.pc = 0x8000
    pp.cpu.sp = 0xEFF0
    return pp


def var(pp, name, n=1):
    a = pp.S[name]
    return pp.peek(a) if n == 1 else pp.peek(a) | (pp.peek(a + 1) << 8)


def shot(pp, path, scale=2):
    from PIL import Image
    img = pp.screen_rgb()
    im = Image.fromarray(img)
    im = im.resize((im.width * scale, int(im.height * scale * 0.75 * 1.0)), Image.NEAREST)
    im.save(path)


def script(pp, text, out):
    for tok in text.split():
        if tok.startswith('w') and tok[1:].isdigit():
            pp.run_frames(int(tok[1:]))
        elif tok.startswith('s') and len(tok) > 1 and tok[1:2].islower():
            shot(pp, Path(out) / (tok[1:] + '.png'))
        else:
            hold = 3
            if '*' in tok:
                tok, n = tok.split('*')
                hold = int(n)
            pp.keys = {tok}
            pp.run_frames(hold)
            pp.keys = set()
            pp.run_frames(12)


if __name__ == '__main__':
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    pp = boot()
    script(pp, sys.argv[2] if len(sys.argv) > 2 else 'w100 stitle', out)
    print('pc %04X  level %d  hp %d  pos %04X facing %d' % (pp.cpu.pc, var(pp, 'level'), var(pp, 'hp'),
                                                            var(pp, 'ppos', 2), var(pp, 'facing')))
