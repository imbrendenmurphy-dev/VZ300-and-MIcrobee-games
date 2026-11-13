import json,collections,sys
from mtest import *
KEYS['O']=(0xBF,1)
import pt3test
def setup(extra):
    im=FatImg()
    for n in ('VZDOS.VZ','SHELL.VZ','PLAYPT3.VZ','PLAYPSG.VZ'): im.addfile(2,n,open('out/'+n,'rb').read())
    for n,d in extra.items(): im.addfile(2,n,d)
    im.finish(); return im,sorted(['VZDOS.VZ','SHELL.VZ','PLAYPT3.VZ','PLAYPSG.VZ']+list(extra))
psg=bytearray(b'PSG\x1a'+bytes(12))+bytes([0,252,1,0,8,15,9,0,10,0,7,0xFE,0xFF])+bytes([0xFF])*60+bytes([0xFD])
mid=midi0([(0,b'\x90\x45\x64'),(960,b'\x80\x45\x00')])
im,names=setup({'T.PSG':bytes(psg),'A.MID':mid})
for mode in range(4):
    m=boot(im); m.tsync=True
    go(m,[(None,5)],maxsteps=40000000)
    m.spk=[]; m.prn=[]
    go(m,tap('O',mode),extra=30,maxsteps=10**8)
    tone=collections.Counter(v for t,v in (m.prn if mode==3 else m.spk))
    print('mode',mode,m.screen().split('\n')[14].strip(),'| beep writes',dict(tone.most_common(4)))
    for tgt in ('T.PSG','A.MID'):
        m.spk=[]; m.prn=[]
        go(m,tap('UP',6)+tap('DOWN',names.index(tgt))+tap('RET'),extra=55,maxsteps=10**9)
        top=m.screen().split('\n')[0]
        src=m.prn if mode==3 else m.spk
        c=collections.Counter(v for t,v in src)
        # voice-A spacing inside a chunk / pitch check
        w=[t for t,v in src if v in (0x01,0x06,0x07)]
        d=collections.Counter(np.diff(w)) if len(w)>2 else {}
        hi={0:0x01,1:0x06,2:0x07,3:0x01}[mode]; lo={0:0x20,1:0x00,2:0x20,3:0x20}[mode]
        seq=[(t,v) for t,v in src if v in (hi,lo)]
        # instantaneous frequency: rising edges per time within contiguous sounding (exclude gaps > 1000T)
        ups=0; tt=0
        for i in range(1,len(seq)):
            dt=seq[i][0]-seq[i-1][0]
            if dt<1000: tt+=dt
            if seq[i][1]==hi and seq[i-1][1]==lo: ups+=1
        f=ups/(tt/CPU) if tt else 0
        print('   ',tgt,top.strip()[:32],'| values',dict(c.most_common(4)),'| latch writes',len(m.spk),'printer writes',len(m.prn),'| inst freq %.1f'%f)
        go(m,tap('RET'),extra=60,maxsteps=10**9)
