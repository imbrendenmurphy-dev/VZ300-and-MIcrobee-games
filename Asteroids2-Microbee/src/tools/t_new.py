from harness import *
b,E=boot(); G=sym('/home/claude/ast/build/sim.sym')
b.run(200); b.image().save('/home/claude/ast/out/n_title.png')
# define keys: K, then press Q W E R T Y
b.key('K'); b.run(4); b.keys_up()
for i in range(100):
    b.run(5)
    if 'DEFINE KEYS' in ttext(b): break
b.run(20)
for k in 'QWERTY':
    b.key(k); b.run(10); b.keys_up(); b.run(10)
b.image().save('/home/claude/ast/out/n_keys.png')
print([b.peek(E['keymap']+2*i) for i in range(6)])
print('\n'.join(ttext(b).split('\n')[1:14]))
for i in range(200):
    b.run(5)
    if 'ROCKS ARE' in ttext(b): break
# play with new keys: R = fire
b.key('R'); b.run(4); b.keys_up(); b.run(40)
blk=b.block(1); print('wave',blk[G['wave']])
n=sum(1 for i in range(24) if blk[G['OBJ_ROCK']+i*G['OBJSZ']] if True) if 'OBJ_ROCK' in G else None
for i in range(150):
    b.key('R', i%6<3); b.key('Q',i%40<10); b.run(1)
print('enemy_count',blk[G['enemy_count']],'score',bytes(blk[G['score']:G['score']+3]).hex())
b.image().save('/home/claude/ast/out/n_game.png')
cnt=0
for i in range(300):
    b.key('R', i%6<3); b.key('Q',i%40<10); b.run(1)
    cnt=max(cnt,sum(1 for j in range(G['N_PBUL']) if blk[G['OBJ_PBUL']+j*G['OBJSZ']]))
print('max player bullets',cnt,'score',bytes(blk[G['score']:G['score']+3]).hex(), 'rocks', sum(1 for j in range(G['N_ROCK']) if blk[G['OBJ_ROCK']+j*G['OBJSZ']]))
b.image().save('/home/claude/ast/out/n_game.png')
