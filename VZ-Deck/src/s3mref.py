import struct
def mk_s3m(long=False):
    # instruments: (name, length, c2spd, loop, vol)
    insts=[('Piano',20000,8363,1,48),('Pluck',4000,8363,0,64),('BassDrum 1',3000,8363,0,64),('Snare 2',3000,8363,0,60),('Closed HiHat',800,8363,0,40),('Bass up8va',6000,16726,0,64)]
    def N(o,s): return o*16+s
    # pattern rows: list of 64 rows, each list of (ch,note,ins,vol,cmd,info)
    def pat(rows):
        b=bytearray()
        for r in range(64):
            for ev in rows.get(r,[]):
                ch,note,ins,vol,cmd,info=ev; what=ch
                if note is not None: what|=32
                if vol is not None: what|=64
                if cmd is not None: what|=128
                b.append(what)
                if note is not None: b+=bytes([note,ins])
                if vol is not None: b.append(vol)
                if cmd is not None: b+=bytes([cmd,info])
            b.append(0)
        return bytes(struct.pack('<H',len(b)+2))+bytes(b)
    p0={0:[(0,N(4,0),1,None,1,4),(1,N(2,0),6,None,None,None),(2,N(3,0),3,None,None,None)],
        2:[(3,N(4,4),2,32,None,None),(4,N(5,0),2,None,None,None)],
        4:[(0,N(4,7),1,None,None,None),(2,N(3,0),4,None,None,None),(5,N(6,0),2,None,None,None)],   # ch5 disabled
        6:[(1,N(2,5),6,None,None,None),(2,N(3,0),5,None,None,None)],
        8:[(0,254,0,None,None,None),(3,N(4,9),2,None,None,None)],
        10:[(0,N(5,0),1,20,20,150)],
        12:[(1,N(1,7),6,None,None,None),(2,N(3,0),3,None,None,None)],
        16:[(0,N(4,2),1,None,3,0x10)]}       # break to row 10 of next pattern
    p1={0:[(0,N(3,0),1,None,None,None)],
        10:[(0,N(4,11),2,None,None,None),(1,N(3,3),6,None,None,None),(2,N(3,0),5,None,None,None)],
        12:[(3,N(5,2),2,None,None,None)],
        14:[(0,N(4,0),1,None,1,3)],
        20:[(1,N(2,0),6,None,None,None),(0,N(4,4),1,None,None,None)],
        24:[(0,None,0,None,2,0)]}             # jump back to order 0: the end
    orders=[0,254,1,0,255] if not long else [0,1]*12+[255]
    if long: p1[24]=[]
    hdr=bytearray(0x60); hdr[0:28]=b'VZ-DECK S3M TEST'.ljust(28,b'\0'); hdr[0x1C]=0x1A; hdr[0x1D]=16
    struct.pack_into('<HHH',hdr,0x20,len(orders),len(insts),2); hdr[0x2C:0x30]=b'SCRM'; hdr[0x30]=64; hdr[0x31]=6; hdr[0x32]=125
    for i in range(32): hdr[0x40+i]=(i if i<5 else 0xFF) if i!=5 else 0xFF
    body=bytearray(hdr)+bytes(orders)
    ipos=len(body); body+=bytes(2*len(insts)); ppos=len(body); body+=bytes(4)
    def align():
        while len(body)%16: body.append(0)
    ip=[]
    for name,ln,c2,lp,vol in insts:
        align(); ip.append(len(body)//16)
        h=bytearray(0x50); h[0]=1; h[1:13]=name[:12].upper().encode().ljust(12,b'\0')
        struct.pack_into('<I',h,0x10,ln); h[0x1C]=vol; h[0x1F]=lp; struct.pack_into('<I',h,0x20,c2); h[0x30:0x30+28]=name.encode().ljust(28,b'\0'); h[0x4C:0x50]=b'SCRS'
        body+=h
    pp=[]
    for p in (p0,p1):
        align(); pp.append(len(body)//16); body+=pat(p)
    align(); body+=bytes(5000)        # stand-in for sample data
    for i,v in enumerate(ip): struct.pack_into('<H',body,ipos+2*i,v)
    for i,v in enumerate(pp): struct.pack_into('<H',body,ppos+2*i,v)
    return bytes(body)
KW=[(2,"SNAR"),(2,"CLAP"),(1,"HAT"),(1,"HH"),(1,"SHAK"),(1,"CYM"),(1,"CRASH"),(1,"RIDE"),(1,"TAMB"),(3,"KICK"),(3,"BD"),(3,"BASSDR"),(3,"DRUM"),(3,"TOM"),(3,"CONGA"),(3,"BONGO"),(2,"SD")]
def kind(b,n=26):
    t=bytes(b[:n+6]).upper().decode('latin1')
    for k,w in KW:
        if w in t[:n-1+len(w)]: return k
    return 0
class S3M:
    def __init__(s,d):
        s.d=d; h=d[:0x60]; nord,nins,npat=struct.unpack('<HHH',h[0x20:0x26])
        s.ords=list(d[0x60:0x60+nord]); o=0x60+nord
        ipp=struct.unpack('<%dH'%nins,d[o:o+2*nins]); o+=2*nins; s.ppp=struct.unpack('<%dH'%npat,d[o:o+2*npat])
        s.speed=h[0x31] or 6; s.tempo=h[0x32] if h[0x32]>=33 else 125; s.en=[h[0x40+i]<16 for i in range(32)]
        ct=[min(65535,int(round(8363*2**((k-23.5)/12)))) for k in range(48)]
        s.info=[]
        for p in ipp:
            b=d[p*16:p*16+0x50]
            if b[0]!=1: s.info.append((0,0,0,1)); continue
            k=kind(b[0x30:]) or kind(b[1:])
            c2=struct.unpack('<I',b[0x20:0x24])[0]; c2=min(c2,65535)
            tr=sum(1 for t in ct if t<c2)-24
            ln=struct.unpack('<I',b[0x10:0x14])[0]
            if b[0x1F]&1: dur=255
            else:
                dv=max(1,(c2 or 8363)//50); l=min(ln,0xFFFF) if ln<0x10000 else 0xFFFF
                dur=l//dv; dur=254 if dur>=255 else dur; dur=dur or 1
            s.info.append((k,tr,min(b[0x1C],64),dur))
        s.chnote=[255]*32; s.chins=[0]*32; s.chvol=[0]*32; s.chdur=[0]*32; s.chseq=[0]*32; s.seqc=0
        s.pos=0; s.ppos=0; s.tcnt=1; s.tacc=0; s.ended=False; s.events=[]; s.drums=[]
        s.ldpat()
    def ldpat(s):
        while True:
            if s.pos>=len(s.ords) or s.ords[s.pos]==255: s.ended=True; return
            if s.ords[s.pos]==254: s.pos+=1; continue
            break
        p=s.ords[s.pos]
        if p>=len(s.ppp) or s.ppp[p]==0: s.rows=[[] for _ in range(64)]
        else:
            o=s.ppp[p]*16; ln=struct.unpack('<H',s.d[o:o+2])[0]; b=s.d[o+2:o+2+ln]; i=0; s.rows=[]
            for r in range(64):
                row=[]
                while i<len(b) and b[i]:
                    w=b[i]; i+=1; ev=[w&31,None,0,None,0,0]
                    if w&32: ev[1]=b[i]; ev[2]=b[i+1]; i+=2
                    if w&64: ev[3]=b[i]; i+=1
                    if w&128: ev[4]=b[i]; ev[5]=b[i+1]; i+=2
                    row.append(ev)
                i+=1; s.rows.append(row)
        s.row=0
    def field(s):
        s.tacc=min(255,s.tacc+s.tempo)
        while s.tacc>=125:
            s.tacc-=125; s.stick()
            if s.ended: return False
        for c in range(32):
            if s.chnote[c]!=255 and s.chdur[c]!=255:
                s.chdur[c]-=1
                if s.chdur[c]==0: s.chnote[c]=255
        return True
    def stick(s):
        s.tcnt-=1
        if s.tcnt: return
        s.tcnt=s.speed; brk=0; jmp=None
        for ch,note,ins,vol,cmd,info in s.rows[s.row]:
            if ch<32 and s.en[ch]:
                if ins: s.chins[ch]=ins; s.chvol[ch]=s.info[ins-1][2]
                if vol is not None: s.chvol[ch]=min(vol,64)
                if note is not None and note!=255:
                    if note==254: s.chnote[ch]=255
                    else:
                        n=(note>>4)*12+(note&15)-12; k,tr,v,dur=s.info[max(1,s.chins[ch])-1]
                        if k: s.drums.append(k)
                        else:
                            n=max(0,min(95,n+tr)); s.chnote[ch]=n; s.seqc=(s.seqc+1)&255; s.chseq[ch]=s.seqc
                            if dur!=255:
                                while n>=48: n-=12; dur>>=1
                                while n<36:
                                    n+=12; dur<<=1
                                    if dur>255: dur=254; break
                                dur=dur or 1
                            s.chdur[ch]=dur
            if cmd==1 and info: s.speed=s.tcnt=info
            elif cmd==20 and info>=33: s.tempo=info
            elif cmd==2: jmp=info
            elif cmd==3:
                r=(info>>4)*10+(info&15); brk=(r if r<64 else 0)+1
        if jmp is not None:
            s.pos=jmp
            if jmp<=s.ppos: s.ended=True; return
            s.ppos=s.pos; s.ldpat(); return
        if brk: s.pos+=1
        else:
            s.row+=1
            if s.row<64: return
            s.pos+=1
        s.ppos=s.pos; s.ldpat()
        if s.ended: return
        if brk>1: s.row=brk-1
    def voices(s):
        act=[c for c in range(32) if s.chnote[c]!=255]
        if not act: return (255,255,255)
        hi=max(act,key=lambda c:(s.chnote[c],-c)); lo=min(act,key=lambda c:(s.chnote[c],c))
        # match Z80 tie rules: hi = first channel with max note; lo = first channel with min
        mx=max(s.chnote[c] for c in act); mn=min(s.chnote[c] for c in act)
        hi=[c for c in act if s.chnote[c]==mx][0]; lo=[c for c in act if s.chnote[c]==mn][0]
        rest=[c for c in act if c not in (hi,lo)]
        mid=255
        if rest:
            best=min(rest,key=lambda c:((s.seqc-s.chseq[c])&255,c)); mid=s.chnote[best]
        h=s.chnote[hi]; l=s.chnote[lo] if s.chnote[lo]!=h else 255
        return (h,l,mid)
if __name__=='__main__':
    d=mk_s3m(); open('out/TEST.S3M','wb').write(d); s=S3M(d); n=0
    while s.field(): n+=1
    print('fields',n,'drums',s.drums,'size',len(d))
