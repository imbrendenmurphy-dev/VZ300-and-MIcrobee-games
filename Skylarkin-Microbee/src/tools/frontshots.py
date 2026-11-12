"""The front end: monitor choice, title, hall of fame, how to play, the
demo, pilot select -> build/shots/front.png"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, peekw, tap, BUILD
from PIL import Image
mono = '--mono' in sys.argv
pp = boot(); S = pp.S
ims = []
def shot(tag):
    ims.append(pp.png('/tmp/claude-0/f.png', scale=1, aspect=1.2, mono=mono).copy())
    print(tag, 'pc %04X demo %d stage %d gstate %d' % (pp.cpu.pc, peek(pp, 'demo'), peek(pp, 'stage'), peek(pp, 'gstate')))
pp.run_frames(40); shot('monitor')
tap(pp, 'M' if mono else 'C'); pp.run_frames(60); shot('title')
pp.run_frames(520); shot('hof')
pp.run_frames(400); shot('howto')
pp.run_frames(700); shot('demo')
pp.run_frames(600); shot('demo2')
tap(pp, 'SPACE'); pp.run_frames(60)
tap(pp, 'SPACE'); pp.run_frames(40); shot('select')
tap(pp, 'RIGHT'); tap(pp, 'C'); pp.run_frames(10); shot('select2')
w, h = ims[0].size
o = Image.new('RGB', (w * 2, h * 4))
for i, im in enumerate(ims):
    o.paste(im, ((i % 2) * w, (i // 2) * h))
o.save(BUILD / 'shots' / ('front%s.png' % ('_mono' if mono else '')))
