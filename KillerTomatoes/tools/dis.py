#!/usr/bin/env python3
# Minimal Z80 disassembler (x/y/z/p/q decoding, per z80.info "Decoding Z80 opcodes")
import sys
r=['B','C','D','E','H','L','(HL)','A']
rp=['BC','DE','HL','SP']; rp2=['BC','DE','HL','AF']
cc=['NZ','Z','NC','C','PO','PE','P','M']
alu=['ADD A,','ADC A,','SUB ','SBC A,','AND ','XOR ','OR ','CP ']
rot=['RLC','RRC','RL','RR','SLA','SRA','SLL','SRL']
im=['0','0/1','1','2','0','0/1','1','2']
bli={(4,0):'LDI',(4,1):'CPI',(4,2):'INI',(4,3):'OUTI',(5,0):'LDD',(5,1):'CPD',(5,2):'IND',(5,3):'OUTD',
     (6,0):'LDIR',(6,1):'CPIR',(6,2):'INIR',(6,3):'OTIR',(7,0):'LDDR',(7,1):'CPDR',(7,2):'INDR',(7,3):'OTDR'}
def dis(m,pc):
    start=pc
    def b():
        nonlocal pc; v=m(pc); pc=(pc+1)&0xffff; return v
    def w():
        lo=b(); hi=b(); return lo|hi<<8
    pref=None; op=b()
    if op in (0xDD,0xFD):
        pref='IX' if op==0xDD else 'IY'; op=b()
    def R(i,d=None):
        if pref:
            if i==6: return '(%s%+d)'%(pref,d)
        return r[i]
    def RPn(i):
        s=rp[i]; return pref if (pref and s=='HL') else s
    def RP2(i):
        s=rp2[i]; return pref if (pref and s=='HL') else s
    if op==0xCB:
        if pref:
            d=b(); d=d-256 if d>127 else d; op=b(); reg='(%s%+d)'%(pref,d)
        else:
            op=b(); reg=r[op&7]
        x,y,z=op>>6,(op>>3)&7,op&7
        if x==0: s='%s %s'%(rot[y],reg)
        elif x==1: s='BIT %d,%s'%(y,reg)
        elif x==2: s='RES %d,%s'%(y,reg)
        else: s='SET %d,%s'%(y,reg)
        return s,pc
    if op==0xED:
        op=b(); x,y,z=op>>6,(op>>3)&7,op&7; p,q=y>>1,y&1
        if x==1:
            if z==0: s='IN %s,(C)'%(r[y] if y!=6 else 'F')
            elif z==1: s='OUT (C),%s'%(r[y] if y!=6 else '0')
            elif z==2: s=('SBC HL,' if q==0 else 'ADC HL,')+rp[p]
            elif z==3:
                a=w(); s=('LD ($%04X),%s'%(a,rp[p])) if q==0 else ('LD %s,($%04X)'%(rp[p],a))
            elif z==4: s='NEG'
            elif z==5: s='RETI' if y==1 else 'RETN'
            elif z==6: s='IM '+im[y]
            else: s=['LD I,A','LD R,A','LD A,I','LD A,R','RRD','RLD','NOP','NOP'][y]
        elif x==2 and (y,z) in bli: s=bli[(y,z)]
        else: s='DB $ED,$%02X'%op
        return s,pc
    x,y,z=op>>6,(op>>3)&7,op&7; p,q=y>>1,y&1
    d=None
    def disp():
        v=b(); return v-256 if v>127 else v
    if x==0:
        if z==0:
            if y==0: s='NOP'
            elif y==1: s="EX AF,AF'"
            else:
                e=disp(); t=(pc+e)&0xffff
                s=['DJNZ','JR','JR NZ,','JR Z,','JR NC,','JR C,'][y-2]
                s=(s+(' ' if not s.endswith(',') else '')+'$%04X'%t)
        elif z==1:
            if q==0: s='LD %s,$%04X'%(RPn(p),w())
            else: s='ADD %s,%s'%(RPn(2),RPn(p))
        elif z==2:
            if q==0: s=['LD (BC),A','LD (DE),A','LD ($%04X),%s','LD ($%04X),A'][p]
            else: s=['LD A,(BC)','LD A,(DE)','LD %s,($%04X)','LD A,($%04X)'][p]
            if p==2: a=w(); s=s%((a,RPn(2)) if q==0 else (RPn(2),a))
            elif p==3: s=s%w()
        elif z==3: s=('INC ' if q==0 else 'DEC ')+RPn(p)
        elif z in (4,5):
            if y==6 and pref: d=disp()
            s=('INC ' if z==4 else 'DEC ')+R(y,d)
        elif z==6:
            if y==6 and pref: d=disp()
            s='LD %s,$%02X'%(R(y,d),b())
        else: s=['RLCA','RRCA','RLA','RRA','DAA','CPL','SCF','CCF'][y]
    elif x==1:
        if z==6 and y==6: s='HALT'
        else:
            if (y==6 or z==6) and pref:
                d=disp(); s='LD %s,%s'%(R(y,d) if y==6 else r[y], R(z,d) if z==6 else r[z])
            else:
                def rr(i):
                    if pref and i in (4,5): return pref+('H' if i==4 else 'L')
                    return r[i]
                s='LD %s,%s'%(rr(y),rr(z))
    elif x==2:
        if z==6 and pref: d=disp()
        s=alu[y]+R(z,d)
    else:
        if z==0: s='RET '+cc[y]
        elif z==1:
            if q==0: s='POP '+RP2(p)
            else: s=['RET','EXX','JP (%s)'%(pref or 'HL'),'LD SP,%s'%(pref or 'HL')][p]
        elif z==2: s='JP %s,$%04X'%(cc[y],w())
        elif z==3:
            if y==0: s='JP $%04X'%w()
            elif y==2: s='OUT ($%02X),A'%b()
            elif y==3: s='IN A,($%02X)'%b()
            else: s=['','', '', '', 'EX (SP),%s'%(pref or 'HL'),'EX DE,HL','DI','EI'][y]
        elif z==4: s='CALL %s,$%04X'%(cc[y],w())
        elif z==5:
            if q==0: s='PUSH '+RP2(p)
            else: s='CALL $%04X'%w()
        elif z==6: s=alu[y]+'$%02X'%b()
        else: s='RST $%02X'%(y*8)
    return s,pc

if __name__=='__main__':
    f=sys.argv[1]; d=open(f,'rb').read()
    base=d[22]|d[23]<<8; data=d[24:]
    mem=lambda a: data[a-base] if 0<=a-base<len(data) else 0
    a=int(sys.argv[2],16); end=int(sys.argv[3],16)
    while a<end:
        s,n=dis(mem,a)
        hb=' '.join('%02X'%mem(i&0xffff) for i in range(a,n if n>a else a+1))
        print('%04X  %-12s %s'%(a,hb,s)); a=n if n>a else a+1
