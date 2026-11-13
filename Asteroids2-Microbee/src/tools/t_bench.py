from harness import *
import sys
b,E=boot(); G=sym('/home/claude/ast/build/sim.sym')
import os
b.run(150+int(os.environ.get('D','0'))); b.key('SPACE'); b.run(4); b.keys_up(); b.run(20)
blk=b.block(1)
W=int(sys.argv[1]) if len(sys.argv)>1 else 5
def bump():
    blk[G['wave']]=W
    for j in range(G['N_ROCK']): blk[G['OBJ_ROCK']+j*G['OBJSZ']]=0
bump()
f0=b.peekw(E['flips']); fps=[]; ff=b.peekw(E['flips'])
for i in range(4000):
    blk[G['lives']]=3
    if blk[G['wave']]>W+1: bump()
    b.key('RIGHT', (i//30)%4==0); b.key('UP', (i//45)%5==0); b.key('SPACE', i%6<3); b.key('B', i%1500==700)
    b.run(1)
    if i%100==99:
        f1=b.peekw(E['flips']); fps.append((f1-f0)/2); f0=f1
print(' '.join('%g'%f for f in fps))
print('min %.1f mean %.2f  frames %d'%(min(fps),sum(fps)/len(fps),b.peekw(E['flips'])-ff))
