"""Clear stages by poking memory: checks stage clear -> next stage, and
takes a picture of stages 1-3 (new wildlife), plus mono."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, BUILD
out = BUILD / 'shots'
out.mkdir(exist_ok=True)
mono = '--mono' in sys.argv
pp = boot(test=True, mono=mono)
pp.run_frames(80)
S = pp.S


def poke(n, v, off=0):
    pp.poke(S[n] + off, v)


for st in range(4):
    pp.run_frames(140)
    pp.png(out / ('stage%d%s.png' % (st + 1, '_mono' if mono else '')), aspect=1.1, mono=mono)
    # every enemy gone, the exit uncovered, Wally on it
    for i in range(8):
        poke('actors', 0, i * 16)
    poke('nenemy', 1)
    for i in range(8):
        pass
    imap = S['imap']
    ex = None
    for idx in range(416):
        v = pp.peek(imap + idx)
        if v & 0x7F == 5:
            ex = idx
    ty, tx = divmod(ex, 32)
    pp.poke(S['amap'] + ex, 0)
    pp.poke(imap + ex, 5)
    poke('allclear', 1)
    poke('said_log', 1)
    poke('p_hx', tx * 8)
    poke('p_hy', ty * 8)
    pp.run_frames(10)
    print('stage', peek(pp, 'stage'), 'gstate', peek(pp, 'gstate'), 'exit at', tx, ty)
    pp.png(out / ('clear%d.png' % (st + 1)), aspect=1.1, mono=mono)
    pp.run_frames(200)
print('now stage', peek(pp, 'stage'), 'score', ''.join('%02X' % b for b in peek(pp, 'score', 3)))
