import run, sys, random
from shoot import press
from flow import boot_disk
for attempt in range(6):
    pp = boot_disk()
    S = pp.S
    pp.run_frames(80)
    press(pp, 'C')
    pp.run_frames(60)
    pp.poke(S['autoplay'], 1)
    pp.poke(S['tour_saved'], 1); pp.poke(S['tour_t'], 3); pp.poke(S['tour_r'], 2)
    pp.poke(S['seed'], random.randrange(256)); pp.poke(S['seed'] + 1, random.randrange(256))
    press(pp, 'SPACE'); pp.run_frames(60)
    press(pp, 'DOWN'); pp.run_frames(10)
    press(pp, 'SPACE')
    won = False
    for t in range(400):
        pp.run_frames(100)
        if pp.peek(S['tourn']) == 4:
            won = True
            pp.run_frames(150)
            pp.png('/home/claude/aot/shots/slam.png', 2)
            print('GRAND SLAM reached, frame', pp.frames)
            break
        if pp.peek(S['mode']) == 0 and t > 5:
            print('lost the final (attempt %d)' % attempt)
            break
        press(pp, 'SPACE', 2)
    if won:
        break
