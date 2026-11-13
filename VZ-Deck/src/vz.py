# VZ300 + BennVenn SD loader test harness (ROM calls trapped, SD emulated at SPI byte level)
import struct
from z80 import Z80
class FatImg:
    def __init__(s,spc=8,reserved=32,fatsz=64):
        s.spc,s.res,s.fatsz=spc,reserved,fatsz; s.sec={}; s.fat=[0x0FFFFFF8,0x0FFFFFFF,0x0FFFFFFF]; s.data0=reserved+2*fatsz
        b=bytearray(512); b[0:3]=b'\xEB\x58\x90'; b[3:11]=b'MSDOS5.0'; struct.pack_into('<HBHB',b,11,512,spc,reserved,2)
        struct.pack_into('<I',b,0x24,fatsz); struct.pack_into('<I',b,0x2C,2); b[510:512]=b'\x55\xAA'; s.sec[0]=bytes(b)
        s.dirs={2:[]}   # cluster -> list of 32-byte entries
    def alloc(s,n):
        first=len(s.fat)
        for i in range(n): s.fat.append(first+i+1 if i<n-1 else 0x0FFFFFFF)
        return first
    def putdata(s,clus,data):
        lba=s.data0+(clus-2)*s.spc
        for i in range(0,len(data),512): s.sec[lba+i//512]=bytes(data[i:i+512].ljust(512,b'\0'))
    @staticmethod
    def ent(name,attr,clus,size,date=(2026,11,6),time=(12,30)):
        n,_,e=name.partition('.'); nm=(n.ljust(8)+e.ljust(3)).encode() if name not in('.','..') else name.ljust(11).encode()
        d=((date[0]-1980)<<9)|(date[1]<<5)|date[2] if date else 0; t=(time[0]<<11)|(time[1]<<5)
        b=bytearray(32); b[0:11]=nm; b[11]=attr; struct.pack_into('<H',b,0x14,clus>>16); struct.pack_into('<HHH',b,0x16,t,d,clus&0xFFFF); struct.pack_into('<I',b,0x1C,size); return bytes(b)
    def addfile(s,dirc,name,data,attr=0x20,**kw):
        n=max(1,-(-len(data)//(512*s.spc))) if data else 0
        c=s.alloc(n) if n else 0
        if n: s.putdata(c,data)
        s.dirs[dirc].append(s.ent(name,attr,c,len(data),**kw)); return c
    def addraw(s,dirc,raw): s.dirs[dirc].append(raw)
    def mkdir(s,dirc,name,**kw):
        c=s.alloc(1); s.dirs[c]=[s.ent('.',0x10,c,0),s.ent('..',0x10,0 if dirc==2 else dirc,0)]
        s.dirs[dirc].append(s.ent(name,0x10,c,0,**kw)); s.dirclus=getattr(s,'dirclus',{}); return c
    def finish(s):
        # write directories (extend chains as needed)
        for c,ents in s.dirs.items():
            data=b''.join(ents); per=512*s.spc; need=max(1,-(-(len(data))//per))
            chain=[c]
            while len(chain)<need:
                n=len(s.fat); s.fat.append(0x0FFFFFFF); s.fat[chain[-1]]=n; chain.append(n)
            if c==2: s.fat[2]=chain[1] if len(chain)>1 else 0x0FFFFFFF
            data=data.ljust(need*per,b'\0')
            for i,cl in enumerate(chain): s.putdata(cl,data[i*per:(i+1)*per])
        fb=b''.join(struct.pack('<I',x) for x in s.fat).ljust(s.fatsz*512,b'\0')
        for k in range(2):
            for i in range(s.fatsz): s.sec[s.res+k*s.fatsz+i]=fb[i*512:(i+1)*512]
class SD:
    def __init__(s,img,maxlba=None):
        s.img=img; s.cmd=None; s.q=[]; s.last=0xFF; s.wr=None; s.reads=[]; s.maxlba=maxlba; s.hung=False
    def out(s,v):
        if s.wr is not None:
            lba,buf,st=s.wr
            if st==0:
                if v==0xFE: s.wr=(lba,buf,1)
                s.last=s.q.pop(0) if s.q else 0xFF; return
            buf.append(v)
            if len(buf)==514:
                s.img.sec[lba]=bytes(buf[:512]); s.wr=None; s.q=[0x05,0x00,0xFF]
            s.last=0xFF; return
        if s.cmd is not None:
            s.cmd.append(v); s.last=0xFF
            if len(s.cmd)==6: s.do(s.cmd); s.cmd=None
            return
        if v&0xC0==0x40 and not s.q: s.cmd=[v]; s.last=0xFF; return
        s.last=s.q.pop(0) if s.q else 0xFF
    def do(s,c):
        n=c[0]&0x3F; arg=(c[1]<<24)|(c[2]<<16)|(c[3]<<8)|c[4]
        if n==0: s.q=[0x01]
        elif n==8: s.q=[0x01,0,0,1,0xAA]
        elif n==55: s.q=[0x01]
        elif n==41: s.q=[0x00]
        elif n==58: s.q=[0x00,0xC0,0xFF,0x80,0x00]
        elif n==16: s.q=[0x00]
        elif n==17:
            s.reads.append(arg)
            if s.maxlba is not None and arg>s.maxlba: s.q=[0x40]; s.hung=True   # out of range: no data token ever
            else: s.q=[0x00,0xFF,0xFE]+list(s.img.sec.get(arg,bytes(512)))+[0,0]
        elif n==24: s.q=[0x00]; s.wr=(arg,[],0)
        else: s.q=[0x04]
    def inp(s): return s.last
ROWS=[0xFE,0xFD,0xFB,0xF7,0xEF,0xDF,0xBF,0x7F]
KEYS={'UP':(0xEF,1),'DOWN':(0xEF,4),'LEFT':(0xEF,5),'RIGHT':(0xEF,3),'RET':(0xBF,2),'B':(0xFB,0),'C':(0xFB,3),'Q':(0xFE,4)}
class VZ:
    def __init__(s,dos,flash,img,maxlba=None):
        z=s.z=Z80(); s.dos=dos; s.flash=flash; s.sd=SD(img,maxlba); s.ramsel=1; s.con=''; s.inkeys=[]; s.held=None; s.script=[]; s.vs=0; s.stop=None; s.frames=0; s.nojoyhw=False; s.spk=None; s.tsync=False; s.prn=None
        z.mem[0x4000:0x4000+len(dos)]=dos
        def rd(a):
            if 0x4000<=a<0x6000 and not s.ramsel: return s.flash[a-0x4000] if a-0x4000<len(s.flash) else 0xFF
            if 0x6800<=a<0x7000:
                v=0x7F
                if s.held in KEYS:
                    row,bit=KEYS[s.held]
                    if not a&(~row&0xFF): v&=~(1<<bit)
                if s.tsync:
                    ph=z.t%70630
                    if ph<12740: v&=0x7F
                    else: v|=0x80
                    f=z.t//70630
                    if f!=s.frames:
                        s.frames=f; s.tick()
                    return v&0xFF
                s.vs+=1
                if s.vs%40<4: v&=0x7F
                else: v|=0x80
                if s.vs%40==0:
                    s.frames+=1; s.tick()
                return v&0xFF
            return z.mem[a]
        def wr(a,v):
            if a<0x4000: return
            if 0x4000<=a<0x6000 and not s.ramsel: return
            if 0x6800<=a<0x7000:
                if s.spk is not None: s.spk.append((z.t,v))
                return
            z.mem[a]=v
        z.rd=rd; z.wr=wr
        def outp(p,v):
            p&=0xFF
            if p==0x39: s.sd.out(v)
            elif p==0x37: s.ramsel=v&1
            elif p==0x0E and s.prn is not None: s.prn.append((z.t,v))
        def inp(p):
            p&=0xFF
            if p==0x39: return s.sd.inp()
            if s.nojoyhw: return 0x00
            J={'JUP':0,'JDOWN':1,'JLEFT':2,'JRIGHT':3}
            if p==0x2C: return 0xFF & ~(1<<J[s.held]) if s.held in J else 0xFF
            if p==0x2E: return 0xEF if s.held=='JFIRE' else 0xFF
            return 0xFF
        z.outp=outp; z.inp=inp; s.cur=0
    def tick(s):
        # script: list of (key or None, frames)
        if s.script:
            k,n=s.script[0]; s.held=k; n-=1
            if n<=0: s.script.pop(0)
            else: s.script[0]=(k,n)
        else: s.held=None
    def putch(s,c):
        s.con+=chr(c) if c!=13 else '\n'
        m=s.z.mem
        if c==13: s.cur=(s.cur//32+1)*32
        else: m[0x7000+s.cur]=c&0x3F; s.cur+=1
        if s.cur>=512:
            m[0x7000:0x71E0]=m[0x7020:0x7200]; m[0x71E0:0x7200]=b'\x20'*32; s.cur-=32
    def trap(s):
        z=s.z; pc=z.pc
        if pc==0x01C9:
            z.mem[0x7000:0x7200]=b'\x20'*512; s.cur=0
        elif pc==0x28A7:
            a=z.hl()
            while z.rd(a): s.putch(z.rd(a)); a+=1
        elif pc==0x033A: s.putch(z.r[7])
        elif pc==0x2EF4: z.r[7]=s.inkeys.pop(0) if s.inkeys else 0
        elif pc==0x06A0: s.stop='BASIC'; return
        elif pc==0x0000:
            s.con+='[RESET]'; z.pc=0x4004; return
        elif pc in(0x3450,0x1A19): pass
        else: s.stop='ROM %04X'%pc; return
        z.pc=z.pop()
    def run(s,pc,maxsteps=3000000,until=None):
        z=s.z; z.pc=pc; n=0
        while n<maxsteps and not s.stop:
            if z.pc<0x4000: s.trap(); continue
            if until and until(s): return 'until'
            z.step(); n+=1
        return s.stop or 'maxsteps'
    def screen(s):
        out=[]
        for r in range(16):
            line=''
            for c in s.z.mem[0x7000+r*32:0x7020+r*32]:
                if c>=0x80: line+='#'
                else:
                    ch=c&0x3F; ch=ch+0x40 if ch<0x20 else ch
                    line+=chr(ch).lower() if c&0x40 and chr(ch).isalpha() else (chr(ch) if not c&0x40 else {' ':'_'}.get(chr(ch),chr(ch)))
            out.append(line)
        return '\n'.join(out)
