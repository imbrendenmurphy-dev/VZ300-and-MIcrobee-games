# Minimal two-pass Z80 assembler (subset sufficient for MZRAY).
import re, sys
R8 = {'B':0,'C':1,'D':2,'E':3,'H':4,'L':5,'(HL)':6,'A':7}
R16 = {'BC':0,'DE':1,'HL':2,'SP':3}
R16AF = {'BC':0,'DE':1,'HL':2,'AF':3}
CC = {'NZ':0,'Z':1,'NC':2,'C':3,'PO':4,'PE':5,'P':6,'M':7}
ALU = {'ADD':0,'ADC':1,'SUB':2,'SBC':3,'AND':4,'XOR':5,'OR':6,'CP':7}
ROT = {'RLC':0,'RRC':1,'RL':2,'RR':3,'SLA':4,'SRA':5,'SLL':6,'SRL':7}
SIMPLE = {'NOP':[0],'HALT':[0x76],'DI':[0xF3],'EI':[0xFB],'EXX':[0xD9],'RLCA':[7],'RRCA':[0xF],
 'RLA':[0x17],'RRA':[0x1F],'DAA':[0x27],'CPL':[0x2F],'SCF':[0x37],'CCF':[0x3F],
 'NEG':[0xED,0x44],'LDI':[0xED,0xA0],'LDIR':[0xED,0xB0],'LDD':[0xED,0xA8],'LDDR':[0xED,0xB8],
 'RET':[0xC9],'RETI':[0xED,0x4D]}

def dispcode(ch):
    if 'A'<=ch<='Z': return ord(ch)-64
    if '0'<=ch<='9': return 0x20+ord(ch)-48
    if ch==' ': return 0
    if ch=='.': return 0x2E
    raise ValueError('no display code for %r'%ch)

