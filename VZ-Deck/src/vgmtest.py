import sys,json
from mtest import *
import pt3test,vgmref
d=open(sys.argv[1],'rb').read() if len(sys.argv)>1 else vgmref.mk_vgm()
ref=vgmref.VGM(d); R=[]
while True:
    r=ref.field()
    if r is None: break
    R.append(r)
pt3test.sy=json.load(open('out/playvgm.json'))
m,st=pt3test.runplug({'T.VGM':d,'PLAYVGM.VZ':open('out/PLAYVGM.VZ','rb').read()},'T.VGM',len(R)/50+2)
T=st['ticks']; print('ref',len(R),'z80',len(T))
bad=0
for i in range(min(len(R),len(T))):
    e=[(p if a else None,a) for p,a,t in R[i]]; g=[(p if a else None,a) for p,a,t in T[i][1]]
    if e!=g:
        bad+=1
        if bad<6: print(i,e,g)
print('mismatched',bad,'drums',sum(1 for t in T if t[2]))
print(m.screen())
