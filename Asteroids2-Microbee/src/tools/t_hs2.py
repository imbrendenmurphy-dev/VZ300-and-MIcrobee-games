from harness import *
b,E=boot()
G=sym('/home/claude/ast/build/sim.sym')
b.run(60); b.key('SPACE'); b.run(4); b.keys_up(); b.run(40)
blk=b.block(1)
blk[G['score']]=0x02; blk[G['score']+1]=0x34; blk[G['score']+2]=0x50
blk[G['lives']]=1
for i in range(60):
    b.key('UP', i%2==0); b.run(25)
    print(i, blk[G['lives']], blk[G['game_over']], blk[G['gover_tmr']], blk[G['ship_state']], b.peek(E['ST_DONE']) if 'ST_DONE' in E else b.peek(0xD309), text(b).split('\n')[7][:40])
    if 'NEW' in text(b): break
