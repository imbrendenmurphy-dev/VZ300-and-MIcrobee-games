# how much of the time the in-game effects actually sound
# t_sfx.py ROOT [wave] [wavfile]
from harness import *
import sys, numpy as np
R=sys.argv[1] if len(sys.argv)>1 else '/home/claude/ast'; W=int(sys.argv[2]) if len(sys.argv)>2 else 5
b,_=boot(R+'/build/AST2.DS8'); E=sym(R+'/build/engine.sym'); G=sym(R+'/build/sim.sym')
b.run(150); b.key('SPACE'); b.run(4); b.keys_up(); b.run(80)
blk=b.block(1)
def bump():
    blk[G['wave']]=W
    for j in range(G['N_ROCK']): blk[G['OBJ_ROCK']+j*G['OBJSZ']]=0
bump(); b.run(100)
FT=67500
t0=b.cycles; act=[]; f0=b.peekw(E['flips'])
for i in range(1000):
    blk[G['lives']]=3
    if blk[G['wave']]>W+1: bump()
    b.key('RIGHT', (i//30)%4==0); b.key('UP', (i//45)%5==0); b.key('SPACE', i%6<3); b.key('B', i%300==150)
    s=b.peek(E['snd_on'])
    b.run(1); act.append(s or b.peek(E['snd_on']))
t1=b.cycles
ts,vs=b.speaker(); m=(ts>=t0)&(ts<t1); ts=ts[m]
d=np.diff(ts); snd=np.zeros(len(act))
for a,g in zip(ts[:-1],d):
    if g<2500:
        k=int((a-t0)//FT)
        if k<len(snd): snd[k]+=g
act=np.array(act,bool)
frac=snd/FT
# per 40 ms window (two fields) while an effect is active
w=(frac[0::2][:len(frac)//2]+frac[1::2][:len(frac)//2])/2; wa=act[0::2][:len(w)]|act[1::2][:len(w)]
ww=w[wa]
print('%s wave %d fps %.1f | effects active %d%% of windows; sounding %.0f%% of that time; silent 40ms windows %.0f%%; windows under 15%%: %.0f%%'%(
 R.split('/')[-1], W, (b.peekw(E['flips'])-f0)/20, 100*wa.mean(), 100*ww.mean(), 100*(ww<0.02).mean(), 100*(ww<0.15).mean()))
if len(sys.argv)>3: b.save_wav(sys.argv[3], t0=t0, t1=t1)
