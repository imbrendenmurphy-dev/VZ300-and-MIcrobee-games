# same input script on a given build: t_cmp.py ROOT [wave]
from harness import *
import sys
R=sys.argv[1]; W=int(sys.argv[2]) if len(sys.argv)>2 else 0
b,_=boot(R+'/build/AST2.DS8'); E=sym(R+'/build/engine.sym'); G=sym(R+'/build/sim.sym')
b.run(150); b.key('SPACE'); b.run(4); b.keys_up(); b.run(80)
blk=b.block(1)
def bump():
    blk[G['wave']]=W
    for j in range(G['N_ROCK']): blk[G['OBJ_ROCK']+j*G['OBJSZ']]=0
if W: bump()
f0=b.peekw(E['flips']); t0=b.peekw(E['ticks']); fps=[]
for i in range(4500):
    blk[G['lives']]=3
    if W and blk[G['wave']]>W+1: bump()
    b.key('RIGHT', (i//30)%4==0); b.key('UP', (i//45)%5==0); b.key('SPACE', i%6<3); b.key('B', i%1500==700)
    b.run(1)
    if i%100==99:
        f1=b.peekw(E['flips']); fps.append((f1-f0)/2); f0=f1
print('wave now',blk[G['wave']],'rocks',sum(1 for j in range(G['N_ROCK']) if blk[G['OBJ_ROCK']+j*G['OBJSZ']]),'demo',blk[G['demo_mode']],'score',bytes(blk[G['score']:G['score']+3]).hex())
fps.sort()
print('%-6s wave%d  mean %.1f  median %.1f  worst10%% %.1f  min %.1f  ticks/s %.2f'%(R.split('/')[-1], W, sum(fps)/len(fps), fps[len(fps)//2], sum(fps[:len(fps)//10])/(len(fps)//10), fps[0], (b.peekw(E['ticks'])-t0)/90 if False else 0))
