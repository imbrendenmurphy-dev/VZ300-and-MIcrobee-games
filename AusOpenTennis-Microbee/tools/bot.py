"""A key-pressing 'human' (pl1) against the computer: tracks the ball across
the court. Logs every point: who won and why, and the human's hits."""
import run, sys
pp = run.boot()
S = pp.S
pp.poke(S['boot_test'], 1)
pp.poke(S['boot_opp'], int(sys.argv[2]) if len(sys.argv) > 2 else 2)
pp.run_frames(5)
pp.poke(S['autoplay'], 0)
P1 = S['pl1']
def w(a): return pp.peek(a) | pp.peek(a + 1) << 8
def wi(a): return w(a) >> 6
off = int(sys.argv[3]) if len(sys.argv) > 3 else 8
last_over = 0; pts = []; rally_max = 0
nf = int(sys.argv[1]) if len(sys.argv) > 1 else 6000
for f in range(nf):
    bx, by = wi(S['ball_x']), wi(S['ball_y'])
    px, py = wi(P1), wi(P1 + 2)
    k = set()
    st = pp.peek(S['ball_st'])
    if st >= 2 and pp.peek(S['ball_last']) != pp.peek(P1 + 37):
        tx = bx - off
        if tx < px - 3: k.add('LEFT')
        elif tx > px + 3: k.add('RIGHT')
    if st < 2 and f % 20 < 3:
        k.add('SPACE')
    pp.keys = k
    pp.run_frames(1)
    rally_max = max(rally_max, pp.peek(S['rally']))
    o = pp.peek(S['pt_over'])
    if o and not last_over:
        pts.append((pp.peek(S['pt_win']), pp.peek(S['pt_reason']), rally_max, pp.peek(P1 + 6)))
        rally_max = 0
    last_over = o
print('points', len(pts), 'human won', sum(1 for p in pts if p[0] == 1))
print(' '.join('%s%d/%d%s' % ('H' if p[0] == 1 else 'c', p[1], p[2], 'n' if p[3] else 'f') for p in pts))
pp.png('/home/claude/aot/shots/bot.png', 2)
