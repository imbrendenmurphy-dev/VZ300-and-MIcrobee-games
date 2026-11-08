from harness import *
b,E=boot()
b.run(100); b.key('SPACE'); b.run(4); b.keys_up(); b.run(60)
# find long stretches without a vb_poll: breakpoint-free method: profile vb_poll entry times via stepping is slow;
# instead compare counts over windows
import numpy as np
f0=b.peek(E['fields']); n0=b.frames
miss=[]
for i in range(3000):
    b.key('RIGHT', (i//25)%5==0); b.key('SPACE', i%8<3)
    b.run(1)
    f1=b.peek(E['fields']); d=(f1-f0)&255; f0=f1
    if d!=1: miss.append((i,d))
print(miss[:40], len(miss))
