import sys
from prof import enter, pose
from h2 import sheet
s = enter(0, 0)
S, vz = s.S, s.vz
files = []
for i, roll in enumerate([-40, -25, -10, 10, 25, 40]):
    pose(s, -3000, 0, 280, 120)
    a = S['roll3']; v = int(roll * 65536 / 360) & 0xFFFF
    vz.m[a] = 0; vz.m[a + 1] = v & 255; vz.m[a + 2] = v >> 8
    vz.press(',' if roll > 0 else 'M')   # hold the bank so it doesn't level
    vz.step(); vz.run_until(S['flyloop'], 60_000_000)
    vz.step(); vz.run_until(S['flyloop'], 60_000_000)
    vz.release_all()
    f = '/tmp/claude-0/-home-claude/03b9a513-f60c-5621-9637-06087f6cc672/scratchpad/bank%d.png' % i
    s.shot(f); files.append(f)
    print(roll, s.state()['rol'])
sheet(files, '/tmp/claude-0/-home-claude/03b9a513-f60c-5621-9637-06087f6cc672/scratchpad/bank.png', 3)
