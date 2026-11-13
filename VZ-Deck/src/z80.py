# compact Z80 core (documented instructions), enough for DOS + shell testing
S_,Z_,H_,P_,N_,C_=0x80,0x40,0x10,0x04,0x02,0x01
PAR=[(bin(i).count('1')%2==0)*P_ for i in range(256)]
SZ=[(i&0x80)|((i==0)*Z_) for i in range(256)]

def _mk():
    T=[4]*256
    for o,v in {0x01:10,0x02:7,0x03:6,0x06:7,0x09:11,0x0A:7,0x0B:6,0x0E:7,0x10:8,0x11:10,0x12:7,0x13:6,0x16:7,0x18:12,0x19:11,0x1A:7,0x1B:6,0x1E:7,
        0x20:7,0x21:10,0x22:16,0x23:6,0x26:7,0x28:7,0x29:11,0x2A:16,0x2B:6,0x2E:7,0x30:7,0x31:10,0x32:13,0x33:6,0x34:11,0x35:11,0x36:10,0x38:7,0x39:11,0x3A:13,0x3B:6,0x3E:7,
        0xC0:5,0xC1:10,0xC2:10,0xC3:10,0xC4:10,0xC5:11,0xC6:7,0xC7:11,0xC8:5,0xC9:10,0xCA:10,0xCC:10,0xCD:17,0xCE:7,0xCF:11,
        0xD0:5,0xD1:10,0xD2:10,0xD3:11,0xD4:10,0xD5:11,0xD6:7,0xD7:11,0xD8:5,0xD9:4,0xDA:10,0xDB:11,0xDC:10,0xDE:7,0xDF:11,
        0xE0:5,0xE1:10,0xE2:10,0xE3:19,0xE4:10,0xE5:11,0xE6:7,0xE7:11,0xE8:5,0xE9:4,0xEA:10,0xEB:4,0xEC:10,0xEE:7,0xEF:11,
        0xF0:5,0xF1:10,0xF2:10,0xF3:4,0xF4:10,0xF5:11,0xF6:7,0xF7:11,0xF8:5,0xF9:6,0xFA:10,0xFB:4,0xFC:10,0xFE:7,0xFF:11}.items(): T[o]=v
    for o in range(0x40,0xC0):
        if o&7==6 or (o<0x80 and (o>>3)&7==6): T[o]=7
    T[0x76]=4
    return T
