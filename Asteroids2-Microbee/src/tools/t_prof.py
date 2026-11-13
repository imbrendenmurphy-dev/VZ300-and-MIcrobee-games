from harness import *
import bisect, collections
b,E=boot()
b.run(100); b.key('SPACE'); b.run(4); b.keys_up(); b.run(100)
G=sym('/home/claude/ast/build/sim.sym')
b.profile(True)
for i in range(500):
    b.key('RIGHT', (i//25)%5==0); b.key('UP', (i//40)%4==0); b.key('SPACE', i%8<3)
    b.run(1)
p=b.prof(); tot=p.sum()
def agg(S,lo,hi):
    inv={v:k for k,v in S.items() if lo<=v<hi and '.' not in k}
    ad=sorted(inv); c=collections.Counter()
    for a in range(lo,hi):
        if p[a]:
            i=bisect.bisect_right(ad,a)-1; c[inv[ad[i]] if i>=0 else '?']+=p[a]
    return c
c=agg(E,0x8000,0x10000)
low=p[:0x8000].sum()
print('lower 32K (sim + compiled art) %.1f%%'%(100*low/tot))
for k,v in c.most_common(22): print('%-20s %5.1f%%'%(k,100*v/tot))
c2=agg(G,0,0x6000)
print('-- lower by sim symbol (art code also lands here)')
for k,v in c2.most_common(15): print('%-20s %5.1f%%'%(k,100*v/tot))
