"""Run the game in the Premium Plus model with the asset banks preloaded
(as the loader leaves them). Helpers for scripted play-tests."""
import sys
import json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import ppmodel

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / 'build'
BANKS = {8: 'GFX.BNK', 9: 'WORLD.BNK', 10: 'TITLE.BNK', 11: 'AUDIO.BNK', 12: 'WORLD2.BNK', 26: 'AUDIO2.BNK', 27: 'AUDIO3.BNK', 28: 'AUDIO4.BNK', 29: 'AUDIO5.BNK'}
for _i in range(5):
    BANKS[16 + 2 * _i] = 'REGION%d.BNK' % _i
    BANKS[17 + 2 * _i] = 'ROOMS%d.BNK' % _i


def symbols():
    sym = {}
    for line in (BUILD / 'main.lst').read_text(errors='replace').splitlines():
        pass
    return sym


def answer(pp, key='C'):
    """the boot question: C colour or M monochrome"""
    for i in range(200):
        pp.run_frames(5)
        row = ''.join(chr((pp.scr[11 * 80 + c] & 0x7F) + 0x20) for c in range(80))
        if 'WHICH MONITOR' in row:
            break
    else:
        raise RuntimeError('no monitor question')
    press(pp, [key], 6)
    pp.run_frames(4)


def boot(entry=0x0600, mono=False, ask=True):
    pp = ppmodel.PP()
    img = (BUILD / 'image.bin').read_bytes()
    for b, name in BANKS.items():
        f = BUILD / name
        if f.exists():
            d = f.read_bytes()
            pp.blocks[b][:len(d)] = d
    ppmodel.load_image(pp, img, entry)
    if ask:
        answer(pp, 'M' if mono else 'C')
    return pp


def press(pp, keys, frames):
    pp.keys = set(ppmodel.KEY[k] for k in keys)
    pp.run_frames(frames)
    pp.keys = set()


if __name__ == '__main__':
    pp = boot()
    import time
    t = time.time()
    pp.run_frames(int(sys.argv[1]) if len(sys.argv) > 1 else 60)
    print('ran in %.1fs, pc=%04X' % (time.time() - t, pp.m.pc))
    pp.save_png(ROOT / 'out' / 'model.png', 1)
