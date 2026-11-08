from harness import *
import numpy as np
def gaps(b,t0,t1,lab):
    ts,vs=b.speaker(); ts=ts[(ts>=t0)&(ts<t1)].astype(np.int64)
    if len(ts)<2: print(lab,'silent'); return
    d=np.diff(ts); tot=t1-t0
    big=d[d>4000]   # >1.2 ms with no speaker change = silence during a tone
    print('%-10s toggles %6d  silent-gap time %4.0f%%  longest gap %5.1f ms'%(lab,len(ts),100*big.sum()/tot, d.max()/3375))
b,E=boot()
L.bee_spk_clear()
b.run(120); t0=b.cycles; b.run(300); gaps(b,t0,b.cycles,'title')
for i in range(600):
    b.run(1)
    if 'ENEMY' in ttext(b): break
t0=b.cycles; b.run(150); gaps(b,t0,b.cycles,'roster')
for i in range(600):
    b.run(1)
    if 'TREASURE' in ttext(b): break
t0=b.cycles; b.run(150); gaps(b,t0,b.cycles,'treasure')
b.key('SPACE'); b.run(4); b.keys_up(); b.run(60)
f0=b.peekw(E['flips']); t0=b.cycles
for i in range(500):
    b.key('RIGHT',(i//30)%4==0); b.key('SPACE',i%6<3); b.run(1)
gaps(b,t0,b.cycles,'game'); print('game fps %.1f'%((b.peekw(E['flips'])-f0)/10))
b.save_wav('/home/claude/ast/out/game_sfx2.wav', t0=t0)
