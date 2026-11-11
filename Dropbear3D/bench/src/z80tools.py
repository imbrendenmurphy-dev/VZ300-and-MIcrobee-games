"""Tiny Z80 assembler (subset) + T-state-counting simulator (same subset)."""
import re
R8={'b':0,'c':1,'d':2,'e':3,'h':4,'l':5,'(hl)':6,'a':7}
R16={'bc':0,'de':1,'hl':2,'sp':3}
R16P={'bc':0,'de':1,'hl':2,'af':3}
CC={'nz':0,'z':1,'nc':2,'c':3,'po':4,'pe':5,'p':6,'m':7}
ALU={'add':0,'adc':1,'sub':2,'sbc':3,'and':4,'xor':5,'or':6,'cp':7}
ROT={'rlc':0,'rrc':1,'rl':2,'rr':3,'sla':4,'sra':5,'srl':7}
SIMPLE={'nop':[0],'rlca':[7],'rrca':[0xF],'rla':[0x17],'rra':[0x1F],'cpl':[0x2F],'scf':[0x37],'ccf':[0x3F],
 'halt':[0x76],'exx':[0xD9],'di':[0xF3],'ei':[0xFB],'neg':[0xED,0x44],'ldi':[0xED,0xA0],'ldir':[0xED,0xB0],'ret':[0xC9]}
def is_mem(a): return a.startswith('(') and a.endswith(')') and a not in('(hl)','(bc)','(de)')

