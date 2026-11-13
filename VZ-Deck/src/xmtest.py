import sys,json
from mtest import *
import pt3test,xmref
sy=json.load(open('out/playxm.json')); pt3test.sy=sy
d=open(sys.argv[1],'rb').read() if len(sys.argv)>1 else xmref.mk_xm()
ref=xmref.XM(d); R=[]
while ref.field(): R.append(ref.voices())
orig=pt3test.boot
cap=[]
def boot2(im):
    m=orig(im); z=m.z; os=z.step
    def step():
        if z.pc==sy['vapply'] and z.mem[0xA000]==0xF3:
            cap.append((tuple(z.mem[sy['vnote']+k] for k in range(3)),z.mem[sy['dreq']]))
        os()
    z.step=step; return m
pt3test.boot=boot2
m,st=pt3test.runplug({'T.XM':d,'PLAYXM.VZ':open('out/PLAYXM.VZ','rb').read()},'T.XM',len(R)/50+1.5)
print('ref fields',len(R),'z80 fields',len(cap))
bad=0
for i in range(min(len(R),len(cap))):
    if R[i]!=cap[i][0]:
        bad+=1
        if bad<8: print(i,'ref',R[i],'z80',cap[i][0])
print('mismatched',bad,'z80 drum ticks',[dr for _,dr in cap if dr])
print(m.screen())
