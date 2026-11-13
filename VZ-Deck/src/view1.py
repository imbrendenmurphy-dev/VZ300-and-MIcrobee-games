import sys
from mtest import *
KEYS['V']=(0xFB,5)
fmt,src=sys.argv[1],sys.argv[2]
files={n:open('out/'+n,'rb').read() for n in ('VZDOS.VZ','SHELL.VZ','PLAY%s.VZ'%fmt.upper())}
fn='T.'+fmt.upper(); files[fn]=open(src,'rb').read(); names=sorted(files)
im=FatImg()
for n,d in files.items(): im.addfile(2,n,d)
im.finish(); m=boot(im); m.tsync=True; go(m,[(None,5)],maxsteps=40000000)
go(m,tap('DOWN',names.index(fn))+tap('RET'),extra=120,maxsteps=10**10)
res=[]
for want in range(5):
    n=0
    while m.z.mem[0x7FDE]!=want and n<6: go(m,tap('V'),extra=8,maxsteps=10**10); n+=1
    go(m,[(None,20)],extra=1,maxsteps=10**10); a=bytes(m.z.mem[0x7000+5*32:0x7000+12*32])
    go(m,[(None,8)],extra=1,maxsteps=10**10); b=bytes(m.z.mem[0x7000+5*32:0x7000+12*32])
    lit=sum(1 for x in b if (x>=0x80 and x&15) or (x<0x80 and (x&0x3F)!=0x20))
    res.append('v%d %s: %3d drawn, %3d changing'%(want,'OK ' if m.z.mem[0x7FDE]==want else 'ERR',lit,sum(1 for x,y in zip(a,b) if x!=y)))
    __import__('vzrender').render(b'\x00'*0+bytes(m.z.mem[0x7000:0x7200])).save('../vchk_%s_%d.png'%(fmt,want))
print(fmt.upper(),' | '.join(res),flush=True)
