import sys, bisect; sys.path.insert(0,'.')
from harness import *
exec(open('t7.py').read().split('# time load')[0])
z=m.z
syms=sorted((v,k) for k,v in sym.items() if 0xA000<=v<0xC400 and not k.startswith('.') and '.' not in k)
addrs=[a for a,_ in syms]
prof={}
m.type_keys(['A','B','C','D']); f0=m.frame; disp=sym['dispatch']; edlp=sym['ed_lp']; on=False
while m.script and m.frame-f0<600:
    if z.pc<0x4000: m.trap(); continue
    if z.pc==disp: on=True
    if z.pc==edlp: on=False
    pc=z.pc; t=z.t; z.step()
    if on:
        i=bisect.bisect_right(addrs,pc)-1; n=syms[i][1] if i>=0 else '?'
        prof[n]=prof.get(n,0)+z.t-t
tot=sum(prof.values())
for k,v in sorted(prof.items(),key=lambda x:-x[1])[:14]: print('%-14s %7d %4.1f%%'%(k,v/4,100*v/tot))
print('per key',tot/4)
