from harness import *
import sys
b,E=boot()
b.run(100)
b.key('SPACE'); b.run(4); b.keys_up(); b.run(30)
G=sym('/home/claude/ast/build/sim.sym')
ims=[]; stats=[]
f0=b.peekw(E['flips']); t0=b.peekw(E['ticks'])
N=int(sys.argv[1]) if len(sys.argv)>1 else 1500
for i in range(N):
    b.key('RIGHT', (i//25)%5==0); b.key('UP', (i//40)%4==0); b.key('SPACE', i%8<3)
    b.key('B', i==900)
    b.run(1)
    if i%50==49:
        f1=b.peekw(E['flips']); t1=b.peekw(E['ticks'])
        stats.append((i+1,(f1-f0),(t1-t0))); f0,t0=f1,t1
    if 300<=i<400: ims.append(b.image(scale=1))
    if i in (320,324,328,332,336,340,700,704,708,1200,1204,1208): b.image(scale=1).save('/home/claude/ast/out/f%04d.png'%i)
    if i%300==299: b.image().save('/home/claude/ast/out/p%d.png'%(i//300))
print('per 50 fields: (field, frames shown, sim ticks)'); print(stats)
print('lives',b.block(1)[G['lives']],'wave',b.block(1)[G['wave']],'score',bytes(b.block(1)[G['score']:G['score']+3]).hex())
ims[0].save('/home/claude/ast/out/play.gif',save_all=True,append_images=ims[1:],duration=20,loop=0)
