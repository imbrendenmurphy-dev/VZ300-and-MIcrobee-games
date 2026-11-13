# capture candidate frames: attract pages + scripted gameplay
from harness import *
import pickle
b,E=boot(); G=sym('/home/claude/ast/build/sim.sym')
frames=[]   # (tag, field, image)
def grab(tag): frames.append((tag, b.frames if hasattr(b,'frames') else 0, b.image(scale=1)))
# attract: one cycle
seen=set()
for i in range(2700):
    b.run(1)
    if i%4==0: grab('attract')
# start a game
for i in range(200):
    b.run(5)
    if 'ROCKS ARE' in ttext(b): break
b.run(60); b.key('SPACE'); b.run(4); b.keys_up(); b.run(40)
blk=b.block(1)
blk[G['wave']]=3
for j in range(G['N_ROCK']): blk[G['OBJ_ROCK']+j*G['OBJSZ']]=0
for i in range(2600):
    blk[G['lives']]=3
    b.key('RIGHT', (i//25)%5==0); b.key('LEFT', (i//25)%5==3); b.key('UP', (i//40)%4==1)
    b.key('SPACE', i%6<3); b.key('B', i%900==450)
    b.run(1)
    if i%4==0: grab('game')
pickle.dump([(t,f,im.tobytes(),im.size) for t,f,im in frames], open('/home/claude/ast/out/promo/frames.pkl','wb'))
print(len(frames))
