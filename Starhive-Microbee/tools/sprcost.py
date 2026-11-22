"""Cost of spr_draw (T-states) a call, fitted per sprite, per cell over
black and per cell over scenery.  python tools/sprcost.py LEVEL CALLS"""
import sys; from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np, starhive_run as sh
lv=int(sys.argv[1]); N=int(sys.argv[2])
pp=sh.boot(); S=pp.S; P=pp.peek; W=pp.peekw; BK=S['bk_s']
pp.run_frames(250); pp.keys={'SPACE'}; pp.run_frames(6)
if lv>1:
    pp.poke(S['level'],lv-1); pp.poke(S['state'],3); pp.poke(S['stimer'],1); pp.run_frames(560)
for t in range(20):
    pp.keys={'SPACE',['LEFT','RIGHT'][(t//10)%2]}; pp.poke(S['inv'],100); pp.run_frames(10)
rows=[]
for i in range(N):
    pp.keys={'SPACE',['LEFT','RIGHT'][(i//200)%2]}; pp.poke(S['inv'],100)
    pp.run_until(S['spr_draw'],5); t0=pp.tick; ret=W(pp.cpu.sp)
    p0=[W(BK+2*j) for j in range(22)]
    pp.run_until(ret,5); dt=pp.tick-t0
    cells=0; pairs=0
    for j in range(22):
        p=p0[j]; p1=W(BK+2*j)
        while p<p1:
            ring=(P(p)|P(p+1)<<8)&0x7ff; cells+=1
            if P(0x7800|ring)!=11: pairs+=1
            p+=6
    rows.append((dt,cells,pairs))
a=np.array(rows,float)
X=np.c_[np.ones(len(a)),a[:,1]-a[:,2],a[:,2]]
coef=np.linalg.lstsq(X,a[:,0],rcond=None)[0]
print('mean T %.0f cells %.2f pairs %.2f | fit: per sprite %.0f, black cell %.0f, scenery cell %.0f'%(a[:,0].mean(),a[:,1].mean(),a[:,2].mean(),*coef))
