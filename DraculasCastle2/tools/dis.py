# minimal Z80 disassembler
import sys
R=['B','C','D','E','H','L','(HL)','A']; RP=['BC','DE','HL','SP']; RP2=['BC','DE','HL','AF']
CC=['NZ','Z','NC','C','PO','PE','P','M']; ALU=['ADD A,','ADC A,','SUB ','SBC A,','AND ','XOR ','OR ','CP ']
ROT=['RLC','RRC','RL','RR','SLA','SRA','SLL','SRL']
def dis(m,pc,base):
    def b(i): return m[pc-base+i]
    def w(i): return b(i)|b(i+1)<<8
    op=b(0); x,y,z=op>>6,(op>>3)&7,op&7; p,q=y>>1,y&1
    if op==0xCB:
        o=b(1);x,y,z=o>>6,(o>>3)&7,o&7
        return 2,[f'{ROT[y]} {R[z]}','BIT %d,%s'%(y,R[z]),'RES %d,%s'%(y,R[z]),'SET %d,%s'%(y,R[z])][x]
    if op==0xED:
        o=b(1);x,y,z=o>>6,(o>>3)&7,o&7;p,q=y>>1,y&1
        if x==1:
            if z==0: return 2,'IN %s,(C)'%R[y]
            if z==1: return 2,'OUT (C),%s'%R[y]
            if z==2: return 2,('ADC' if q else 'SBC')+' HL,'+RP[p]
            if z==3: return 4,('LD %s,(%04X)'%(RP[p],w(2)) if q else 'LD (%04X),%s'%(w(2),RP[p]))
            return 2,['NEG','RETN','IM','LD I,A/..'][min(z-4,3)] if z<7 else (2,['LD I,A','LD R,A','LD A,I','LD A,R','RRD','RLD','?','?'][y])
        if x==2 and y>=4 and z<4: return 2,['LDI','CPI','INI','OUTI','LDD','CPD','IND','OUTD','LDIR','CPIR','INIR','OTIR','LDDR','CPDR','INDR','OTDR'][(y-4)*4+z]
        return 2,'ED %02X'%o
    if op in (0xDD,0xFD):
        n,s=dis(m,pc+1,base); ix='IX' if op==0xDD else 'IY'
        if '(HL)' in s:
            d=b(2); d=d-256 if d>127 else d
            s2=s.replace('(HL)','(%s%+d)'%(ix,d))
            # shift immediates: re-decode with offset byte
            if b(1)==0x36: return 4,'LD (%s%+d),%02X'%(ix,d,b(3))
            if b(1)==0xCB:
                o=b(3); return 4,dis([0xCB,o],0,0)[1].replace('(HL)','(%s%+d)'%(ix,d))
            return n+2,s2
        return n+1,s.replace('HL',ix)
    if x==0:
        if z==0: return [(1,'NOP'),(1,"EX AF,AF'"),(2,'DJNZ %04X'),(2,'JR %04X')][y] if y<4 and y<2 else ((2,('DJNZ' if y==2 else 'JR')+' %04X'%(pc+2+(b(1)-256 if b(1)>127 else b(1)))) if y<4 else (2,'JR %s,%04X'%(CC[y-4],pc+2+(b(1)-256 if b(1)>127 else b(1)))))
        if z==1: return (3,'LD %s,%04X'%(RP[p],w(1))) if not q else (1,'ADD HL,'+RP[p])
        if z==2: return [(1,'LD (BC),A'),(1,'LD A,(BC)'),(1,'LD (DE),A'),(1,'LD A,(DE)'),(3,'LD (%04X),HL'%w(1)),(3,'LD HL,(%04X)'%w(1)),(3,'LD (%04X),A'%w(1)),(3,'LD A,(%04X)'%w(1))][y]
        if z==3: return 1,('DEC ' if q else 'INC ')+RP[p]
        if z==4: return 1,'INC '+R[y]
        if z==5: return 1,'DEC '+R[y]
        if z==6: return 2,'LD %s,%02X'%(R[y],b(1))
        return 1,['RLCA','RRCA','RLA','RRA','DAA','CPL','SCF','CCF'][y]
    if x==1: return 1,'HALT' if op==0x76 else 'LD %s,%s'%(R[y],R[z])
    if x==2: return 1,ALU[y]+R[z]
    if z==0: return 1,'RET '+CC[y]
    if z==1: return 1,('POP '+RP2[p]) if not q else ['RET','EXX','JP (HL)','LD SP,HL'][p]
    if z==2: return 3,'JP %s,%04X'%(CC[y],w(1))
    if z==3: return [(3,'JP %04X'%w(1)),(1,'CB'),(2,'OUT (%02X),A'%b(1)),(2,'IN A,(%02X)'%b(1)),(1,'EX (SP),HL'),(1,'EX DE,HL'),(1,'DI'),(1,'EI')][y]
    if z==4: return 3,'CALL %s,%04X'%(CC[y],w(1))
    if z==5: return (1,'PUSH '+RP2[p]) if not q else (3,'CALL %04X'%w(1))
    if z==6: return 2,ALU[y]+'%02X'%b(1)
    return 1,'RST %02X'%(y*8)
if __name__=='__main__':
    d=open(sys.argv[1],'rb').read()
    base=d[22]|d[23]<<8; m=d[24:]
    start=int(sys.argv[2],16) if len(sys.argv)>2 else base
    end=int(sys.argv[3],16) if len(sys.argv)>3 else base+len(m)
    pc=start
    while pc<end:
        try: n,s=dis(m,pc,base)
        except Exception: n,s=1,'??'
        print('%04X  %-12s %s'%(pc,' '.join('%02X'%m[pc-base+i] for i in range(n)),s)); pc+=n
