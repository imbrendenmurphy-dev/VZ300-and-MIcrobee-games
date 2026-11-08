import run, sys
from shoot import press
from flow import boot_disk
pp = boot_disk()
S = pp.S
pp.run_frames(80)
press(pp, 'C')
pp.run_frames(60)
pp.poke(S['autoplay'], 1)
press(pp, 'SPACE')       # title -> menu
pp.run_frames(60)
press(pp, 'SPACE')       # new tour
last = None
shots = 0
for t in range(int(sys.argv[1]) if len(sys.argv) > 1 else 300):
    pp.run_frames(100)
    st = (pp.peek(S['mode']), pp.peek(S['tourn']), pp.peek(S['round']), pp.peek(S['tour_saved']))
    if st != last:
        print(pp.frames, 'mode/tourn/round/saved', st, 'pts', [pp.peek(S['tourpts'] + i) for i in range(3)], 'pc %04X' % pp.cpu.pc)
        last = st
        pp.png('/home/claude/aot/shots/tour_%02d.png' % shots, 2)
        shots += 1
    if pp.peek(S['mode']) != 4 and pp.peek(S['match_over']) == 0 and t % 2 == 0:
        pass
    press(pp, 'SPACE', 2)
    if not (0x8000 <= pp.cpu.pc < 0xD400 or pp.cpu.pc < 0x2000):
        print('PC out of range', hex(pp.cpu.pc)); break
open('/home/claude/aot/build/tourdisk.ds8', 'wb').write(pp.disk())
