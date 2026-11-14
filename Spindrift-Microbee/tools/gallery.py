"""The screenshot gallery for BLURB.md, taken from the real build in the
Premium Plus model: every sector in action, every Guardian, the Chance
Stage, a warp and the amber monitor (screenshots/gameplay/), and the
front-end screens (screenshots/info/).

    python3 tools/gallery.py
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run
import jump
import fronttest
from showcase import fly, busiest

ROOT = Path(__file__).resolve().parent.parent
SECTORS = ['oort_drift', 'comet_lanes', 'ring_works', 'cinder_gate',
           'gas_giant', 'iron_belt', 'corona', 'the_eye']
PH_CLEAR, PH_BONUS = 2, 7


def wait_text(pp, needle, tries=600):
    for _ in range(tries):
        pp.run_frames(10)
        if needle in fronttest.screen_text(pp):
            return True
    return False


def main():
    g = ROOT / 'screenshots' / 'gameplay'
    i = ROOT / 'screenshots' / 'info'
    g.mkdir(parents=True, exist_ok=True)
    i.mkdir(parents=True, exist_ok=True)

    # ---- the front end
    pp = run.boot()
    pp.run_frames(60)
    run.shot(pp, i / 'info_01_monitor.png')
    run.press(pp, ['C'])
    pp.run_frames(40)
    run.shot(pp, i / 'info_02_screen_shape.png')
    run.press(pp, ['SPACE'])
    pp.run_frames(200)
    run.shot(pp, i / 'info_03_title.png')
    if wait_text(pp, 'HALL OF FAME'):
        pp.run_frames(150)
        run.shot(pp, i / 'info_04_hall_of_fame.png')
    if wait_text(pp, 'HOW TO PLAY'):
        pp.run_frames(260)
        run.shot(pp, i / 'info_05_how_to_play.png')

    # ---- every sector, its busiest moment in wave 2
    for s, name in enumerate(SECTORS):
        pp = jump.to_sector(s, 1)
        busiest(pp, 900, g / ('game_%02d_%s.png' % (s + 1, name)))
        print('sector', s + 1)

    # ---- the four Guardians
    n = 9
    for s in (1, 3, 5, 7):
        pp = jump.to_boss(s)
        busiest(pp, 700, g / ('game_%02d_guardian_%s.png' % (n, SECTORS[s])))
        n += 1
        print('guardian', s + 1)

    # ---- the Chance Stage: the last Guardian finished off
    S = pp.S
    pp.poke(S['core_hp'], 1)
    for _ in range(3000):
        fly(pp, 1)
        if run.var(pp, 'phase') == PH_BONUS:
            break
    busiest(pp, 500, g / ('game_%02d_chance_stage.png' % n))
    n += 1

    # ---- a warp: the first wave cleared, "n WARPS TO ..."
    pp = jump.to_sector(0, 0)
    for _ in range(6000):
        fly(pp, 1)
        if run.var(pp, 'phase') == PH_CLEAR:
            break
    fly(pp, 12)
    run.shot(pp, g / ('game_%02d_warp.png' % n))
    n += 1

    # ---- the amber monitor
    pp = jump.to_sector(2, 1, mono=True)
    busiest(pp, 700, g / ('game_%02d_amber_monitor.png' % n), mono=True)
    print('saved to', g, 'and', i)


if __name__ == '__main__':
    main()
