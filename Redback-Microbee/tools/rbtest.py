"""REDBACK in the Premium Plus model: boot, run, screenshots, checks"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
from mbee import Mbee, FRAME_T
import run

ROOT = Path(__file__).resolve().parent.parent
B = ROOT / 'build'


def boot(binname='REDBACK.BIN', sym='redback.sym'):
    pp = Mbee()
    def put(b, data, off=0):
        pp.blocks[b][off:off + len(data)] = np.frombuffer(data, np.uint8)
    put(8, (B / 'PAIRS.BNK').read_bytes())
    put(12, (B / 'DECK.BNK').read_bytes())
    import sprites
    i = 0
    while (B / ('SPR%d.BNK' % i)).exists():
        put(sprites.SPR_BLOCKS[i], (B / ('SPR%d.BNK' % i)).read_bytes())
        i += 1
    put(0, (B / binname).read_bytes())
    pp.out(0x50, run.blk_port(8) | 8)
    pp.cpu.pc = 0x8000
    pp.cpu.sp = 0xEFF0
    pp.S = run.symbols(B / sym)
    return pp


def shot(pp, path, scale=2):
    from PIL import Image
    img = pp.screen_rgb()
    im = Image.fromarray(img)
    im = im.resize((im.width * scale, int(im.height * scale * 1.5)), Image.NEAREST)
    im.save(path)


if __name__ == '__main__':
    pp = boot()
    pp.run_frames(5)
    print('pc %04X' % pp.cpu.pc, 'start', pp.start_addr(), 'crtc', [int(x) for x in pp.crtc[:16]])
    pp.run_frames(60)
    print('pc %04X' % pp.cpu.pc, 'start', pp.start_addr())
    shot(pp, '/tmp/claude-0/rb0.png')
