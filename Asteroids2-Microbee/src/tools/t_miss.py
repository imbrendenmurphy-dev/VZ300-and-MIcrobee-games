from harness import *
import collections,bisect
b,E=boot()
b.run(100); b.key('SPACE'); b.run(4); b.keys_up(); b.run(60)
G=sym('/home/claude/ast/build/sim.sym')
def agg(p,S,lo,hi):
    inv={v:k for k,v in S.items() if lo<=v<hi and '.' not in k}
    ad=sorted(inv); c=collections.Counter()
    for a in range(lo,hi):
        if p[a]:
            i=bisect.bisect_right(ad,a)-1; c[inv[ad[i]] if i>=0 else '?']+=p[a]
    return c
f0=b.peek(E['fields'])
for i in range(320):
    b.key('RIGHT', (i//25)%5==0); b.key('SPACE', i%8<3)
    b.run_to=None
    L.bee_run_to(67500*256//312); b.profile(True); b.run(1); b.profile(False)
    f1=b.peek(E['fields']); d=(f1-f0)&255; f0=f1
    if d==0:
        p=b.prof(); print('miss at',i, agg(p,E,0x8000,0x10000).most_common(6), agg(p,G,0,0x6000).most_common(6))
