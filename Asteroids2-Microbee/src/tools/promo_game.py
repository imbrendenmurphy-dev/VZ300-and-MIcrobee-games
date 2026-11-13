from harness import *
import pickle, sys
W=int(sys.argv[1]); N=int(sys.argv[2]); out=sys.argv[3]
b,E=boot(); G=sym('/home/claude/ast/build/sim.sym')
for i in range(200):
    b.run(5)
    if 'ROCKS ARE' in ttext(b): break
b.run(60); b.key('SPACE'); b.run(4); b.keys_up(); b.run(40)
blk=b.block(1)
blk[G['wave']]=W
for j in range(G['N_ROCK']): blk[G['OBJ_ROCK']+j*G['OBJSZ']]=0
fr=[]
for i in range(N):
    blk[G['lives']]=3
    if blk[G['bombs']]==0 and i%500==0: blk[G['bombs']]=2
    b.key('RIGHT', (i//25)%5==0); b.key('LEFT', (i//25)%5==3); b.key('UP', (i//40)%4==1)
    b.key('SPACE', i%6<3); b.key('B', i%700==400)
    b.run(1)
    if i%2==0: im=b.image(scale=1); fr.append((i,im.tobytes(),im.size))
pickle.dump(fr, open(out,'wb'))
