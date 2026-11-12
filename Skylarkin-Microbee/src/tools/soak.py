"""Random play for every pilot; fails if the program leaves its code or
the stack goes wild. Usage: soak.py [fields per pilot]"""
import sys, random
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, peekw, to_game
from autoplay import step
N = int(sys.argv[1]) if len(sys.argv) > 1 else 6000
KEYS = ['UP', 'DOWN', 'LEFT', 'RIGHT', 'SPACE', 'X']
ok = True
for pilot in range(4):
    rnd = random.Random(pilot)
    pp = boot(); to_game(pp, pilot=pilot); S = pp.S
    end = S['spr_tab']
    for t in range(N // 4):
        if t % 3:
            step(pp, 4, ['X'] if rnd.random() < 0.1 else ())
        else:
            pp.keys = [k for k in KEYS if rnd.random() < 0.3]
            pp.run_frames(4)
        if t % 200 == 100:      # keep it powered up and alive
            for k, v in dict(pmissile=1, poptions=rnd.randrange(3), pdouble=rnd.randrange(2), pspeed=rnd.randrange(4)).items():
                pp.poke(S[k], v)
            pp.poke(S['lives'], 3)
        pc, sp = pp.cpu.pc, pp.cpu.sp
        if not (0x8000 <= pc < end) or not (0xD000 <= sp <= 0xEFFE or pc < S['cell_alloc']):
            print('pilot', pilot, 'FAIL at field', t * 4, hex(pc), hex(sp)); ok = False; break
    print('pilot', pilot, 'scroll', peekw(pp, 'scrollx'), 'gstate', peek(pp, 'gstate'), 'stage', peek(pp, 'stage'), 'boss_hp', peekw(pp, 'boss_hp'))
print('OK' if ok else 'FAILED')
