from harness import *
import numpy as np
b,E=boot()
b.run(100); t0=b.cycles; b.run(400); b.save_wav('/home/claude/ast/out/title_music.wav', t0=t0)
ts,vs=b.speaker(); sel=ts>=t0
print('title toggles',sel.sum())
b.key('SPACE'); b.run(4); b.keys_up(); b.run(30)
t0=b.cycles
for i in range(400):
    b.key('RIGHT',(i//20)%3==0); b.key('UP',(i//30)%3==0); b.key('SPACE',i%8<3); b.run(1)
b.save_wav('/home/claude/ast/out/game_sfx.wav', t0=t0)
ts,vs=b.speaker(); print('game toggles',(ts>=t0).sum())
