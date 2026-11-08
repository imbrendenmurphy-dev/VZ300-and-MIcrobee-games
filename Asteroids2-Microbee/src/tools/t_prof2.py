from harness import *
LOCALS=('paint_rect.','text_redraw.','tq_')
import bisect, collections, sys
b,E=boot()
b.run(100); b.key('SPACE'); b.run(4); b.keys_up(); b.run(60)
G=sym('/home/claude/ast/build/sim.sym')
b.profile(True); f0=b.peekw(E['flips'])
for i in range(300):
    b.key('RIGHT', (i//25)%5==0); b.key('SPACE', i%8<3)
    b.run(1)
nf=b.peekw(E['flips'])-f0
p=b.prof(); tot=p.sum()
print('frames',nf,'T per frame %.0f'%(tot/nf))
def agg(S,lo,hi):
    inv={v:k for k,v in S.items() if lo<=v<hi and ('.' not in k or k.startswith(LOCALS))}
    ad=sorted(inv); c=collections.Counter()
    for a in range(lo,hi):
        if p[a]:
            i=bisect.bisect_right(ad,a)-1; c[inv[ad[i]] if i>=0 else '?']+=p[a]
    return c
c=agg(E,0x8000,0x10000)
mix=sum(v for k,v in c.items() if k[:2] in ('pA','pB','pC','mC') or k.startswith('snd_w'))
print('idle/mixer per frame %.0f'%(mix/nf))
print('sim per frame %.0f  art per frame %.0f'%(L.bee_cyc_sim()/nf, L.bee_cyc_art()/nf))
for k,v in c.most_common(30):
    if k[:2] in ('pA','pB','pC','mC') or k.startswith('snd_w'): continue
    print('%-18s %7.0f'%(k,v/nf))
print('--- sim (lower) by symbol, per frame (block-1 only approx)')
c2=agg(G,0,0x6000)
for k,v in c2.most_common(25): print('%-22s %7.0f'%(k,v/nf))
