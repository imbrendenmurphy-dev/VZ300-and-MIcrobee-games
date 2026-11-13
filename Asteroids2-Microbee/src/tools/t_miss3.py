from harness import *
import collections,bisect
b,E=boot(); G=sym('/home/claude/ast/build/sim.sym')
b.run(150); b.key('SPACE'); b.run(4); b.keys_up(); b.run(20)
blk=b.block(1)
def agg(p,S,lo,hi):
    inv={v:k for k,v in S.items() if lo<=v<hi and '.' not in k}
    ad=sorted(inv); c=collections.Counter()
    for a in range(lo,hi):
        if p[a]:
            i=bisect.bisect_right(ad,a)-1; c[inv[ad[i]] if i>=0 else '?']+=p[a]
    return c
f0=b.peek(E['fields']); n=0
for i in range(3000):
    blk[G['lives']]=3
    b.key('RIGHT', (i//30)%4==0); b.key('UP', (i//45)%5==0); b.key('SPACE', i%6<3); b.key('B', i%1500==700)
    L.bee_run_to(67500*256//312); b.profile(True); b.run(1); b.profile(False)
    f1=b.peek(E['fields']); d=(f1-f0)&255; f0=f1
    if d!=1:
        n+=1
        if n<6: p=b.prof(); print(i,d, agg(p,E,0x8000,0x10000).most_common(4), agg(p,G,0,0x6000).most_common(4))
print('misses',n)
