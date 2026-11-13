import sys,collections
from mtest import *
KEYS['O']=(0xBF,1); KEYS['T']=(0xFE,0); KEYS['V']=(0xFB,5)
TF='../testfiles/'
files={n:open('out/'+n,'rb').read() for n in ('VZDOS.VZ','SHELL.VZ','PLAYPSG.VZ','PLAYXM.VZ')}
files['T.PSG']=open('out/TEST.PSG','rb').read(); files['L.XM']=open('out/LONG.XM','rb').read()
files['A.MOD']=open(TF+'ACIDBAT2.MOD','rb').read(); files['B.MID']=open(TF+'BJROCK.MID','rb').read()
names=sorted(files)
def mk():
    im=FatImg()
    for n,d in files.items(): im.addfile(2,n,d)
    im.finish(); m=boot(im); m.tsync=True; go(m,[(None,5)],maxsteps=40000000); m.spk=[]; return m
def snap(m): return bytes(m.z.mem[0x7000:0x7200])
steps=[('root',[]),('down',tap('DOWN',2))]
for tgt in ('L.XM','A.MOD','B.MID'):
    steps.append((tgt,tap('UP',9)+tap('DOWN',names.index(tgt))+tap('RET')))
    for v in range(4): steps.append((tgt+' v%d'%(v+1),tap('V')))
    steps.append((tgt+' back',tap('V')+tap('RET')+[(None,150)]))
def run(theme):
    m=mk(); out=[]
    if theme: go(m,tap('T',theme),extra=10,maxsteps=10**8)
    for name,keys in steps:
        go(m,keys,extra=80,maxsteps=10**9); out.append((name,snap(m),m.screen(),[v for t,v in m.spk[-2000:]])); m.spk=[]
    return out
A=run(0); B=run(1); C=run(2)
for (n,a,sa,_),(_,b,sb,_),(_,c,sc,lc) in zip(A,B,C):
    bad=[i for i in range(512) if a[i]<0x80 and b[i]!=a[i]^0x40]
    rows=sorted(set(i//32 for i in bad))
    css=collections.Counter(v&0x10 for v in lc)
    print('%-12s dark mismatches %3d rows %s | red: same screen %s, latch CSS %s'%(n,len(bad),rows,a==c,dict(css)))
    if bad and len(sys.argv)>1: print(sa); print(sb)
print(B[4][2]); print(C[3][2])
for i in (2,3,6,7,8,9,12,13,14,15): print(A[i][0]); print(A[i][2]); print(B[i][2]); print(C[i][2]); print(len(A[i][3]))
