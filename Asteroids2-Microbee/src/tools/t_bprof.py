from harness import *
import collections,bisect,sys
b,E=boot(); G=sym('/home/claude/ast/build/sim.sym')
b.run(150); b.key('SPACE'); b.run(4); b.keys_up(); b.run(20)
blk=b.block(1)
blk[G['wave']]=5
for j in range(G['N_ROCK']): blk[G['OBJ_ROCK']+j*G['OBJSZ']]=0
def step(i):
    blk[G['lives']]=3
    b.key('RIGHT', (i//30)%4==0); b.key('UP', (i//45)%5==0); b.key('SPACE', i%6<3); b.key('B', i%1500==700)
    b.run(1)
for i in range(200): step(i)
f0=b.peekw(E['flips']); b.profile(True); t0=b.peekw(E['ticks'])
for i in range(200,1000): step(i)
p=b.prof(); nf=b.peekw(E['flips'])-f0; nt=b.peekw(E['ticks'])-t0
print('fps %.1f  ticks/frame %.2f T/frame %.0f  sim %.0f art %.0f'%(nf/16, nt/nf, p.sum()/nf, L.bee_cyc_sim()/nf, L.bee_cyc_art()/nf))
def agg(S,lo,hi):
    inv={v:k for k,v in S.items() if lo<=v<hi and '.' not in k}
    ad=sorted(inv); c=collections.Counter()
    for a in range(lo,hi):
        if p[a]:
            i=bisect.bisect_right(ad,a)-1; c[inv[ad[i]] if i>=0 else '?']+=p[a]
    return c
mixk=lambda k: k[:2] in ('pA','pB','pC','mC') or k.startswith('snd_w')
c=agg(E,0x8000,0x10000)
print('vb_poll calls/frame %.0f'%(p[E['vb_poll']]/11/nf))
print('idle %.0f'%(sum(v for k,v in c.items() if mixk(k))/nf))
for k,v in c.most_common(40):
    if not mixk(k) and v/nf>700: print('  %-16s %6.0f'%(k,v/nf))
c2=agg(G,0,0x6000)
for k,v in c2.most_common(14): print('  sim %-20s %6.0f  per tick %6.0f'%(k,v/nf,v/nt))
if len(sys.argv)>1:
    lo=E[sys.argv[1]]; hi=lo+int(sys.argv[2])
    loc={v:k for k,v in E.items() if lo<=v<hi}
    for a in range(lo,hi):
        if p[a]: print('%04x %-22s %8.0f'%(a,loc.get(a,''),p[a]/nf))
