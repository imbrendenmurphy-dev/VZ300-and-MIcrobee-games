from harness import *
b,E=boot(); a=E['hi_score']-0x8000
inv={v:k for k,v in E.items()}
import bisect; ad=sorted(x for x in inv if x>=0x8000)
nm=lambda pc: inv[ad[bisect.bisect_right(ad,pc)-1]] if pc>=0x8000 else 'lower %04x'%pc
b.run(15)
while bytes(b.block(0)[a:a+3]).hex()!='010000': b.run(1)
v0=bytes(b.block(0)[a:a+3])
for f in range(120):
    for t in range(0,67500,500):
        L.bee_run_to(t)
        if t%2000: pass
        v=bytes(b.block(0)[a:a+3])
        if v!=v0: print('changed at frame',b.frames,'t',t,v.hex(),'pc',nm(b.reg('pc')),'sp %04x'%b.reg('sp')); raise SystemExit
    b.run(1)
