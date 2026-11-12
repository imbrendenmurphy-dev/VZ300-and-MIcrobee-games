"""Pictures for the README, taken from the real build in the Premium Plus
model: the title, how to play, sectors in action, a Guardian, the Chance
Stage, the monochrome mode, and a short GIF of play.

    python3 tools/showcase.py [outdir]     (default: screenshots/)
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from PIL import Image
import run
import jump
import playtest
import fronttest

ROOT = Path(__file__).resolve().parent.parent


def fly(pp, frames, god=True, every=None, cb=None):
    S = pp.S
    for f in range(frames):
        if f % 2 == 0:
            pp.keys = playtest.pilot(pp, f)
        if god:
            pp.poke(S['p_inv'], 40)
        pp.run_frames(1)
        if cb and every and f % every == 0:
            cb(f)


def busiest(pp, frames, path, mono=False):
    """fly, and keep the picture with the most sprite cells"""
    best = [-1]

    def cb(f):
        n = run.var(pp, 'lcount')
        if n > best[0] and run.var(pp, 'phase') in (1, 4, 7) and run.var(pp, 'flashcnt') == 0:
            best[0] = n
            run.shot(pp, path, mono=mono)
    fly(pp, frames, every=5, cb=cb)


def main(out):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    pp = run.to_title()
    pp.run_frames(120)
    run.shot(pp, out / '01_title.png')
    for _ in range(400):
        pp.run_frames(10)
        if 'HOW TO PLAY' in fronttest.screen_text(pp):
            break
    pp.run_frames(260)
    run.shot(pp, out / '02_how_to_play.png')

    names = {0: '03_oort_drift', 3: '04_cinder_gate', 5: '05_iron_belt', 7: '06_the_eye'}
    for s, n in names.items():
        pp = jump.to_sector(s, 1)
        busiest(pp, 900, out / (n + '.png'))
    pp = jump.to_boss(3)
    busiest(pp, 700, out / '07_guardian.png')
    # the Chance Stage: finish the Guardian off
    S = pp.S
    pp.poke(S['core_hp'], 1)
    for _ in range(3000):
        fly(pp, 1)
        if run.var(pp, 'phase') == 7:
            break
    busiest(pp, 500, out / '08_chance_stage.png')
    pp = jump.to_sector(2, 1, mono=True)
    busiest(pp, 700, out / '09_amber_ring_works.png', mono=True)

    # a GIF: the swarm spiralling out in the first sector
    pp = jump.to_sector(0, 0)
    fly(pp, 40)
    frames = []
    for f in range(240):
        if f % 2 == 0:
            pp.keys = playtest.pilot(pp, f)
        pp.poke(pp.S['p_inv'], 40)
        pp.run_frames(2)                     # one game frame (25 a second)
        im = run.view(pp)
        frames.append(im.resize((im.width // 2, int(im.height * 0.8)), Image.NEAREST).convert('P', palette=Image.ADAPTIVE, colors=16))
    frames[0].save(out / 'spindrift.gif', save_all=True, append_images=frames[1:], duration=40, loop=0, optimize=True)
    print('saved to', out)


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else ROOT / 'screenshots')