def assemble(src, syms):
    lines=[]
    for raw in src.split('\n'):
        s=raw.split(';')[0].rstrip()
        if not s.strip(): continue
        label=None
        m=re.match(r'^(\w+):\s*(.*)$',s)
        if m: label,s=m.group(1),m.group(2)
        s=s.strip()
        op=None;args=[]
        if s:
            parts=s.split(None,1); op=parts[0].lower()
            if len(parts)>1: args=[a.strip() for a in parts[1].split(',')]
        lines.append((label,op,args,raw))
    def ev(e,final):
        e=re.sub(r'\$([0-9A-Fa-f]+)',r'0x\1',e)
        try: return int(eval(e,{},syms))
        except NameError:
            if final: raise
            return 0
    out={}
    for final in (False,True):
        pc=0
        for label,op,args,raw in lines:
            if op=='equ': syms[label]=ev(args[0],final); continue
            if label: syms[label]=pc
            if op is None: continue
            if op=='org': pc=ev(args[0],final); continue
            V=lambda e: ev(e[1:-1] if is_mem(e) else e,final)
            w=lambda n:[n&255,(n>>8)&255]
            a=[x if x.lower() not in R8 and x.lower() not in R16 and x.lower() not in CC and x.lower() not in ('af',"af'") else x.lower() for x in args]
            b=None
            try:
                if op in SIMPLE and not a: b=SIMPLE[op]
                elif op=='db': b=[V(x)&255 for x in a]
                elif op=='dw': b=sum([w(V(x)) for x in a],[])
                elif op=='ds': b=[0]*V(a[0])
                elif op=='ld':
                    d,s=a
                    if d in R8 and s in R8: assert not(d==s=='(hl)'); b=[0x40|R8[d]<<3|R8[s]]
                    elif d=='a' and s=='(bc)': b=[0x0A]
                    elif d=='a' and s=='(de)': b=[0x1A]
                    elif d=='(bc)' and s=='a': b=[0x02]
                    elif d=='(de)' and s=='a': b=[0x12]
                    elif d=='a' and is_mem(s): b=[0x3A]+w(V(s))
                    elif is_mem(d) and s=='a': b=[0x32]+w(V(d))
                    elif d=='hl' and is_mem(s): b=[0x2A]+w(V(s))
                    elif is_mem(d) and s=='hl': b=[0x22]+w(V(d))
                    elif d in R16 and is_mem(s): b=[0xED,0x4B|R16[d]<<4]+w(V(s))
                    elif is_mem(d) and s in R16: b=[0xED,0x43|R16[s]<<4]+w(V(d))
                    elif d=='sp' and s=='hl': b=[0xF9]
                    elif d in R16: assert not is_mem(s); b=[0x01|R16[d]<<4]+w(V(s))
                    elif d in R8: assert not is_mem(s) and s not in R16; b=[0x06|R8[d]<<3,V(s)&255]
                elif op in ALU:
                    if op in('add','adc','sbc') and a[0]=='hl':
                        r=R16[a[1]]; b=[0x09|r<<4] if op=='add' else ([0xED,0x4A|r<<4] if op=='adc' else [0xED,0x42|r<<4])
                    else:
                        s=a[-1]
                        if len(a)==2: assert a[0]=='a'
                        if s in R8: b=[0x80|ALU[op]<<3|R8[s]]
                        else: assert not is_mem(s); b=[0xC6|ALU[op]<<3,V(s)&255]
                elif op in('inc','dec'):
                    i=0 if op=='inc' else 1
                    if a[0] in R8: b=[0x04|i|R8[a[0]]<<3]
                    else: b=[(0x03 if i==0 else 0x0B)|R16[a[0]]<<4]
                elif op=='jp':
                    if a==['(hl)']: b=[0xE9]
                    elif len(a)==1: b=[0xC3]+w(V(a[0]))
                    else: b=[0xC2|CC[a[0]]<<3]+w(V(a[1]))
                elif op in('jr','djnz'):
                    t=V(a[-1]); o=t-(pc+2)
                    if final: assert -128<=o<=127, 'jr range'
                    if op=='djnz': b=[0x10,o&255]
                    elif len(a)==1: b=[0x18,o&255]
                    else: assert CC[a[0]]<4; b=[0x20|CC[a[0]]<<3,o&255]
                elif op=='call':
                    b=([0xCD]+w(V(a[0]))) if len(a)==1 else ([0xC4|CC[a[0]]<<3]+w(V(a[1])))
                elif op=='ret': b=[0xC0|CC[a[0]]<<3]
                elif op=='push': b=[0xC5|R16P[a[0]]<<4]
                elif op=='pop': b=[0xC1|R16P[a[0]]<<4]
                elif op=='ex':
                    b=[0xEB] if a==['de','hl'] else None
                elif op in ROT: b=[0xCB,ROT[op]<<3|R8[a[0]]]
                elif op in('bit','res','set'):
                    b=[0xCB,{'bit':0x40,'res':0x80,'set':0xC0}[op]|V(a[0])<<3|R8[a[1]]]
                assert b is not None
            except Exception as e:
                raise SystemExit(f'ASM error: {raw!r}: {e!r}')
            if final:
                for i,v in enumerate(b): out[pc+i]=v
            pc+=len(b)
    return out

