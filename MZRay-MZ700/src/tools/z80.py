# Compact Z80 emulator (documented instruction set + IXH/IXL), approximate T-states.
SZP=[0]*256; SZ=[0]*256
for i in range(256):
    s=(i&0x80)|(0x40 if i==0 else 0)|(i&0x28)
    SZ[i]=s
    SZP[i]=s|(0 if bin(i).count('1')&1 else 4)
FC,FN,FP,FH,FZ,FS=1,2,4,0x10,0x40,0x80

class Z80:
    def __init__(s,rd,wr):
        s.rd=rd; s.wr=wr
        s.a=s.f=s.b=s.c=s.d=s.e=s.h=s.l=0
        s.a_=s.f_=s.b_=s.c_=s.d_=s.e_=s.h_=s.l_=0
        s.ix=s.iy=0; s.sp=0xFFFF; s.pc=0; s.t=0; s.iff=0; s.halted=False
    def fetch(s):
        v=s.rd(s.pc); s.pc=(s.pc+1)&0xFFFF; return v
    def fetchw(s):
        lo=s.fetch(); return lo|s.fetch()<<8
    def rdw(s,a): return s.rd(a)|s.rd((a+1)&0xFFFF)<<8
    def wrw(s,a,v): s.wr(a,v&0xFF); s.wr((a+1)&0xFFFF,v>>8)
    def push(s,v): s.sp=(s.sp-2)&0xFFFF; s.wrw(s.sp,v)
    def pop(s):
        v=s.rdw(s.sp); s.sp=(s.sp+2)&0xFFFF; return v
    # 16-bit pairs
    def g16(s,p,idx):
        if p==0: return s.b<<8|s.c
        if p==1: return s.d<<8|s.e
        if p==2: return s.hl_get(idx)
        return s.sp
    def s16(s,p,v,idx):
        v&=0xFFFF
        if p==0: s.b=v>>8; s.c=v&0xFF
        elif p==1: s.d=v>>8; s.e=v&0xFF
        elif p==2: s.hl_set(idx,v)
        else: s.sp=v
    def hl_get(s,idx):
        if idx==0: return s.h<<8|s.l
        return s.ix if idx==1 else s.iy
    def hl_set(s,idx,v):
        v&=0xFFFF
        if idx==0: s.h=v>>8; s.l=v&0xFF
        elif idx==1: s.ix=v
        else: s.iy=v
    def getr(s,i,idx,addr):
        if i==0: return s.b
        if i==1: return s.c
        if i==2: return s.d
        if i==3: return s.e
        if i==4: return s.h if idx==0 else (s.hl_get(idx)>>8)
        if i==5: return s.l if idx==0 else (s.hl_get(idx)&0xFF)
        if i==6: return s.rd(addr)
        return s.a
    def setr(s,i,v,idx,addr):
        v&=0xFF
        if i==0: s.b=v
        elif i==1: s.c=v
        elif i==2: s.d=v
        elif i==3: s.e=v
        elif i==4:
            if idx==0: s.h=v
            else: s.hl_set(idx,(s.hl_get(idx)&0xFF)|v<<8)
        elif i==5:
            if idx==0: s.l=v
            else: s.hl_set(idx,(s.hl_get(idx)&0xFF00)|v)
        elif i==6: s.wr(addr,v)
        else: s.a=v
    def maddr(s,idx):
        if idx==0: return s.h<<8|s.l
        d=s.fetch()
        if d>127: d-=256
        return (s.hl_get(idx)+d)&0xFFFF
    def cond(s,y):
        f=s.f
        return [not f&FZ, bool(f&FZ), not f&FC, bool(f&FC), not f&FP, bool(f&FP), not f&FS, bool(f&FS)][y]
    def alu(s,k,v):
        a=s.a
        if k in(0,1):
            c=(s.f&FC) if k==1 else 0
            r=a+v+c
            s.f=SZ[r&0xFF]|((a^v^r)&FH)|(FP if (~(a^v)&(a^r)&0x80) else 0)|(FC if r>0xFF else 0)
            s.a=r&0xFF
        elif k in(2,3,7):
            c=(s.f&FC) if k==3 else 0
            r=a-v-c
            f=SZ[r&0xFF]|((a^v^r)&FH)|(FP if ((a^v)&(a^r)&0x80) else 0)|(FC if r<0 else 0)|FN
            if k==7: s.f=(f&~0x28)|(v&0x28)
            else: s.f=f; s.a=r&0xFF
        elif k==4: s.a=a&v; s.f=SZP[s.a]|FH
        elif k==5: s.a=a^v; s.f=SZP[s.a]
        else: s.a=a|v; s.f=SZP[s.a]
    def rot(s,k,v):
        c=s.f&FC
        if k==0: r=((v<<1)|(v>>7))&0xFF; cf=v>>7
        elif k==1: r=((v>>1)|(v<<7))&0xFF; cf=v&1
        elif k==2: r=((v<<1)|c)&0xFF; cf=v>>7
        elif k==3: r=(v>>1)|(c<<7); cf=v&1
        elif k==4: r=(v<<1)&0xFF; cf=v>>7
        elif k==5: r=(v>>1)|(v&0x80); cf=v&1
        elif k==6: r=((v<<1)|1)&0xFF; cf=v>>7
        else: r=v>>1; cf=v&1
        s.f=SZP[r]|cf
        return r
    def step(s):
        op=s.fetch(); idx=0
        while op in(0xDD,0xFD):
            idx=1 if op==0xDD else 2; s.t+=4; op=s.fetch()
        if op==0xCB:
            if idx:
                addr=s.maddr(idx); op2=s.fetch(); s.t+=19
                v=s.rd(addr); x=op2>>6; y=(op2>>3)&7
                if x==0: s.wr(addr,s.rot(y,v))
                elif x==1:
                    s.f=(s.f&FC)|FH|(FZ|FP if not v&(1<<y) else 0)|(FS if y==7 and v&0x80 else 0); s.t-=3
                elif x==2: s.wr(addr,v&~(1<<y))
                else: s.wr(addr,v|(1<<y))
                return
            op2=s.fetch(); x=op2>>6; y=(op2>>3)&7; z=op2&7
            addr=s.h<<8|s.l
            v=s.getr(z,0,addr)
            s.t+=15 if z==6 else 8
            if x==0: s.setr(z,s.rot(y,v),0,addr)
            elif x==1:
                s.f=(s.f&FC)|FH|(FZ|FP if not v&(1<<y) else 0)|(FS if y==7 and v&0x80 else 0)
                if z==6: s.t-=3
            elif x==2: s.setr(z,v&~(1<<y),0,addr)
            else: s.setr(z,v|(1<<y),0,addr)
            return
        if op==0xED:
            s.edop(s.fetch()); return
        x=op>>6; y=(op>>3)&7; z=op&7; p=y>>1; q=y&1
        if x==1:
            if op==0x76: s.halted=True; s.t+=4; s.pc=(s.pc-1)&0xFFFF; return
            if y==6 or z==6:
                addr=s.maddr(idx); s.t+=7+(8 if idx else 0)
                s.setr(y,s.getr(z,0,addr),0,addr)
            else:
                s.t+=4; s.setr(y,s.getr(z,idx,0),idx,0)
            return
        if x==2:
            if z==6: addr=s.maddr(idx); s.t+=7+(8 if idx else 0); v=s.rd(addr)
            else: s.t+=4; v=s.getr(z,idx,0)
            s.alu(y,v); return
        if x==0:
            if z==0:
                if y==0: s.t+=4
                elif y==1:
                    s.a,s.a_=s.a_,s.a; s.f,s.f_=s.f_,s.f; s.t+=4
                elif y==2:
                    d=s.fetch(); s.b=(s.b-1)&0xFF
                    if s.b: s.pc=(s.pc+(d-256 if d>127 else d))&0xFFFF; s.t+=13
                    else: s.t+=8
                else:
                    d=s.fetch()
                    if y==3 or s.cond(y-4): s.pc=(s.pc+(d-256 if d>127 else d))&0xFFFF; s.t+=12
                    else: s.t+=7
            elif z==1:
                if q==0: s.s16(p,s.fetchw(),idx); s.t+=10
                else:
                    hl=s.hl_get(idx); v=s.g16(p,idx); r=hl+v
                    s.f=(s.f&(FS|FZ|FP))|(((hl^v^r)>>8)&FH)|(FC if r>0xFFFF else 0)|((r>>8)&0x28)
                    s.hl_set(idx,r); s.t+=11
            elif z==2:
                if q==0:
                    if p==0: s.wr(s.b<<8|s.c,s.a); s.t+=7
                    elif p==1: s.wr(s.d<<8|s.e,s.a); s.t+=7
                    elif p==2: s.wrw(s.fetchw(),s.hl_get(idx)); s.t+=16
                    else: s.wr(s.fetchw(),s.a); s.t+=13
                else:
                    if p==0: s.a=s.rd(s.b<<8|s.c); s.t+=7
                    elif p==1: s.a=s.rd(s.d<<8|s.e); s.t+=7
                    elif p==2: s.hl_set(idx,s.rdw(s.fetchw())); s.t+=16
                    else: s.a=s.rd(s.fetchw()); s.t+=13
            elif z==3:
                s.s16(p,s.g16(p,idx)+(-1 if q else 1),idx); s.t+=6
            elif z in(4,5):
                if y==6: addr=s.maddr(idx); s.t+=11+(8 if idx else 0)
                else: addr=0; s.t+=4
                v=s.getr(y,idx,addr)
                if z==4:
                    r=(v+1)&0xFF; s.f=(s.f&FC)|SZ[r]|(FH if r&0xF==0 else 0)|(FP if r==0x80 else 0)
                else:
                    r=(v-1)&0xFF; s.f=(s.f&FC)|SZ[r]|FN|(FH if r&0xF==0xF else 0)|(FP if r==0x7F else 0)
                s.setr(y,r,idx,addr)
            elif z==6:
                if y==6: addr=s.maddr(idx); s.t+=10+(5 if idx else 0)
                else: addr=0; s.t+=7
                s.setr(y,s.fetch(),idx,addr)
            else:
                s.t+=4; a=s.a; f=s.f
                if y==0: s.a=((a<<1)|(a>>7))&0xFF; s.f=(f&(FS|FZ|FP))|(a>>7)
                elif y==1: s.a=((a>>1)|(a<<7))&0xFF; s.f=(f&(FS|FZ|FP))|(a&1)
                elif y==2: s.a=((a<<1)|(f&FC))&0xFF; s.f=(f&(FS|FZ|FP))|(a>>7)
                elif y==3: s.a=(a>>1)|((f&FC)<<7); s.f=(f&(FS|FZ|FP))|(a&1)
                elif y==4:
                    c=f&FC; corr=0
                    if (f&FH) or (a&0xF)>9: corr=6
                    if c or a>0x99: corr|=0x60; c=1
                    if f&FN: r=(a-corr)&0xFF
                    else: r=(a+corr)&0xFF
                    s.a=r; s.f=SZP[r]|(f&FN)|c|((a^r)&FH)
                elif y==5: s.a=a^0xFF; s.f=f|FH|FN
                elif y==6: s.f=(f&(FS|FZ|FP))|FC
                else: s.f=((f&(FS|FZ|FP))|((f&FC)<<4))^FC
            return
        # x==3
        if z==0:
            if s.cond(y): s.pc=s.pop(); s.t+=11
            else: s.t+=5
        elif z==1:
            if q==0:
                v=s.pop(); s.t+=10
                if p==3: s.a=v>>8; s.f=v&0xFF
                else: s.s16(p,v,idx)
            else:
                if p==0: s.pc=s.pop(); s.t+=10
                elif p==1:
                    s.b,s.b_=s.b_,s.b; s.c,s.c_=s.c_,s.c; s.d,s.d_=s.d_,s.d
                    s.e,s.e_=s.e_,s.e; s.h,s.h_=s.h_,s.h; s.l,s.l_=s.l_,s.l; s.t+=4
                elif p==2: s.pc=s.hl_get(idx); s.t+=4
                else: s.sp=s.hl_get(idx); s.t+=6
        elif z==2:
            a=s.fetchw(); s.t+=10
            if s.cond(y): s.pc=a
        elif z==3:
            if y==0: s.pc=s.fetchw(); s.t+=10
            elif y==2: s.fetch(); s.t+=11
            elif y==3: s.fetch(); s.a=0xFF; s.t+=11
            elif y==4:
                v=s.rdw(s.sp); s.wrw(s.sp,s.hl_get(idx)); s.hl_set(idx,v); s.t+=19
            elif y==5:
                s.d,s.h=s.h,s.d; s.e,s.l=s.l,s.e; s.t+=4
            elif y==6: s.iff=0; s.t+=4
            elif y==7: s.iff=1; s.t+=4
        elif z==4:
            a=s.fetchw()
            if s.cond(y): s.push(s.pc); s.pc=a; s.t+=17
            else: s.t+=10
        elif z==5:
            if q==0:
                s.t+=11
                v=(s.a<<8|s.f) if p==3 else s.g16(p,idx)
                s.push(v)
            else:
                a=s.fetchw(); s.push(s.pc); s.pc=a; s.t+=17
        elif z==6:
            s.alu(y,s.fetch()); s.t+=7
        else:
            s.push(s.pc); s.pc=y*8; s.t+=11
    def edop(s,op):
        x=op>>6; y=(op>>3)&7; z=op&7; p=y>>1; q=y&1
        if x==1:
            if z==2:
                hl=s.h<<8|s.l; v=s.g16(p,0); c=s.f&FC
                if q==0: r=hl-v-c; ff=FN|(FC if r<0 else 0)|(FP if ((hl^v)&(hl^r)&0x8000) else 0)
                else: r=hl+v+c; ff=(FC if r>0xFFFF else 0)|(FP if (~(hl^v)&(hl^r)&0x8000) else 0)
                r&=0xFFFF
                s.f=ff|((r>>8)&(FS|0x28))|(FZ if r==0 else 0)|(((hl^v^r)>>8)&FH)
                s.h=r>>8; s.l=r&0xFF; s.t+=15; return
            if z==3:
                a=s.fetchw(); s.t+=20
                if q==0: s.wrw(a,s.g16(p,0))
                else: s.s16(p,s.rdw(a),0)
                return
            if z==4:
                v=s.a; s.a=0; s.alu(2,v); s.t+=8; return
            if z==6: s.t+=8; return
            if z==5: s.pc=s.pop(); s.t+=14; return
        if x==2 and z==0 and y>=4:
            hl=s.h<<8|s.l; de=s.d<<8|s.e; bc=s.b<<8|s.c
            s.wr(de,s.rd(hl)); dlt=1 if y in(4,6) else -1
            hl=(hl+dlt)&0xFFFF; de=(de+dlt)&0xFFFF; bc=(bc-1)&0xFFFF
            s.h=hl>>8; s.l=hl&0xFF; s.d=de>>8; s.e=de&0xFF; s.b=bc>>8; s.c=bc&0xFF
            s.f=(s.f&(FS|FZ|FC))|(FP if bc else 0)
            if y>=6 and bc: s.pc=(s.pc-2)&0xFFFF; s.t+=21
            else: s.t+=16
            return
        raise Exception('ED op %02X not implemented at %04X'%(op,s.pc-2))
