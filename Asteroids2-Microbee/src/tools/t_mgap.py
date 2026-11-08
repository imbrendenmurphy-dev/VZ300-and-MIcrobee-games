# music gaps over the attract cycle: longest silences (ms) and where
from harness import *
import sys, numpy as np
R=sys.argv[1] if len(sys.argv)>1 else '/home/claude/ast'
b,_=boot(R+'/build/AST2.DS8'); E=sym(R+'/build/engine.sym')
t0=b.cycles; marks=[]
last=''
for i in range(int(sys.argv[2]) if len(sys.argv)>2 else 1500):
    b.run(1); t=ttext(b)
    for k in ('ENEMY','TREASURE','DEMO','HIGH SC','ROCKS ARE'):
        if k in t and k not in last: marks.append(((b.cycles-t0)/3375,k))
    last=t
ts,vs=b.speaker(); ts=ts[ts>=t0]
d=np.diff(ts)/3375.0
idx=np.argsort(d)[::-1][:8]
print(R.split('/')[-1],'gaps(ms):',' '.join('%.0f@%.0fs'%(d[i],(ts[i]-t0)/3375000) for i in sorted(idx,key=lambda i:ts[i])))
print('pages:',' '.join('%s@%.1fs'%(k,t/1000) for t,k in marks))