class Z80:
    def __init__(s,mem):
        s.m=mem; s.r=[0]*8; s.r2=[0]*8; s.fc=s.fz=s.fs=0; s.sp=0; s.pc=0; s.t=0
        s.latch=0; s.keys={}; s.ioreads=[]; s.FIELD=70630; s.SYNC=12740; s.logio=False
    def rd(s,a):
        if 0x6800<=a<0x7000:
            if s.logio: s.ioreads.append(s.t)
            v=0x7F
            for row in range(8):
                if not (a>>row)&1: v&=s.keys.get(row,0x7F)
            return v|(0 if (s.t%s.FIELD)<s.SYNC else 0x80)
        return s.m[a]
    def wr(s,a,v):
        if a>=0x7000: s.m[a]=v
        elif a>=0x6800: s.latch=v
    def g(s,i): return s.rd(s.r[4]<<8|s.r[5]) if i==6 else s.r[i]
    def p(s,i,v):
        if i==6: s.wr(s.r[4]<<8|s.r[5],v)
        else: s.r[i]=v
    def rp(s,i): return s.sp if i==3 else s.r[i*2]<<8|s.r[i*2+1]
    def setrp(s,i,v):
        v&=0xFFFF
        if i==3: s.sp=v
        else: s.r[i*2]=v>>8; s.r[i*2+1]=v&255
    def imm(s): v=s.m[s.pc]; s.pc=(s.pc+1)&0xFFFF; return v
    def imm16(s): return s.imm()|s.imm()<<8
    def cond(s,c): return [not s.fz,s.fz,not s.fc,s.fc,None,None,not s.fs,s.fs][c]
    def zs(s,v): s.fz=int(v==0); s.fs=v>>7
    def alu(s,y,v):
        a=s.r[7]
        if y==0: r=a+v
        elif y==1: r=a+v+s.fc
        elif y in(2,7): r=a-v
        elif y==3: r=a-v-s.fc
        elif y==4: r=a&v
        elif y==5: r=a^v
        else: r=a|v
        s.fc=int(r>255 or r<0) if y in(0,1,2,3,7) else 0
        r&=255; s.zs(r)
        if y!=7: s.r[7]=r
    def push(s,v): s.sp=(s.sp-2)&0xFFFF; s.wr(s.sp,v&255); s.wr(s.sp+1,v>>8)
    def pop(s): v=s.m[s.sp]|s.m[(s.sp+1)&0xFFFF]<<8; s.sp=(s.sp+2)&0xFFFF; return v
    def step(s):
        op=s.imm(); x=op>>6; y=(op>>3)&7; z=op&7; r=s.r
        if x==1:
            assert op!=0x76,'halt'
            s.p(y,s.g(z)); s.t+=7 if 6 in(y,z) else 4
        elif x==2: s.alu(y,s.g(z)); s.t+=7 if z==6 else 4
        elif x==0:
            if z==0:
                if y==0: s.t+=4
                elif y==2:
                    o=s.imm(); r[0]=(r[0]-1)&255
                    if r[0]: s.pc=(s.pc+(o^128)-128)&0xFFFF; s.t+=13
                    else: s.t+=8
                elif y==3: o=s.imm(); s.pc=(s.pc+(o^128)-128)&0xFFFF; s.t+=12
                elif y>=4:
                    o=s.imm()
                    if s.cond(y-4): s.pc=(s.pc+(o^128)-128)&0xFFFF; s.t+=12
                    else: s.t+=7
                else: raise Exception('op %02x'%op)
            elif z==1:
                if y&1==0: s.setrp(y>>1,s.imm16()); s.t+=10
                else:
                    v=s.rp(2)+s.rp(y>>1); s.fc=int(v>0xFFFF); s.setrp(2,v); s.t+=11
            elif z==2:
                if y==0: s.wr(s.rp(0),r[7]); s.t+=7
                elif y==1: r[7]=s.rd(s.rp(0)); s.t+=7
                elif y==2: s.wr(s.rp(1),r[7]); s.t+=7
                elif y==3: r[7]=s.rd(s.rp(1)); s.t+=7
                elif y==4: a=s.imm16(); s.wr(a,r[5]); s.wr(a+1,r[4]); s.t+=16
                elif y==5: a=s.imm16(); r[5]=s.rd(a); r[4]=s.rd(a+1); s.t+=16
                elif y==6: s.wr(s.imm16(),r[7]); s.t+=13
                else: r[7]=s.rd(s.imm16()); s.t+=13
            elif z==3: s.setrp(y>>1,s.rp(y>>1)+(1 if y&1==0 else -1)); s.t+=6
            elif z in(4,5):
                v=(s.g(y)+(1 if z==4 else -1))&255; s.p(y,v); s.zs(v); s.t+=11 if y==6 else 4
            elif z==6: s.p(y,s.imm()); s.t+=10 if y==6 else 7
            else:
                a=r[7]
                if y==0: s.fc=a>>7; a=((a<<1)|s.fc)&255
                elif y==1: s.fc=a&1; a=(a>>1)|(s.fc<<7)
                elif y==2: n=a>>7; a=((a<<1)|s.fc)&255; s.fc=n
                elif y==3: n=a&1; a=(a>>1)|(s.fc<<7); s.fc=n
                elif y==5: a^=255
                elif y==6: s.fc=1
                elif y==7: s.fc^=1
                else: raise Exception('daa')
                r[7]=a; s.t+=4
        else:
            if z==0:
                if s.cond(y): s.pc=s.pop(); s.t+=11
                else: s.t+=5
            elif z==1:
                if y&1==0:
                    assert y!=6; s.setrp(y>>1,s.pop()); s.t+=10
                elif y==1: s.pc=s.pop(); s.t+=10
                elif y==3: s.r,s.r2=s.r2,s.r; a=s.r[7]; s.r[7]=s.r2[7]; s.r2[7]=a; s.t+=4   # exx keeps A
                elif y==5: s.pc=s.rp(2); s.t+=4
                else: s.sp=s.rp(2); s.t+=6
            elif z==2:
                a=s.imm16()
                if s.cond(y): s.pc=a
                s.t+=10
            elif z==3:
                if y==0: s.pc=s.imm16(); s.t+=10
                elif y==1: s.cb()
                elif y==5: r[2],r[3],r[4],r[5]=r[4],r[5],r[2],r[3]; s.t+=4
                elif y in(6,7): s.t+=4
                else: raise Exception('op %02x'%op)
            elif z==4:
                a=s.imm16()
                if s.cond(y): s.push(s.pc); s.pc=a; s.t+=17
                else: s.t+=10
            elif z==5:
                if y&1==0: assert y!=6; s.push(s.rp(y>>1)); s.t+=11
                elif y==1: a=s.imm16(); s.push(s.pc); s.pc=a; s.t+=17
                elif y==5: s.ed()
                else: raise Exception('op %02x'%op)
            elif z==6: s.alu(y,s.imm()); s.t+=7
            else: raise Exception('rst')
    def cb(s):
        op=s.imm(); x=op>>6; y=(op>>3)&7; z=op&7; v=s.g(z)
        if x==0:
            c=s.fc
            if y==0: s.fc=v>>7; v=((v<<1)|s.fc)&255
            elif y==1: s.fc=v&1; v=(v>>1)|(s.fc<<7)
            elif y==2: s.fc=v>>7; v=((v<<1)|c)&255
            elif y==3: s.fc=v&1; v=(v>>1)|(c<<7)
            elif y==4: s.fc=v>>7; v=(v<<1)&255
            elif y==5: s.fc=v&1; v=(v>>1)|(v&128)
            elif y==7: s.fc=v&1; v>>=1
            else: raise Exception('sll')
            s.zs(v); s.p(z,v); s.t+=15 if z==6 else 8
        elif x==1: s.fz=int(not (v>>y)&1); s.t+=12 if z==6 else 8
        else:
            v=(v&~(1<<y)) if x==2 else (v|1<<y); s.p(z,v&255); s.t+=15 if z==6 else 8
    def ed(s):
        op=s.imm(); r=s.r
        if op&0xC7==0x43:
            i=(op>>4)&3; a=s.imm16()
            if op&8: s.setrp(i,s.rd(a)|s.rd(a+1)<<8)
            else: v=s.rp(i); s.wr(a,v&255); s.wr(a+1,v>>8)
            s.t+=20
        elif op&0xC7==0x42:
            i=(op>>4)&3; h=s.rp(2); v=s.rp(i)
            n=h+v+s.fc if op&8 else h-v-s.fc
            s.fc=int(n>0xFFFF or n<0); n&=0xFFFF; s.fz=int(n==0); s.fs=n>>15; s.setrp(2,n); s.t+=15
        elif op==0x44:
            a=r[7]; s.fc=int(a!=0); a=(-a)&255; s.zs(a); r[7]=a; s.t+=8
        elif op in(0xA0,0xB0):
            while True:
                s.wr(s.rp(1),s.rd(s.rp(2))); s.setrp(2,s.rp(2)+1); s.setrp(1,s.rp(1)+1); s.setrp(0,s.rp(0)-1)
                if op==0xA0 or s.rp(0)==0: s.t+=16; break
                s.t+=21
        else: raise Exception('ED %02x'%op)
