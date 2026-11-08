from harness import *
b,E=boot()
G=sym('/home/claude/ast/build/sim.sym')
b.run(150); b.key('SPACE'); b.run(4); b.keys_up(); b.run(40)
blk=b.block(1)
blk[G['score']]=0x02; blk[G['score']+1]=0x34; blk[G['score']+2]=0x50
blk[G['lives']]=1
for i in range(6000):
    b.key('UP', (i//10)%2==0); b.run(1)
    if i%10==0 and 'NEW HIGH' in ttext(b): break
b.keys_up(); b.run(30)
print('entry at',i); b.image(scale=1).save('/home/claude/ast/out/h0.png')
# enter B, P, M
def tap(k,n=1):
    for _ in range(n):
        b.key(k); b.run(6); b.keys_up(); b.run(6)
tap('RIGHT',1); tap('SPACE'); tap('RIGHT',14); tap('SPACE'); tap('LEFT',14); tap('SPACE')
b.run(20)
for i in range(800):
    b.run(5)
    if 'HIGH SCORES' in ttext(b): break
b.run(20); print(ttext(b)); b.image(scale=1).save('/home/claude/ast/out/h1.png')