class Asm:
    def __init__(s): s.sym={}; s.final=False
    def ev(s,e):
        e=e.strip().replace('$','__pc__')
        env=dict(s.sym); env['__pc__']=s.pc
        try: return int(eval(e,{'__builtins__':{}},env))
        except NameError:
            if s.final: raise
            return 0
    def cls(s,op):
        o=op.strip(); u=o.upper().replace(' ','')
        if u in R8: return ('r8',R8[u])
        if u in ('IX','IY'): return ('xr',0xDD if u=='IX' else 0xFD)
        if u in R16 or u in ('AF',"AF'"): return ('r16',u)
        m=re.match(r'^\((IX|IY)([+-].*)?\)$',u)
        if m:
            d=o.strip()[3:-1].strip()
            return ('ix',0xDD if m.group(1)=='IX' else 0xFD, d if d else '0')
        if u in ('(BC)','(DE)','(SP)','(C)'): return ('indr',u[1:-1])
        if o.startswith('(') and o.endswith(')'):
            depth=0; outer=True
            for i,ch in enumerate(o):
                if ch=='(': depth+=1
                elif ch==')':
                    depth-=1
                    if depth==0 and i!=len(o)-1: outer=False
            if outer: return ('ind',o[1:-1])
        return ('imm',o)
    def b(s,v): return v&0xFF
    def w(s,v): v&=0xFFFF; return [v&0xFF,v>>8]
    def d8(s,e):
        v=s.ev(e)
        if s.final and not -128<=v<=127: raise ValueError('displacement range %d'%v)
        return v&0xFF
    def rel(s,e,size=2):
        t=s.ev(e); d=t-(s.pc+size)
        if s.final and not -128<=d<=127: raise ValueError('JR out of range')
        return d&0xFF
    def enc(s,mn,ops):
        C=[s.cls(o) for o in ops]
        if mn in SIMPLE and not ops: return SIMPLE[mn]
        if mn=='LD':
            a,b=C
            if a[0]=='r8' and b[0]=='r8': return [0x40|a[1]<<3|b[1]]
            if a[0]=='r8' and b[0]=='imm': return [0x06|a[1]<<3,s.b(s.ev(b[1]))]
            if a[0]=='r8' and b[0]=='ix': return [b[1],0x46|a[1]<<3,s.d8(b[2])]
            if a[0]=='ix' and b[0]=='r8': return [a[1],0x70|b[1],s.d8(a[2])]
            if a[0]=='ix' and b[0]=='imm': return [a[1],0x36,s.d8(a[2]),s.b(s.ev(b[1]))]
            if a==('r8',7) and b[0]=='indr' and b[1] in('BC','DE'): return [0x0A if b[1]=='BC' else 0x1A]
            if b==('r8',7) and a[0]=='indr' and a[1] in('BC','DE'): return [0x02 if a[1]=='BC' else 0x12]
            if a==('r8',7) and b[0]=='ind': return [0x3A]+s.w(s.ev(b[1]))
            if b==('r8',7) and a[0]=='ind': return [0x32]+s.w(s.ev(a[1]))
            if a[0]=='r16' and a[1] in R16 and b[0]=='imm': return [0x01|R16[a[1]]<<4]+s.w(s.ev(b[1]))
            if a[0]=='xr' and b[0]=='imm': return [a[1],0x21]+s.w(s.ev(b[1]))
            if a==('r16','HL') and b[0]=='ind': return [0x2A]+s.w(s.ev(b[1]))
            if b==('r16','HL') and a[0]=='ind': return [0x22]+s.w(s.ev(a[1]))
            if a[0]=='xr' and b[0]=='ind': return [a[1],0x2A]+s.w(s.ev(b[1]))
            if b[0]=='xr' and a[0]=='ind': return [b[1],0x22]+s.w(s.ev(a[1]))
            if a[0]=='r16' and a[1] in R16 and b[0]=='ind': return [0xED,0x4B|R16[a[1]]<<4]+s.w(s.ev(b[1]))
            if b[0]=='r16' and b[1] in R16 and a[0]=='ind': return [0xED,0x43|R16[b[1]]<<4]+s.w(s.ev(a[1]))
            if a==('r16','SP') and b==('r16','HL'): return [0xF9]
        if mn in('PUSH','POP'):
            a=C[0]; base=0xC5 if mn=='PUSH' else 0xC1
            if a[0]=='xr': return [a[1],base|0x20]
            return [base|R16AF[a[1]]<<4]
        if mn in ALU:
            if len(C)==2:
                if C[0]==('r16','HL') and mn in('ADD','ADC','SBC'):
                    r=R16[C[1][1]]
                    if mn=='ADD': return [0x09|r<<4]
                    return [0xED,(0x4A if mn=='ADC' else 0x42)|r<<4]
                if C[0][0]=='xr' and mn=='ADD':
                    n=C[1][1]; r={'BC':0,'DE':1,'SP':3}.get(n,2)
                    return [C[0][1],0x09|r<<4]
                if C[0]==('r8',7): C=C[1:]
                else: raise ValueError('bad alu')
            a=C[0]; k=ALU[mn]
            if a[0]=='r8': return [0x80|k<<3|a[1]]
            if a[0]=='imm': return [0xC6|k<<3,s.b(s.ev(a[1]))]
            if a[0]=='ix': return [a[1],0x86|k<<3,s.d8(a[2])]
        if mn in('INC','DEC'):
            a=C[0]; i=mn=='DEC'
            if a[0]=='r8': return [0x04|a[1]<<3|i]
            if a[0]=='r16': return [(0x0B if i else 0x03)|R16[a[1]]<<4]
            if a[0]=='xr': return [a[1],0x2B if i else 0x23]
            if a[0]=='ix': return [a[1],0x34|i,s.d8(a[2])]
        if mn=='JP':
            if len(C)==1:
                a=C[0]
                if a==('r8',6): return [0xE9]
                return [0xC3]+s.w(s.ev(ops[0]))
            return [0xC2|CC[ops[0].strip().upper()]<<3]+s.w(s.ev(ops[1]))
        if mn=='JR':
            if len(C)==1: return [0x18,s.rel(ops[0])]
            c=CC[ops[0].strip().upper()]; assert c<4
            return [0x20|c<<3,s.rel(ops[1])]
        if mn=='DJNZ': return [0x10,s.rel(ops[0])]
        if mn=='CALL':
            if len(C)==1: return [0xCD]+s.w(s.ev(ops[0]))
            return [0xC4|CC[ops[0].strip().upper()]<<3]+s.w(s.ev(ops[1]))
        if mn=='RET' and ops: return [0xC0|CC[ops[0].strip().upper()]<<3]
        if mn=='RST': return [0xC7|s.ev(ops[0])]
        if mn=='EX':
            u=[o.strip().upper().replace(' ','') for o in ops]
            if u==['DE','HL']: return [0xEB]
            if u==['AF',"AF'"]: return [0x08]
            if u==['(SP)','HL']: return [0xE3]
        if mn=='IM': return [0xED,{0:0x46,1:0x56,2:0x5E}[s.ev(ops[0])]]
        if mn in ROT:
            a=C[0]; k=ROT[mn]
            if a[0]=='r8': return [0xCB,k<<3|a[1]]
            if a[0]=='ix': return [a[1],0xCB,s.d8(a[2]),k<<3|6]
        if mn in('BIT','RES','SET'):
            n=s.ev(ops[0]); a=C[1]; base={'BIT':0x40,'RES':0x80,'SET':0xC0}[mn]
            if a[0]=='r8': return [0xCB,base|n<<3|a[1]]
            if a[0]=='ix': return [a[1],0xCB,s.d8(a[2]),base|n<<3|6]
        raise ValueError('cannot encode %s %s'%(mn,ops))

    def splitops(s,t):
        out=[];cur='';q=None;depth=0
        for ch in t:
            if q:
                cur+=ch
                if ch==q: q=None
                continue
            if ch in '"': q=ch; cur+=ch; continue
            if ch=='(': depth+=1
            if ch==')': depth-=1
            if ch==',' and depth==0: out.append(cur.strip()); cur=''
            else: cur+=ch
        if cur.strip(): out.append(cur.strip())
        return out
    def run(s,src,final):
        s.final=final; s.pc=0; s.out={}; s.origin=None
        for ln,line in enumerate(src.split('\n'),1):
            try: s.line(line)
            except Exception as e:
                raise SystemExit('line %d: %s\n  %s'%(ln,e,line))
    def emit(s,bs):
        for x in bs:
            s.out[s.pc]=x&0xFF; s.pc+=1
    def line(s,line):
        # strip comment (not inside quotes)
        q=False; t=''
        for ch in line:
            if ch=='"': q=not q
            if ch==';' and not q: break
            t+=ch
        t=t.rstrip()
        if not t.strip(): return
        m=re.match(r'^([A-Za-z_][\w]*):?\s+(equ|EQU)\s+(.*)$',t)
        if m:
            s.sym[m.group(1)]=s.ev(m.group(3)); return
        m=re.match(r'^([A-Za-z_][\w]*):(.*)$',t)
        if m:
            name=m.group(1)
            if not s.final and name in s.sym and s.sym[name]!=s.pc and s.pass1seen.get(name):
                raise ValueError('duplicate label '+name)
            s.sym[name]=s.pc
            if not s.final: s.pass1seen[name]=1
            t=m.group(2)
            if not t.strip(): return
        t=t.strip()
        parts=t.split(None,1); mn=parts[0].upper(); rest=parts[1] if len(parts)>1 else ''
        ops=s.splitops(rest) if rest else []
        if mn=='ORG': s.pc=s.ev(rest); return
        if mn=='ALIGN':
            n=s.ev(rest)
            while s.pc%n: s.emit([0])
            return
        if mn=='DS':
            n=s.ev(ops[0]); f=s.ev(ops[1]) if len(ops)>1 else 0
            s.emit([f]*n); return
        if mn=='DB':
            for o in ops:
                if o.startswith('"'): s.emit([ord(c) for c in o[1:-1]])
                else: s.emit([s.ev(o)])
            return
        if mn=='DW':
            for o in ops: s.emit(s.w(s.ev(o)))
            return
        if mn=='DSC':   # MZ display-code string, 0xFF terminated
            s.emit([dispcode(c) for c in rest.strip()[1:-1]]+[0xFF]); return
        s.emit(s.enc(mn,ops))

def assemble(src):
    a=Asm(); a.pass1seen={}
    a.run(src,False); a.run(src,False); a.run(src,True)
    lo=min(a.out); hi=max(a.out)
    data=bytes(a.out.get(i,0) for i in range(lo,hi+1))
    return lo,data,a.sym
