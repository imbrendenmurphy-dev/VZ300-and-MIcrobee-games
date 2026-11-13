from harness import *
import numpy as np, sys
b,E=boot()
b.run(150); b.key('SPACE'); b.run(4); b.keys_up(); b.run(60)
L.bee_spk_clear(); t0=b.cycles; f0=b.peekw(E['flips'])
for i in range(500):
    b.key('RIGHT',(i//30)%4==0); b.key('SPACE',i%6<3); b.run(1)
ts,vs=b.speaker(); d=np.diff(ts.astype(np.int64))/3375.0
tot=(b.cycles-t0)/3375.0
for lo,hi in ((1.5,5),(5,15),(15,40),(40,200)):
    sel=(d>=lo)&(d<hi); print('gaps %4.1f-%5.1f ms: %4d  (%4.0f ms total)'%(lo,hi,sel.sum(),d[sel].sum()))
print('fps %.1f  sound-on time %.0f%%'%((b.peekw(E['flips'])-f0)/10, 100*(1-d[d>=1.5].sum()/tot)))
