import struct
from s3mref import kind
def mk_xm(long=False,nch=6):
    # instruments: (name, samplename, length, loop, vol, relnote, 16bit) ; None = no samples
    insts=[('Piano','pno',20000,1,48,0,0),('Pluck','',4000,0,64,12,0),('Kick','bd',3000,0,64,0,0),('Snare 2','',3000,0,60,0,1),
           ('Closed HiHat','',800,0,40,0,0),('Bass','',6000,0,64,-12,1),None,('lead','',9000,0,50,-3,0)]
    def pat(rows,nrows):
        b=bytearray()
        for r in range(nrows):
            ev={e[0]:e for e in rows.get(r,[])}
            for c in range(nch):
                if c not in ev: b.append(0x80); continue
                _,note,ins,vol,eff,par=ev[c]
                if r%7==3:          # some entries stored unpacked
                    b+=bytes([note or 0,ins or 0,vol or 0,eff or 0,par or 0]); continue
                f=0x80; x=bytearray()
                for bit,v in enumerate((note,ins,vol,eff,par)):
                    if v: f|=1<<bit; x.append(v)
                b.append(f); b+=x
        return b
    C4=49
    p0={0:[(0,C4,1,0,0x0F,4),(1,C4-24,6,0,0,0),(2,C4,3,0,0,0)],
        2:[(3,C4+4,2,0x30,0,0),(4,C4+12,2,0,0,0)],
        4:[(0,C4+7,1,0,0,0),(2,C4,4,0,0,0),(5,C4+24,2,0,0x0C,20)],
        6:[(1,C4-19,6,0,0,0),(2,C4,5,0,0,0),(3,C4,7,0,0,0)],
        8:[(0,97,0,0,0,0),(3,C4+9,2,0,0,0),(5,C4-7,8,0,0,0)],
        10:[(0,C4+12,1,0x24,0x0F,150)],
        12:[(1,C4-29,6,0,0,0),(2,C4,3,0,0,0),(4,0,8,0,0,0)],
        16:[(0,C4+2,1,0,0x0D,0x10)]}       # break to row 10 of next pattern
    p1={0:[(0,C4-12,1,0,0,0)],
        10:[(0,C4+11,2,0,0,0),(1,C4+3-12,6,0,0,0),(2,C4,5,0,0,0)],
        12:[(3,C4+14,2,0,0,0),(5,C4+2,8,0x50,0,0)],
        14:[(0,C4,1,0,0x0F,3)],
        20:[(1,C4-24,6,0,0,0),(0,C4+4,1,0,0,0)],
        24:[(0,0,0,0,0x0B,0)]}             # jump back to order 0: the end
    pats=[(p0,64),(p1,32),({},48)]
    orders=[0,2,1,0] if not long else [0,1]*12
    if long: p1[24]=[]
    h=bytearray(b'Extended Module: '+b'VZ-DECK XM TEST'.ljust(20,b'\0')+b'\x1a'+b'FastTracker v2.00   '+b'\x04\x01')
    hd=bytearray(276-4)
    struct.pack_into('<HHHHHHHH',hd,0,len(orders),0,nch,len(pats),len(insts),1,6,125)
    hd[16:16+len(orders)]=bytes(orders)
    body=h+struct.pack('<I',276)+hd
    for p,nr in pats:
        b=pat(p,nr) if p else b''
        body+=struct.pack('<IBHH',9,0,nr,len(b))+b
    for ins in insts:
        if ins is None:
            ih=bytearray(29); struct.pack_into('<I',ih,0,29); ih[4:26]=b'empty'.ljust(22,b'\0'); body+=ih; continue
        name,sn,ln,lp,vol,rel,b16=ins
        ih=bytearray(263); struct.pack_into('<I',ih,0,263); ih[4:26]=name.encode().ljust(22,b'\0')
        ns=2 if name=='Piano' else 1
        struct.pack_into('<HI',ih,27,ns,40); body+=ih
        tot=0
        for k in range(ns):
            sh=bytearray(40); bl=ln*(2 if b16 else 1)
            struct.pack_into('<III',sh,0,bl,0,bl if lp else 0); sh[12]=vol; sh[14]=(1 if lp else 0)|(16 if b16 else 0)
            sh[16]=rel&255; sh[18:40]=sn.encode().ljust(22,b'\0'); body+=sh; tot+=bl
        body+=bytes(tot)
    return bytes(body)
