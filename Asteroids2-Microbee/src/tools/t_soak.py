from harness import *
b,E=boot()
G=sym('/home/claude/ast/build/sim.sym')
b.run(150); b.key('SPACE'); b.run(4); b.keys_up(); b.run(20)
blk=b.block(1)
f0=b.peekw(E['flips']); t0=b.peekw(E['ticks']); fps=[]; sps=set(); games=1
for i in range(3000):
    blk[G['lives']]=3     # keep playing to reach later waves
    b.key('RIGHT', (i//30)%4==0); b.key('UP', (i//45)%5==0); b.key('SPACE', i%6<3); b.key('B', i%1500==700)
    b.run(1)
    if i%100==99:
        f1=b.peekw(E['flips']); t1=b.peekw(E['ticks']); fps.append(((f1-f0)/2, (t1-t0)/2)); f0,t0=f1,t1
        sps.add(b.reg('sp'))
    if i in (2000,4000,5900): b.image(scale=1).save('/home/claude/ast/out/s%d.png'%i)
print('fps,tps per 2s:', fps)
print('min fps',min(f for f,t in fps),'mean',sum(f for f,t in fps)/len(fps), 'ticks/s mean', sum(t for f,t in fps)/len(fps))
print('wave',blk[G['wave']],'score',bytes(blk[G['score']:G['score']+3]).hex(),'sp',[hex(x) for x in sorted(sps)][:5], 'pc %04x'%b.reg('pc'))
