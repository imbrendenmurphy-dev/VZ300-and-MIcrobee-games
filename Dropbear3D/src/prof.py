"""Profile one area: run the bot to frame N, then time each routine over the next M frames."""
import sys, pickle
exec(open('play.py').read().split("frames = []; shots = {}")[0])
watch = {S[n]: n for n in ('gloop', 'wf1', 'wf2', 'tt2')}
names = ['render', 'objects', 'drawvis', 'parts', 'drawgun', 'blit', 'hud', 'timers', 'turnmove', 'projq', 'proj', 'ai', 'drawspr', 'pick', 'castray', 'texsrc', 'smul', 'div168', 'mktabs', 'typeptr', 'abshl', 'poll']
addr = {S[n]: n for n in names}
acc = {n: 0 for n in names}; cnt = {n: 0 for n in names}
N0 = int(sys.argv[1]); N1 = N0+int(sys.argv[2]); nframe = 0; titles = 0; stack = []; t0 = None
while nframe < N1:
    n = watch.get(z.pc)
    if n == 'tt2': titles += 1; press(' ' if titles > 3 else '')
    elif n == 'wf1': press('')
    elif n == 'wf2': press(' ')
    elif n == 'gloop':
        nframe += 1
        if nframe == N0: t0 = z.t
        press(bot(nframe))
    pc = z.pc; op = z.m[pc]
    if nframe >= N0 and op == 0xCD:
        tgt = z.m[pc+1] | z.m[pc+2] << 8; sp0 = z.sp; z.step()
        if tgt in addr: stack.append((addr[tgt], z.t, z.sp))
        continue
    z.step()
    while stack and z.sp > stack[-1][2]:
        nm, ts, _ = stack.pop(); acc[nm] += z.t-ts; cnt[nm] += 1
fr = N1-N0; tot = z.t-t0
print('area', NAMES[rd(S['area'])], 'avg frame %d T = %.1f fps' % (tot/fr, 3546900*fr/tot))
for nm in names: print('  %-9s %7d T/frame  (%d calls/frame)' % (nm, acc[nm]/fr, cnt[nm]/fr))
