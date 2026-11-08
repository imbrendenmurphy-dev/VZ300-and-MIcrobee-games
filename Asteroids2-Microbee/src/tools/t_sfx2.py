# per 40 ms window: how long the mixer ran while an effect was on
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
rng=[(E['snd_w1'],E['snd_apply'])]+[(E[k],E[k]+70) for k in ('snd_w3',)]
mix=[];act=[]; f0=b.peekw(E['flips'])
for i in range(800):
    blk[G['lives']]=3
    if blk[G['wave']]>W+1: bump()
    b.key('RIGHT', (i//30)%4==0); b.key('UP', (i//45)%5==0); b.key('SPACE', i%6<3); b.key('B', i%300==150)
    a=b.peek(E['snd_on']); b.profile(True); b.run(1); p=b.prof(); b.profile(False)
    mix.append(sum(p[lo:hi].sum() for lo,hi in rng)/67500); act.append(a or b.peek(E['snd_on']))
mix=np.array(mix); act=np.array(act,bool)
w=(mix[0::2]+mix[1::2])/2; wa=act[0::2]|act[1::2]; ww=w[wa]
print('%s wave %d fps %.1f | effect windows: mixer %.0f%% avg; silent(<2%%) %.0f%%; <10%%: %.0f%%'%(R.split('/')[-1],W,(b.peekw(E['flips'])-f0)/16,100*ww.mean(),100*(ww<.02).mean(),100*(ww<.10).mean()))