class XM:
    def __init__(s,d):
        s.d=d; hs=struct.unpack('<I',d[60:64])[0]
        nord,rst,nch,npat,nins,fl,spd,bpm=struct.unpack('<8H',d[64:80])
        s.nch=nch; s.ords=list(d[80:80+min(nord,255)])
        s.speed=spd or 6; s.tempo=bpm if bpm>=32 else 125
        o=60+hs; s.pats=[]
        for p in range(min(npat,255)):
            hl,pk,nr,ps=struct.unpack('<IBHH',d[o:o+9]); s.pats.append((o+hl,nr,ps)); o+=hl+ps
        s.info=[]
        for i in range(min(nins,128)):
            isz=struct.unpack('<I',d[o:o+4])[0]; ns=struct.unpack('<H',d[o+27:o+29])[0]
            if ns==0: s.info.append((0,0,0,1)); o+=isz; continue
            shs=struct.unpack('<I',d[o+29:o+33])[0]; so=o+isz; sh=d[so:so+40]
            k=kind(d[o+4:o+26]+bytes(10)) or kind(sh[18:40]+bytes(10))
            ln=struct.unpack('<I',sh[0:4])[0]
            if sh[14]&16: ln>>=1
            if sh[14]&3: dur=255
            else:
                l=min(ln,0xFFFF); dur=l//167; dur=254 if dur>=255 else dur; dur=dur or 1
            rel=sh[16]-256 if sh[16]>127 else sh[16]
            s.info.append((k,rel,min(sh[12],64),dur))
            tot=sum(struct.unpack('<I',d[so+j*shs:so+j*shs+4])[0] for j in range(ns))
            o=so+ns*shs+tot
        s.chnote=[255]*32; s.chins=[0]*32; s.chvol=[0]*32; s.chdur=[0]*32; s.chseq=[0]*32; s.seqc=0
        s.pos=0; s.ppos=0; s.tcnt=1; s.tacc=0; s.ended=False; s.drums=[]
        s.ldpat()
    def ldpat(s):
        if s.pos>=len(s.ords): s.ended=True; return
        p=s.ords[s.pos]
        if p>=len(s.pats): s.nrows=64; s.rows=[[] for _ in range(64)]
        else:
            o,nr,ps=s.pats[p]; s.nrows=nr; b=s.d[o:o+ps]; i=0; s.rows=[]
            for r in range(nr):
                row=[]
                for c in range(s.nch):
                    if ps==0: continue
                    f=b[i]; i+=1; ev=[c,0,0,0,0,0]
                    if f&0x80:
                        for bit in range(5):
                            if f>>bit&1: ev[1+bit]=b[i]; i+=1
                    else:
                        ev[1]=f; ev[2:6]=b[i:i+4]; i+=4
                    row.append(ev)
                s.rows.append(row)
        s.row=0
    field=None
    def stick(s):
        s.tcnt-=1
        if s.tcnt: return
        s.tcnt=s.speed; brk=0; jmp=None
        for ch,note,ins,vol,cmd,info in s.rows[s.row]:
            if ch<32:
                if ins: s.chins[ch]=ins; s.chvol[ch]=s.info[ins-1][2] if ins<=len(s.info) else 0
                if 0x10<=vol<=0x50: s.chvol[ch]=vol-0x10
                if cmd==0x0C: s.chvol[ch]=min(info,64)
                if note==97: s.chnote[ch]=255
                elif 1<=note<=96:
                    ci=max(1,s.chins[ch]); k,tr,v,dur=s.info[ci-1] if ci<=len(s.info) else (0,0,0,1)
                    n=note-13
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
            if cmd==0x0F and info:
                if info<32: s.speed=s.tcnt=info
                else: s.tempo=info
            elif cmd==0x0B: jmp=info
            elif cmd==0x0D:
                r=(info>>4)*10+(info&15); brk=r+1
        if jmp is not None:
            s.pos=jmp
            if jmp<=s.ppos: s.ended=True; return
            s.ppos=s.pos; s.ldpat(); return
        if brk: s.pos+=1
        else:
            s.row+=1
            if s.row<s.nrows: return
            s.pos+=1
        s.ppos=s.pos; s.ldpat()
        if s.ended: return
        if brk>1: s.row=brk-1 if brk-1<s.nrows else 0
import s3mref
XM.field=s3mref.S3M.field; XM.voices=s3mref.S3M.voices
if __name__=='__main__':
    d=mk_xm(); open('out/TEST.XM','wb').write(d); s=XM(d); n=0
    while s.field(): n+=1
    print('fields',n,'drums',s.drums,'size',len(d),s.info)
