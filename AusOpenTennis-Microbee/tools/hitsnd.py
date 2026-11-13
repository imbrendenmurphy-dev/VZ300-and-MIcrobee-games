"""How much of each racket hit is actually heard: speaker pulses in the
frames after every hit of a computer-vs-computer match."""
import run, numpy as np
pp=run.boot(); S=pp.S
pp.poke(S['boot_test'],1); pp.run_frames(150); pp.poke(S['autoplay'],1)
pp.speaker(True)
last=pp.peek(S['rally']); res=[]
for f in range(6000):
    pp.run_frames(1)
    r=pp.peek(S['rally'])
    if r!=last and r>last:
        t0=pp.tick
        pp.run_frames(6)
        t,v=pp.speaker(True)
        res.append(int(((t>=t0)).sum()))
    else:
        pp.speaker(True)
    last=r
res=np.array(res)
print('hits',len(res),'pulses: min',res.min(),'median',int(np.median(res)),'hits with < 20 pulses',(res<20).sum())
