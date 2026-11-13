from harness import *
import collections,bisect,sys
b,E=boot(); G=sym('/home/claude/ast/build/sim.sym')
b.run(150); b.key('SPACE'); b.run(4); b.keys_up(); b.run(20)
blk=b.block(1)
def step(i):
    blk[G['lives']]=3
    b.key('RIGHT', (i//30)%4==0); b.key('UP', (i//45)%5==0); b.key('SPACE', i%6<3); b.key('B', i%1500==700)
    b.run(1)
for i in range(2300): step(i)
f0=b.peekw(E['flips']); b.profile(True)
for i in range(2300,2900): step(i)
p=b.prof(); nf=b.peekw(E['flips'])-f0
print('fps %.1f  T/frame %.0f  sim %.0f art %.0f'%(nf/12, p.sum()/nf, L.bee_cyc_sim()/nf, L.bee_cyc_art()/nf))
def agg(S,lo,hi):
    inv={v:k for k,v in S.items() if lo<=v<hi and '.' not in k}
    ad=sorted(inv); c=collections.Counter()
    for a in range(lo,hi):
        if p[a]:
            i=bisect.bisect_right(ad,a)-1; c[inv[ad[i]] if i>=0 else '?']+=p[a]
    return c
mixk=lambda k: k[:2] in ('pA','pB','pC','mC') or k.startswith('snd_w')
c=agg(E,0x8000,0x10000)
print('vbpoll calls %.0f sim %.0f'%(p[E['vb_poll']]/11/nf, p[E['vb_poll_sim']]/max(1,1)/nf)); print('idle %.0f'%(sum(v for k,v in c.items() if mixk(k))/nf))
for k,v in c.most_common(40):
    if not mixk(k) and v/nf>800: print('  %-16s %6.0f'%(k,v/nf))
print('rocks',sum(1 for j in range(G['N_ROCK']) if blk[G['OBJ_ROCK']+j*G['OBJSZ']]), 'wave',blk[G['wave']])
c2=agg(G,0,0x6000)
for k,v in c2.most_common(12): print('  sim %-16s %6.0f'%(k,v/nf))
