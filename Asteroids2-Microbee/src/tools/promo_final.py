from harness import *
import os
D='/home/claude/ast/out/promo/f/'; os.makedirs(D,exist_ok=True)
for f in os.listdir(D): os.remove(D+f)
b,E=boot(); G=sym('/home/claude/ast/build/sim.sym')
n=0
def grab(tag):
    global n
    b.image(scale=2).save(D+'%04d_%s.png'%(n,tag)); n+=1
def page(key):
    for i in range(3000):
        b.run(1)
        if key in ttext(b): return
# attract
page('ROCKS ARE'); b.run(30)
for i in range(40): grab('title'); b.run(4)
page('CONTROLS'); b.run(30)
for i in range(40): grab('controls'); b.run(4)
page('ENEMY'); b.run(30)
for i in range(22): grab('roster'); b.run(4)
page('TREASURE'); b.run(30)
for i in range(22): grab('treasure'); b.run(4)
page('HIGH SC'); b.run(30)
for i in range(22): grab('scores'); b.run(4)
# game at wave 6
page('ROCKS ARE'); b.run(60); b.key('SPACE'); b.run(4); b.keys_up(); b.run(40)
blk=b.block(1)
blk[G['wave']]=5; blk[G['wave_bcd']]=0x05
for j in range(G['N_ROCK']): blk[G['OBJ_ROCK']+j*G['OBJSZ']]=0
for i in range(720):
    blk[G['lives']]=3
    b.key('RIGHT', (i//25)%5==0); b.key('LEFT', (i//25)%5==3); b.key('UP', (i//40)%4==1)
    b.key('SPACE', i%6<3); b.key('B', i==430)
    b.run(1)
    if i>=20 and i%4==0: grab('game')
print(n)
