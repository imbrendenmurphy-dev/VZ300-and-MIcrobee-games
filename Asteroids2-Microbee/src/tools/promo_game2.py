from harness import *
import os
D='/home/claude/ast/out/promo/f/'
for f in os.listdir(D):
    if 'game' in f: os.remove(D+f)
b,E=boot(); G=sym('/home/claude/ast/build/sim.sym')
for i in range(200):
    b.run(5)
    if 'ROCKS ARE' in ttext(b): break
d=312
b.run(60); b.key("SPACE"); b.run(4); b.keys_up(); b.run(40+d)
blk=b.block(1)
blk[G['wave']]=5; blk[G['wave_bcd']]=5; blk[G['rnd_seed']]=d*37&255; blk[G['rnd_seed']+1]=(d*91+7)&255
for j in range(G['N_ROCK']): blk[G['OBJ_ROCK']+j*G['OBJSZ']]=0
n=1000
for i in range(900):
    blk[G['lives']]=3
    b.key('RIGHT', (i//25)%5==0); b.key('LEFT', (i//25)%5==3); b.key('UP', (i//40)%4==1)
    b.key('SPACE', i%6<3); b.key('B', 430<=i<436)
    b.run(1)
    if i>=20 and i%4==0: b.image(scale=2).save(D+'%04d_game.png'%n); n+=1
