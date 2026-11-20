import sys
r=['B','C','D','E','H','L','(HL)','A'];rp=['BC','DE','HL','SP'];rp2=['BC','DE','HL','AF']
cc=['NZ','Z','NC','C','PO','PE','P','M'];alu=['ADD A,','ADC A,','SUB ','SBC A,','AND ','XOR ','OR ','CP ']
rot=['RLC','RRC','RL','RR','SLA','SRA','SLL','SRL']
def dis(m,pc,org):
    o=pc
    def b():
        nonlocal pc; v=m[pc-org] if pc-org<len(m) else 0; pc+=1; return v
    def w(): l=b();h=b();return "%04Xh"%(l|h<<8)
    def d(): v=b(); return v-256 if v>127 else v
    op=b(); idx=None
    if op in(0xDD,0xFD):
        idx='IX' if op==0xDD else 'IY'; op=b()
    def R(i,dd=None):
        if idx and i==6: return "(%s%+d)"%(idx,dd)
        return r[i]
    def HLn(): return idx or 'HL'
    if op==0xCB:
        dd=d() if idx else None; op=b();x,y,z=op>>6,(op>>3)&7,op&7
        t=R(z if not idx else 6,dd)
        s=("%s %s"%(rot[y],t)) if x==0 else "%s %d,%s"%(['','BIT','RES','SET'][x],y,t)
    elif op==0xED:
        op=b();x,y,z=op>>6,(op>>3)&7,op&7;p,q=y>>1,y&1
        if x==1:
            if z==0: s="IN %s,(C)"%r[y]
            elif z==1: s="OUT (C),%s"%r[y]
            elif z==2: s=("SBC" if q==0 else "ADC")+" HL,"+rp[p]
            elif z==3: s="LD (%s),%s"%(w(),rp[p]) if q==0 else "LD %s,(%s)"%(rp[p],w())
            elif z==4: s="NEG"
            elif z==5: s="RETN" if y!=1 else "RETI"
            elif z==6: s="IM %d"%[0,0,1,2,0,0,1,2][y]
            else: s=['LD I,A','LD R,A','LD A,I','LD A,R','RRD','RLD','NOP','NOP'][y]
        elif x==2 and z<4 and y>=4:
            s=[['LDI','CPI','INI','OUTI'],['LDD','CPD','IND','OUTD'],['LDIR','CPIR','INIR','OTIR'],['LDDR','CPDR','INDR','OTDR']][y-4][z]
        else: s="DB EDh,%02Xh"%op
    else:
        x,y,z=op>>6,(op>>3)&7,op&7;p,q=y>>1,y&1
        RP=lambda i: HLn() if i==2 else rp[i]
        if x==0:
            if z==0:
                if y==0:s="NOP"
                elif y==1:s="EX AF,AF'"
                elif y==2: e=d(); s="DJNZ %04Xh"%(pc+e)
                elif y==3: e=d(); s="JR %04Xh"%(pc+e)
                else: e=d(); s="JR %s,%04Xh"%(cc[y-4],pc+e)
            elif z==1: s="LD %s,%s"%(RP(p),w()) if q==0 else "ADD %s,%s"%(HLn(),RP(p))
            elif z==2:
                s=[["LD (BC),A","LD A,(BC)"],["LD (DE),A","LD A,(DE)"],None,None][p]
                if p==2: a=w(); s="LD (%s),%s"%(a,HLn()) if q==0 else "LD %s,(%s)"%(HLn(),a)
                elif p==3: a=w(); s="LD (%s),A"%a if q==0 else "LD A,(%s)"%a
                else: s=s[q]
            elif z==3: s=("INC " if q==0 else "DEC ")+RP(p)
            elif z in(4,5):
                dd=d() if idx and y==6 else None; s=("INC " if z==4 else "DEC ")+R(y,dd)
            elif z==6:
                dd=d() if idx and y==6 else None; s="LD %s,%02Xh"%(R(y,dd),b())
            else: s=['RLCA','RRCA','RLA','RRA','DAA','CPL','SCF','CCF'][y]
        elif x==1:
            if op==0x76: s="HALT"
            else:
                dd=d() if idx and (y==6 or z==6) else None
                s="LD %s,%s"%(R(y,dd) if y==6 else r[y],R(z,dd) if z==6 else r[z])
        elif x==2:
            dd=d() if idx and z==6 else None; s=alu[y]+R(z,dd)
        else:
            if z==0:s="RET "+cc[y]
            elif z==1: s="POP "+(HLn() if p==2 else rp2[p]) if q==0 else ['RET','EXX','JP (%s)'%HLn(),'LD SP,%s'%HLn()][p]
            elif z==2:s="JP %s,%s"%(cc[y],w())
            elif z==3:
                if y==0:s="JP "+w()
                elif y==2:s="OUT (%02Xh),A"%b()
                elif y==3:s="IN A,(%02Xh)"%b()
                else:s=['','','','','EX (SP),HL','EX DE,HL','DI','EI'][y]
            elif z==4:s="CALL %s,%s"%(cc[y],w())
            elif z==5: s="PUSH "+(HLn() if p==2 else rp2[p]) if q==0 else "CALL "+w()
            elif z==6:s=alu[y]+"%02Xh"%b()
            else:s="RST %02Xh"%(y*8)
    return pc,s
if __name__=="__main__":
    m=open(sys.argv[1],"rb").read()[24:]; org=0x4000
    pc=int(sys.argv[2],16); end=int(sys.argv[3],16)
    while pc<end:
        n,s=dis(m,pc,org)
        print("%04X  %-12s %s"%(pc,m[pc-org:n-org].hex(),s)); pc=n
