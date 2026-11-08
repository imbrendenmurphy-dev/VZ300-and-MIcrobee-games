# fixed-scene benchmark: the simulation's data (6000-7EFF of its bank) is
# restored before every emulated field, so every build renders the same scene
from harness import *
import collections,bisect,sys,os
b,E=boot(); G=sym('/home/claude/ast/build/sim.sym')
b.run(150); b.key('SPACE'); b.run(4); b.keys_up(); b.run(20)
blk=b.block(1)
SNAP='/home/claude/ast/out/scene%s.bin'%(os.environ.get('SC','300'))
if not os.path.exists(SNAP):
    blk[G['wave']]=5
    for j in range(G['N_ROCK']): blk[G['OBJ_ROCK']+j*G['OBJSZ']]=0
    for i in range(int(os.environ.get('SC','300'))):
        blk[G['lives']]=3; b.key('SPACE', i%6<3); b.key('RIGHT', (i//30)%4==0); b.run(1)
    open(SNAP,'wb').write(bytes(blk[0x6000:0x7F00]))
snap=open(SNAP,'rb').read(); snapl=list(snap)
def st():
    blk[0x6300:0x7200]=snapl[0x300:0x1200]; b.run(1)
for i in range(20): st()
f0=b.peekw(E['flips']); b.profile(True); t0=b.peekw(E['ticks'])
N=300
for i in range(N): st()
p=b.prof(); nf=b.peekw(E['flips'])-f0; nt=b.peekw(E['ticks'])-t0
print('fps %.2f  ticks/frame %.2f T/frame %.0f  sim %.0f art %.0f'%(nf*50/N, nt/nf, (p.sum()+L.bee_cyc_art())/nf, L.bee_cyc_sim()/nf, L.bee_cyc_art()/nf))
rk=sum(1 for j in range(G['N_ROCK']) if blk[G['OBJ_ROCK']+j*G['OBJSZ']])
print('rocks',rk,'dlist',b.block(0)[0xD1F8-0x8000],'dots',b.block(0)[0xD1F9-0x8000])
def agg(S,lo,hi):
    inv={v:k for k,v in S.items() if lo<=v<hi and '.' not in k}
    ad=sorted(inv); c=collections.Counter()
    for a in range(lo,hi):
        if p[a]:
            i=bisect.bisect_right(ad,a)-1; c[inv[ad[i]] if i>=0 else '?']+=p[a]
    return c
mixk=lambda k: k[:2] in ('pA','pB','pC','mC') or k.startswith('snd_w')
c=agg(E,0x8000,0x10000)
print('idle %.0f'%(sum(v for k,v in c.items() if mixk(k))/nf))
if '-v' in sys.argv:
  for k,v in c.most_common(40):
    if not mixk(k) and v/nf>700: print('  %-16s %6.0f'%(k,v/nf))
if '-i' in sys.argv: b.image(scale=1).save('/home/claude/ast/out/fix.png')
from harness import ttext
if '-t' in sys.argv:
    t=ttext(b)
    for r in range(16): print(r, repr(t[r*64:(r+1)*64] if isinstance(t,(bytes,str)) else t[r]))
if '-c' in sys.argv:
    import re
    # count executions of every call to the text queue (CALL = CD/C4/CC.. first byte 17/10 T)
    mem=b.block(0)
    tg={E[k] for k in ('tq_back','tq_push0','tq_push1')}
    inv=sorted((v,k) for k,v in E.items() if v>=0x8000)
    for a in range(0x8000,E['code_end']):
        op=mem[a-0x8000]
        if op in (0xCD,0xC4,0xCC,0xD4,0xDC) and (mem[a-0x8000+1]|mem[a-0x8000+2]<<8) in tg and p[a]:
            nm=[k for v,k in inv if v<=a][-1]
            print('%04x %-20s %6.1f per frame'%(a,nm,p[a]/17/nf))
if '-m' in sys.argv:
    m=b.block(0)
    for r in range(3): print(r, bytes(m[0x6000+r*64:0x6000+r*64+64]).hex())
    print('prot',bytes(m[0x5E00:0x5E30]).hex())
if '-s' in sys.argv:
    c2=agg(G,0,0x6000)
    for k,v in c2.most_common(22): print('  sim %-22s %6.0f per tick'%(k,v/nt))
if '-x' in sys.argv:
    fn=sys.argv[sys.argv.index('-x')+1]
    lo=G[fn]; subs=sorted((v,k) for k,v in G.items() if k.startswith(fn+'.') or k==fn)
    nxt=min(v for v in G.values() if v>lo and '.' not in [k for k,vv in G.items() if vv==v][0][:0]+'' and not any(k.startswith(fn) for k,vv in G.items() if vv==v)) if False else None
    tot=collections.Counter()
    for a in range(lo,lo+0x300):
        if p[a]:
            nm=[k for v,k in subs if v<=a][-1]; tot[nm]+=p[a]
    for k,v in sorted(tot.items(), key=lambda x:G[x[0]]): print('   %-24s %7.0f per frame'%(k,v/nf))
if '-n' in sys.argv:
    for k in sys.argv[sys.argv.index('-n')+1].split(','):
        print(k, 'entries/frame', p[E[k]]/nf)
if '-a' in sys.argv:
    lo=E[sys.argv[sys.argv.index('-a')+1]]
    loc={v:k for k,v in E.items() if lo<=v<lo+200}
    for a in range(lo,lo+200):
        if p[a]: print('%04x %-22s %8.1f'%(a,loc.get(a,''),p[a]/nf))
