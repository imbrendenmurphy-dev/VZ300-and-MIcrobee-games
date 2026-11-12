import sys,json
from mtest import *
import pt3test,pt3ref
# make a PSG by recording the reference PT3 decoder's registers each tick
d=pt3ref.make_test(); ref=pt3ref.PT3(d); frames=[]
while True:
    r=ref.tick()
    if r is None: break
    regs={}
    for k,x in enumerate(r):
        regs[2*k]=x['per']&255; regs[2*k+1]=x['per']>>8; regs[8+k]=x['amp']
    mix=0
    for k,x in enumerate(r):
        if not x['ton']: mix|=1<<k
        if not x['noi']: mix|=8<<k
    regs[7]=mix; regs[6]=max([x['nper'] for x in r]+[0])
    frames.append(regs)
out=bytearray(b'PSG\x1a\x0a\x32'+bytes(10)); prev={}
for i,f in enumerate(frames):
    for k,v in f.items():
        if prev.get(k)!=v: out+=bytes([k,v])
    prev=dict(f); out.append(0xFF)
    if i==150: out+=bytes([0xFE,5])        # 20 frames of silence-hold, then continue
out.append(0xFD)
open('out/TEST.PSG','wb').write(out)
pt3test.sy=json.load(open('out/playpsg.json'))
m,st=pt3test.runplug({'TEST.PSG':bytes(out),'PLAYPSG.VZ':open('out/PLAYPSG.VZ','rb').read()},'TEST.PSG',len(frames)/50+2)
T=st['ticks']; print('frames',len(frames),'+20 hold; z80 ticks',len(T),'psg bytes',len(out))
exp=[]
for i,f in enumerate(frames):
    exp.append(f)
    if i==150: exp+= [f]*20
bad=0
for i,(t,v,dr) in enumerate(T[:len(exp)]):
    f=exp[i]; e=[(f[2*k]|f[2*k+1]<<8, f[8+k], 0 if f[7]>>k&1 else 1) for k in range(3)]
    e2=[(p if a and tn else None,a,tn if a else None) for p,a,tn in e]; g2=[(p if a and tn else None,a,tn if a else None) for p,a,tn in v]
    if e2!=g2:
        bad+=1
        if bad<5: print(i,e,v)
print('mismatched',bad)
print(m.screen())
