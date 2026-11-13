# reference PT3 decoder (per-tick channel outputs), following the PT3 player logic
import struct
AY=1773400.0
PT=[int(round(AY/16/(32.703195662574829*2**(n/12)))) for n in range(96)]
VT=[[int(round(v*a/15)) for a in range(16)] for v in range(16)]
def s16(x): x&=0xFFFF; return x-65536 if x&0x8000 else x
class Ch:
    def __init__(c): 
        c.addr=0; c.skip=1; c.skipc=1; c.note=0; c.smp=0; c.orn=0; c.psmp=0; c.porn=0; c.vol=15; c.en=0; c.env=0
        c.tacc=0; c.tsld=0; c.tstep=0; c.tdly=0; c.tcnt=0; c.asld=0; c.nsld=0; c.port=0; c.tdelt=0; c.sltn=0; c.von=0; c.voff=0; c.vcnt=0
class PT3:
    def __init__(p,d):
        p.d=d; p.ver=6 if d[0:1]==b'V' else (d[13]-48 if 48<=d[13]<=57 else 6)
        p.delay=d[0x64] or 1; p.npos=d[0x65]; p.patp=struct.unpack('<H',d[0x67:0x69])[0]
        p.ch=[Ch(),Ch(),Ch()]; p.nbase=0; p.dcnt=1; p.posi=0; p.ended=False
        for c in p.ch: c.smp=p.sptr(1); c.orn=p.optr(0)
        p.setpat()
    def w(p,a): return struct.unpack('<H',p.d[a:a+2])[0]
    def sptr(p,n): return p.w(0x69+2*n)
    def optr(p,n): return p.w(0xA9+2*n)
    def setpat(p):
        if p.posi>=p.npos or p.d[0xC9+p.posi]==0xFF: p.ended=True; return
        e=p.patp+2*p.d[0xC9+p.posi]
        for i,c in enumerate(p.ch): c.addr=p.w(e+2*i)
    def reset(p,c): c.psmp=c.asld=c.nsld=c.porn=c.tcnt=c.tsld=c.tacc=c.vcnt=0
    def interp(p,c):
        d=p.d; prnote=c.note; prsld=c.tsld; a=c.addr; fl={}; cnt=0
        while True:
            v=d[a]
            if v>=0xF0: c.orn=p.optr(v-0xF0); a+=1; c.smp=p.sptr(d[a]//2); c.env=0; c.porn=0
            elif v>=0xD1: c.smp=p.sptr(v-0xD0)
            elif v==0xD0: break
            elif v>=0xC1: c.vol=v-0xC0
            elif v==0xC0: p.reset(c); c.en=0; break
            elif v>=0xB2: a+=2; c.env=1; c.porn=0
            elif v==0xB1: a+=1; c.skip=d[a]
            elif v==0xB0: c.env=0; c.porn=0
            elif v>=0x50: c.note=v-0x50; p.reset(c); c.en=1; c.newn=1; break
            elif v>=0x40: c.orn=p.optr(v-0x40); c.porn=0
            elif v>=0x20: p.nbase=v-0x20
            elif v>=0x10:
                if v==0x10: c.env=0
                else: a+=2; c.env=1
                a+=1; c.smp=p.sptr(d[a]//2); c.porn=0
            elif v==0: break
            elif v in (1,2,3,4,5,8,9): cnt+=1; fl[v]=cnt
            a+=1
        a+=1
        while cnt>0:
            for k,vv in fl.items():
                if vv!=cnt: continue
                if k==1:
                    c.tdly=c.tcnt=d[a]; c.tstep=s16(p.w(a+1)); a+=3; c.port=0; c.vcnt=0
                    if c.tcnt==0 and p.ver>=7: c.tcnt=1
                elif k==2:
                    c.port=1; c.tdly=c.tcnt=d[a]; a+=3; st=abs(s16(p.w(a))); a+=2
                    c.tdelt=s16(PT[min(c.note,95)]-PT[min(prnote,95)]); c.sltn=c.note; c.note=prnote
                    if p.ver>=6: c.tsld=prsld
                    if s16(c.tdelt-c.tsld)<0: st=-st
                    c.tstep=st
                elif k==3: c.psmp=d[a]; a+=1
                elif k==4: c.porn=d[a]; a+=1
                elif k==5: c.von=c.vcnt=d[a]; c.voff=d[a+1]; a+=2; c.tcnt=0; c.tsld=0
                elif k==8: a+=3
                elif k==9:
                    if d[a]: p.delay=d[a]
                    a+=1
            cnt-=1
        c.addr=a; c.skipc=c.skip
    def regs(p,c):
        d=p.d; out=dict(per=0,amp=0,ton=0,noi=0,nper=0)
        if c.en:
            L=c.smp+2+4*c.psmp; b0,b1=d[L],d[L+1]; ton=(p.w(L+2)+c.tacc)&0xFFFF
            if b1&0x40: c.tacc=ton
            j=c.note+s16(d[c.orn+2+c.porn]|(0xFF00 if d[c.orn+2+c.porn]&0x80 else 0)); j=0 if j<0 else min(j,95)
            out['per']=(ton+c.tsld+PT[j])&0xFFF
            if c.tcnt>0:
                c.tcnt-=1
                if c.tcnt==0:
                    c.tcnt=c.tdly; c.tsld=s16(c.tsld+c.tstep)
                    if c.port:
                        diff=s16(c.tsld-c.tdelt)
                        if diff==0 or (diff<0)==(c.tstep<0): c.note=c.sltn; c.tcnt=0; c.tsld=0
            if b0&0x80:
                if b0&0x40:
                    if c.asld<15: c.asld+=1
                elif c.asld>-15: c.asld-=1
            am=max(0,min(15,(b1&15)+c.asld)); am=VT[c.vol][am]
            if not b0&1 and c.env: am=16
            out['amp']=am
            if not b1&0x80:
                n=(((b0>>1)&31)+c.nsld)&255
                if b1&0x20: c.nsld=n
                out['noi']=1; out['nper']=(p.nbase+n)&31
            out['ton']=0 if b1&0x10 else 1
            c.psmp+=1
            if c.psmp>=d[c.smp+1]: c.psmp=d[c.smp]
            c.porn+=1
            if c.porn>=d[c.orn+1]: c.porn=d[c.orn]
        if c.vcnt>0:
            c.vcnt-=1
            if c.vcnt==0:
                c.en^=1; c.vcnt=c.von if c.en else c.voff
        return out
    def tick(p):
        p.dcnt-=1
        if p.dcnt==0:
            p.dcnt=p.delay; a=p.ch[0]; a.skipc-=1
            if a.skipc==0:
                if p.d[a.addr]==0:
                    p.posi+=1; p.setpat()
                    if p.ended: return None
                    p.nbase=0
                p.interp(a)
            for c in p.ch[1:]:
                c.skipc-=1
                if c.skipc==0: p.interp(c)
        return [p.regs(c) for c in p.ch]

def make_test():
    # a small hand-built module exercising most commands
    smp={}; orn={}
    smp[1]=bytes([0,1, 0x01,0x8F,0,0])                                           # steady tone
    smp[2]=bytes([0,4]+[0x01,0x8F,0,0, 0x81,0x8E,0,0, 0x81,0x8D,0,0, 0x01,0x8C,0x02,0])   # amp slide down, small detune
    smp[3]=bytes([3,4]+[0x09,0x1F,0,0, 0x07,0x1D,0,0, 0x05,0x1A,0,0, 0x01,0x90,0,0])     # noise drum, then silence (tone off amp 0)
    smp[4]=bytes([3,4]+[0x01,0xCF,0x20,0, 0x01,0xCE,0x20,0, 0x01,0xCC,0x20,0, 0x01,0x80,0,0])  # kick: accumulating tone sweep
    smp[5]=bytes([0,2]+[0x01,0x0F,0,0, 0x01,0x8F,0,0])                           # tone + noise mixed (snare-ish) then tone
    orn[0]=bytes([0,1,0]); orn[1]=bytes([0,3,0,4,7]); orn[2]=bytes([0,2,0,0xF4])
    N=lambda n:0x50+n
    A=bytes([0xF1,2, N(36), 0xD0, 0x40,N(40), 0xC8,N(43), 0xD0, 0xCF,0x01,N(48),3,0x40,0x00,
             0x02,N(55),2,0,0,0x08,0x00, 0xD0,0xD0, 0x05,N(48),2,1, 0xD0,0xD0, 0xC0, 0xD0, 0x09,N(36),4, 0xD0,0xD0, 0x03,0x04,N(38),0,2, 0xD0, 0xB1,2,N(41),0xD0,0xD0,0xD0,0x00])
    B=bytes([0x13,0x01,0x40,8, N(24), 0xD0, 0xD3,N(24),0xD0,0xD4,N(26), 0xB1,4, 0xD2,N(31),N(29),N(28),0xC0, 0xB1,1, 0x2A,0xD5,N(26),0xD0,0xD0,0xD0])
    C=bytes([0xD1,0x42,N(60),0xD0,0xD0,0xD0, 0xF2,10, N(64),0xD0,0x01,N(67),3,0xF0,0xFF,0xD0,0xD0,0x10,6,N(72),0xD0,0x0F if False else 0xD0, 0xB0,N(60),0xD0,0xD0,0xD0,0xD0])
    A2=bytes([0xF0,2,N(50),0xD0,0xD0,N(52),0xD0,0x00]); B2=bytes([0xD3,N(30),0xD0,0xD0,0xD0,0xD0]); C2=bytes([0xD1,N(70),0xD0,0xD0,0xD0,0xD0])
    hdr=bytearray(b'ProTracker 3.6 compilation of '.ljust(0x1E)); hdr+=b'VZ-DECK PT3 TEST TUNE'.ljust(32)+b' by '+b'BPM'.ljust(32)
    hdr+=bytes([0,3,3,0,0,0])           # 0x62 pad? -> fix offsets below
    hdr=hdr[:0x63]+bytes([0,3,3,0])     # tone table, delay, npos, loop
    hdr+=b'\0\0'                        # patp at 0x67
    hdr+=bytes(64)+bytes(32)            # sample and ornament pointers
    assert len(hdr)==0xC9
    pos=bytes([0,3,0,0xFF])
    body=bytearray(hdr+pos)
    def put(b):
        o=len(body); body.extend(b); return o
    pad=bytes([0xD0])*64
    pats=[(A,B+pad,C+pad),(A2,B2+pad,C2+pad)]
    chd=[[put(x) for x in p] for p in pats]
    patp=len(body)
    for p in chd:
        for o in p: body.extend(struct.pack('<H',o))
    struct.pack_into('<H',body,0x67,patp)
    for i in range(32):
        o=put(smp.get(i,smp[1])) if i in smp else None
        struct.pack_into('<H',body,0x69+2*i,o if o is not None else 0)
    for i in range(16): struct.pack_into('<H',body,0xA9+2*i,put(orn[i]) if i in orn else 0)
    # undefined samples/ornaments point at defined ones
    for i in range(32):
        if i not in smp: struct.pack_into('<H',body,0x69+2*i,struct.unpack('<H',body[0x6B:0x6D])[0])
    for i in range(16):
        if i not in orn: struct.pack_into('<H',body,0xA9+2*i,struct.unpack('<H',body[0xA9:0xAB])[0])
    return bytes(body)
if __name__=='__main__':
    d=make_test(); open('out/TEST.PT3','wb').write(d); p=PT3(d); n=0
    while True:
        r=p.tick()
        if r is None: break
        n+=1
        if n<30: print(n,[(x['per'],x['amp'],x['ton'],x['noi']) for x in r])
    print('ticks',n,'size',len(d))