CYC=_mk()
class Z80:
    def __init__(s):
        s.r=[0]*8  # B C D E H L (F) A  -> index 6 holds F
        s.alt=[0]*8; s.ix=s.iy=0; s.sp=0xFFFF; s.pc=0; s.iff=0; s.halted=False
        s.mem=bytearray(65536); s.cyc=0; s.t=0
        s.rd=lambda a:s.mem[a]
        def wr(a,v): s.mem[a]=v
        s.wr=wr; s.inp=lambda p:0xFF; s.outp=lambda p,v:None
    # helpers
    def f(s): return s.r[6]
    def fetch(s):
        v=s.rd(s.pc); s.pc=(s.pc+1)&0xFFFF; return v
    def fetch16(s):
        l=s.fetch(); return l|(s.fetch()<<8)
    def rd16(s,a): return s.rd(a)|(s.rd((a+1)&0xFFFF)<<8)
    def wr16(s,a,v): s.wr(a,v&255); s.wr((a+1)&0xFFFF,(v>>8)&255)
    def push(s,v): s.sp=(s.sp-2)&0xFFFF; s.wr16(s.sp,v)
    def pop(s):
        v=s.rd16(s.sp); s.sp=(s.sp+2)&0xFFFF; return v
    def bc(s): return s.r[0]<<8|s.r[1]
    def de(s): return s.r[2]<<8|s.r[3]
    def hl(s): return s.r[4]<<8|s.r[5]
    def setbc(s,v): s.r[0]=(v>>8)&255; s.r[1]=v&255
    def setde(s,v): s.r[2]=(v>>8)&255; s.r[3]=v&255
    def sethl(s,v): s.r[4]=(v>>8)&255; s.r[5]=v&255
    def add8(s,b,c=0):
        a=s.r[7]; r=a+b+c
        s.r[6]=SZ[r&255]|((a^b^r)&H_)|((((a^r)&(b^r))>>5)&P_)|(r>>8&1); s.r[7]=r&255
    def sub8(s,b,c=0,store=True):
        a=s.r[7]; r=a-b-c
        s.r[6]=SZ[r&255]|((a^b^r)&H_)|((((a^b)&(a^r))>>5)&P_)|N_|((r>>8)&1)
        if store: s.r[7]=r&255
    def alu(s,y,v):
        if y==0: s.add8(v)
        elif y==1: s.add8(v,s.r[6]&1)
        elif y==2: s.sub8(v)
        elif y==3: s.sub8(v,s.r[6]&1)
        elif y==4: s.r[7]&=v; s.r[6]=SZ[s.r[7]]|H_|PAR[s.r[7]]
        elif y==5: s.r[7]^=v; s.r[6]=SZ[s.r[7]]|PAR[s.r[7]]
        elif y==6: s.r[7]|=v; s.r[6]=SZ[s.r[7]]|PAR[s.r[7]]
        else: s.sub8(v,0,False)
    def inc8(s,v):
        r=(v+1)&255; s.r[6]=(s.r[6]&C_)|SZ[r]|((r&15==0)*H_)|((r==0x80)*P_); return r
    def dec8(s,v):
        r=(v-1)&255; s.r[6]=(s.r[6]&C_)|N_|SZ[r]|((r&15==15)*H_)|((r==0x7F)*P_); return r
    def cond(s,y):
        f=s.r[6]; return [not f&Z_, f&Z_, not f&C_, f&C_, not f&P_, f&P_, not f&S_, f&S_][y]
    def step(s):
        idx=None; op=s.fetch()
        while op in(0xDD,0xFD):
            idx='ix' if op==0xDD else 'iy'; op=s.fetch()
        r=s.r
        s.t+=CYC[op] if op not in (0xCB,0xED) else 0
        def HL(): return getattr(s,idx) if idx else s.hl()
        def setHL(v):
            v&=0xFFFF
            if idx: setattr(s,idx,v)
            else: s.sethl(v)
        def addr():
            if idx:
                d=s.fetch(); d=d-256 if d>127 else d
                return (getattr(s,idx)+d)&0xFFFF
            return s.hl()
        def getrp(p):
            return [s.bc(),s.de(),HL(),s.sp][p]
        def setrp(p,v):
            v&=0xFFFF
            if p==0:s.setbc(v)
            elif p==1:s.setde(v)
            elif p==2:setHL(v)
            else:s.sp=v
        if op==0xCB:
            a=addr() if idx else None; op=s.fetch(); x,y,z=op>>6,(op>>3)&7,op&7
            s.t+=8 if z!=6 else (12 if x==1 else 15)
            if idx: v=s.rd(a)
            else: v=s.rd(s.hl()) if z==6 else r[z if z!=7 else 7]
            if x==0:
                c=r[6]&1
                if y==0: co=v>>7; v=((v<<1)|co)&255
                elif y==1: co=v&1; v=(v>>1)|(co<<7)
                elif y==2: co=v>>7; v=((v<<1)|c)&255
                elif y==3: co=v&1; v=(v>>1)|(c<<7)
                elif y==4: co=v>>7; v=(v<<1)&255
                elif y==5: co=v&1; v=(v>>1)|(v&0x80)
                elif y==6: co=v>>7; v=((v<<1)|1)&255
                else: co=v&1; v=v>>1
                r[6]=SZ[v]|PAR[v]|co
            elif x==1:
                r[6]=(r[6]&C_)|H_|((not (v>>y)&1)*(Z_|P_))|((y==7 and v&0x80) and S_ or 0); return
            elif x==2: v&=~(1<<y)&255
            else: v|=1<<y
            if idx: s.wr(a,v)
            elif z==6: s.wr(s.hl(),v)
            else: r[z]=v
            return
        if op==0xED:
            op=s.fetch(); x,y,z=op>>6,(op>>3)&7,op&7; p,q=y>>1,y&1
            if x==1: s.t+=[12,12,15,20,8,14,8,9][z] if not (z==7 and y in(4,5)) else 18
            if x==1:
                if z==0:
                    v=s.inp(s.r[1]); 
                    if y!=6: r[y if y!=7 else 7]=v
                    r[6]=(r[6]&C_)|SZ[v]|PAR[v]
                elif z==1: s.outp(s.r[1], 0 if y==6 else r[y])
                elif z==2:
                    h=s.hl(); v=[s.bc(),s.de(),s.hl(),s.sp][p]; c=r[6]&1
                    if q==0:
                        res=h-v-c
                        r[6]=((res>>8)&S_)|((res&0xFFFF==0)*Z_)|(((h^v^res)>>8)&H_)|((((h^v)&(h^res))>>13)&P_)|N_|((res>>16)&1)
                    else:
                        res=h+v+c
                        r[6]=((res>>8)&S_)|((res&0xFFFF==0)*Z_)|(((h^v^res)>>8)&H_)|((((h^res)&(v^res))>>13)&P_)|((res>>16)&1)
                    s.sethl(res&0xFFFF)
                elif z==3:
                    a=s.fetch16()
                    if q==0: s.wr16(a,[s.bc(),s.de(),s.hl(),s.sp][p])
                    else:
                        v=s.rd16(a)
                        if p==0:s.setbc(v)
                        elif p==1:s.setde(v)
                        elif p==2:s.sethl(v)
                        else:s.sp=v
                elif z==4:
                    a=r[7]; r[7]=0; s.sub8(a)
                elif z==5: s.pc=s.pop()
                elif z==6: pass
                else:
                    if y==4:
                        m=s.rd(s.hl()); s.wr(s.hl(),((r[7]<<4)|(m>>4))&255); r[7]=(r[7]&0xF0)|(m&15); r[6]=(r[6]&C_)|SZ[r[7]]|PAR[r[7]]
                    elif y==5:
                        m=s.rd(s.hl()); s.wr(s.hl(),((m<<4)|(r[7]&15))&255); r[7]=(r[7]&0xF0)|(m>>4); r[6]=(r[6]&C_)|SZ[r[7]]|PAR[r[7]]
                    elif y in(2,3): r[7]=0
                return
            if x==2 and z<4 and y>=4:
                rep=y>=6; d=1 if y in(4,6) else -1
                s.t+=16-21
                while True:
                    s.t+=21
                    if z==0:
                        s.wr(s.de(),s.rd(s.hl())); s.setde((s.de()+d)&0xFFFF); s.sethl((s.hl()+d)&0xFFFF); s.setbc((s.bc()-1)&0xFFFF)
                        r[6]=(r[6]&(S_|Z_|C_))|((s.bc()!=0)*P_)
                        if not(rep and s.bc()): break
                    elif z==1:
                        c=r[6]&1; s.sub8(s.rd(s.hl()),0,False); s.sethl((s.hl()+d)&0xFFFF); s.setbc((s.bc()-1)&0xFFFF)
                        r[6]=(r[6]&~(P_|C_)&255)|((s.bc()!=0)*P_)|c
                        if not(rep and s.bc() and not r[6]&Z_): break
                    elif z==2:
                        s.wr(s.hl(),s.inp(r[1])); s.sethl((s.hl()+d)&0xFFFF); r[0]=(r[0]-1)&255; r[6]=((r[0]==0)*Z_)|N_
                        if not(rep and r[0]): break
                    else:
                        s.outp(r[1],s.rd(s.hl())); s.sethl((s.hl()+d)&0xFFFF); r[0]=(r[0]-1)&255; r[6]=((r[0]==0)*Z_)|N_
                        if not(rep and r[0]): break
                return
            raise Exception("bad ED %02X at %04X"%(op,s.pc))
        x,y,z=op>>6,(op>>3)&7,op&7; p,q=y>>1,y&1
        def getr(i):
            if i==6: return s.rd(addr())
            if idx and i in(4,5) : return r[i]
            return r[i]
        if x==0:
            if z==0:
                if y==0: return
                if y==1: r[7],s.alt[7]=s.alt[7],r[7]; r[6],s.alt[6]=s.alt[6],r[6]; return
                e=s.fetch(); e=e-256 if e>127 else e
                if y==2:
                    r[0]=(r[0]-1)&255
                    if r[0]: s.pc=(s.pc+e)&0xFFFF; s.t+=5
                elif y==3: s.pc=(s.pc+e)&0xFFFF
                elif s.cond(y-4): s.pc=(s.pc+e)&0xFFFF; s.t+=5
            elif z==1:
                if q==0: setrp(p,s.fetch16())
                else:
                    h=HL(); v=getrp(p); res=h+v
                    r[6]=(r[6]&(S_|Z_|P_))|(((h^v^res)>>8)&H_)|(res>>16)
                    setHL(res)
            elif z==2:
                if p==0:
                    if q==0: s.wr(s.bc(),r[7])
                    else: r[7]=s.rd(s.bc())
                elif p==1:
                    if q==0: s.wr(s.de(),r[7])
                    else: r[7]=s.rd(s.de())
                elif p==2:
                    a=s.fetch16()
                    if q==0: s.wr16(a,HL())
                    else: setHL(s.rd16(a))
                else:
                    a=s.fetch16()
                    if q==0: s.wr(a,r[7])
                    else: r[7]=s.rd(a)
            elif z==3: setrp(p,getrp(p)+(1 if q==0 else -1))
            elif z in(4,5):
                fn=s.inc8 if z==4 else s.dec8
                if y==6:
                    a=addr(); s.wr(a,fn(s.rd(a)))
                else:
                    i=y if y!=7 else 7; r[i]=fn(r[i])
            elif z==6:
                if y==6:
                    a=addr(); s.wr(a,s.fetch())
                else: r[y]=s.fetch()
            else:
                a=r[7]; c=r[6]&1
                if y==0: co=a>>7; r[7]=((a<<1)|co)&255; r[6]=(r[6]&(S_|Z_|P_))|co
                elif y==1: co=a&1; r[7]=(a>>1)|(co<<7); r[6]=(r[6]&(S_|Z_|P_))|co
                elif y==2: co=a>>7; r[7]=((a<<1)|c)&255; r[6]=(r[6]&(S_|Z_|P_))|co
                elif y==3: co=a&1; r[7]=(a>>1)|(c<<7); r[6]=(r[6]&(S_|Z_|P_))|co
                elif y==4:
                    f=r[6]; adj=0; cf=f&C_
                    if (f&H_) or (a&15)>9: adj|=6
                    if cf or a>0x99: adj|=0x60; cf=1
                    na=(a-adj)&255 if f&N_ else (a+adj)&255
                    r[6]=SZ[na]|PAR[na]|(f&N_)|cf|((a^na)&H_); r[7]=na
                elif y==5: r[7]=a^255; r[6]|=H_|N_
                elif y==6: r[6]=(r[6]&(S_|Z_|P_))|C_
                else: r[6]=((r[6]&(S_|Z_|P_|C_))^C_)|((r[6]&C_)*H_ and H_)
        elif x==1:
            if op==0x76: s.halted=True; s.pc=(s.pc-1)&0xFFFF; return
            if z==6: r[y if y!=6 else 7]=s.rd(addr()) if y!=7 else s.rd(addr())
            elif y==6: s.wr(addr(),r[z])
            else: r[y]=r[z]
            # note: index 6 is F slot; y==7/z==7 map to A at r[7] naturally
        elif x==2:
            s.alu(y,s.rd(addr()) if z==6 else r[z])
        else:
            if z==0:
                if s.cond(y): s.pc=s.pop(); s.t+=6
            elif z==1:
                if q==0:
                    v=s.pop()
                    if p==3: r[7]=v>>8; r[6]=v&255
                    else: setrp(p,v)
                elif p==0: s.pc=s.pop()
                elif p==1:
                    for i in range(6): r[i],s.alt[i]=s.alt[i],r[i]
                elif p==2: s.pc=HL()
                else: s.sp=HL()
            elif z==2:
                a=s.fetch16()
                if s.cond(y): s.pc=a
            elif z==3:
                if y==0: s.pc=s.fetch16()
                elif y==2: s.outp(s.fetch(),r[7])
                elif y==3: r[7]=s.inp(s.fetch())
                elif y==4:
                    v=s.rd16(s.sp); s.wr16(s.sp,HL()); setHL(v)
                elif y==5:
                    d=s.de(); s.setde(s.hl()); s.sethl(d)
                elif y==6: s.iff=0
                else: s.iff=1
            elif z==4:
                a=s.fetch16()
                if s.cond(y): s.push(s.pc); s.pc=a; s.t+=7
            elif z==5:
                if q==0: s.push((r[7]<<8|r[6]) if p==3 else getrp(p))
                else:
                    a=s.fetch16(); s.push(s.pc); s.pc=a
            elif z==6: s.alu(y,s.fetch())
            else: s.push(s.pc); s.pc=y*8
