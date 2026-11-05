#!/usr/bin/env python3
"""zasm.py - compact two-pass Z80 assembler written for the EMPIRES project.

Syntax (Zilog style):
  label:   ld a,(ix+5)      ; comment
  .local   ...               ; local label, scoped to previous global label
  NAME     equ  expr  /  NAME = expr
  org expr | db/defb/defm ... | dw/defw ... | ds/defs n[,fill]
  include "file" | incbin "file" | align n | assert expr[,"msg"]
Numbers: 123  $7F  0x7F  7Fh  %1010  1010b  'A'   $ = current address
Functions: low(x) high(x)
"""
import sys, re, os

R8 = {'b':0,'c':1,'d':2,'e':3,'h':4,'l':5,'a':7}
R16 = {'bc':0,'de':1,'hl':2,'sp':3}
R16AF = {'bc':0,'de':1,'hl':2,'af':3}
CC = {'nz':0,'z':1,'nc':2,'c':3,'po':4,'pe':5,'p':6,'m':7}

class AsmError(Exception): pass

class Op:
    """Parsed operand. kind: r8 (val), mhl, idx (prefix,disp expr), r16, imm, mem (addr expr),
    mreg (bc/de/sp/c), spec (i r af af' ix iy)"""
    def __init__(s, kind, val=None, pre=None, expr=None):
        s.kind=kind; s.val=val; s.pre=pre; s.expr=expr

def split_ops(t):
    out=[]; depth=0; cur=''; q=None
    for ch in t:
        if q:
            cur+=ch
            if ch==q: q=None
            continue
        if ch in '"\'' and not (ch=="'" and cur.strip().lower().endswith('af')):
            q=ch; cur+=ch; continue
        if ch=='(': depth+=1
        if ch==')': depth-=1
        if ch==',' and depth==0:
            out.append(cur.strip()); cur=''
        else: cur+=ch
    if cur.strip(): out.append(cur.strip())
    return out

class Assembler:
    def __init__(s):
        s.syms={}; s.pc=0; s.out={}; s.lastglobal=''; s.passno=0
        s.listing=[]; s.unresolved=False; s.minaddr=None; s.maxaddr=None
        s.promote=set(); s.curkey=None

    # ---------- expressions ----------
    def ev(s, e, need=True):
        e=e.strip()
        toks=re.findall(r"\$[0-9a-fA-F]+|0x[0-9a-fA-F]+|%[01]+|[0-9][0-9a-fA-F]*[hH]\b|[01]+[bB]\b|\d+|'(?:[^'\\]|\\.)'|\.?[A-Za-z_][\w.]*|<<|>>|\*\*|[-+*/%&|^~()<>=!]=?|\$|\S", e)
        py=''
        for t in toks:
            tl=t.lower()
            if t=='$': py+=str(s.pc)
            elif t.startswith('$'): py+=str(int(t[1:],16))
            elif tl.startswith('0x'): py+=str(int(t,16))
            elif t.startswith('%'): py+=str(int(t[1:],2))
            elif re.fullmatch(r"[0-9][0-9a-fA-F]*[hH]",t): py+=str(int(t[:-1],16))
            elif re.fullmatch(r"[01]+[bB]",t): py+=str(int(t[:-1],2))
            elif t.isdigit(): py+=str(int(t))
            elif t.startswith("'"):
                c=t[1:-1]
                if c.startswith('\\'): c={'n':'\n','r':'\r','0':'\0','\\':'\\',"'":"'"}.get(c[1],c[1])
                py+=str(ord(c))
            elif tl in ('low','high','col'): py+=tl
            elif re.fullmatch(r"\.?[A-Za-z_][\w.]*",t):
                name=s.full(t)
                if name in s.syms: py+=str(s.syms[name])
                else:
                    if s.passno>=2 and need: raise AsmError('undefined symbol '+t)
                    s.unresolved=True; py+='0'
            elif t=='/': py+='//'
            else: py+=t
        try:
            v=eval(py,{'__builtins__':{}},{'low':lambda x:x&255,'high':lambda x:(x>>8)&255,'col':lambda f,b:((b&15)<<4)|(f&15)})
        except Exception as ex:
            raise AsmError('bad expression "%s" (%s)'%(e,ex))
        return int(v)

    def full(s,name):
        return (s.lastglobal+name) if name.startswith('.') else name

    # ---------- operands ----------
    def op(s,t):
        tl=t.lower().replace(' ','')
        if tl in R8: return Op('r8',R8[tl])
        if tl=='(hl)': return Op('mhl',6)
        if tl in ('ix','iy'): return Op('xr',pre=0xDD if tl=='ix' else 0xFD)
        if tl in ('ixh','ixl','iyh','iyl'):
            return Op('xh',4 if tl[2]=='h' else 5, pre=0xDD if tl[1]=='x' else 0xFD)
        if tl in R16: return Op('r16',R16[tl])
        if tl=='af': return Op('af')
        if tl=="af'": return Op("af'")
        if tl in ('i','r'): return Op('ir',tl)
        if tl in ('(bc)','(de)'): return Op('mreg',tl[1:3])
        if tl=='(sp)': return Op('msp')
        if tl=='(c)': return Op('mc')
        m=re.fullmatch(r'\((ix|iy)([+-].*)?\)',tl)
        if m:
            d=m.group(2) or '+0'
            # use original-case expression
            ot=t.strip()[1:-1].strip()[2:].strip() or '+0'
            return Op('idx',6,pre=0xDD if m.group(1)=='ix' else 0xFD,expr=ot)
        if t.strip().startswith('(') and t.strip().endswith(')') and s.balanced(t.strip()[1:-1]):
            return Op('mem',expr=t.strip()[1:-1])
        return Op('imm',expr=t)

    def balanced(s,t):
        d=0
        for c in t:
            if c=='(': d+=1
            elif c==')':
                d-=1
                if d<0: return False
        return d==0

    def cond(s,t):
        return CC.get(t.lower().strip())

    def b(s,e,signed=False):
        v=s.ev(e)
        if s.passno>=2 and not (-128<=v<=255): raise AsmError('byte out of range: %s=%d'%(e,v))
        return v&255
    def w(s,e):
        v=s.ev(e)&0xFFFF; return [v&255,v>>8]
    def disp(s,o):
        v=s.ev(o.expr)
        if s.passno>=2 and not -128<=v<=127: raise AsmError('index displacement out of range')
        return v&255

    # ---------- r8-ish helpers ----------
    def r8x(s,o):
        """returns (prefix list, regcode, suffix list) for r8,(hl),(ix+d),ixh..."""
        if o.kind=='r8': return [],o.val,[]
        if o.kind=='mhl': return [],6,[]
        if o.kind=='idx': return [o.pre],6,[s.disp(o)]
        if o.kind=='xh': return [o.pre],o.val,[]
        return None

    def encode(s,mn,ops):
        mn=mn.lower()
        O=[s.op(x) for x in ops]
        n=len(O)
        simple={'nop':[0],'rlca':[7],'rrca':[0x0f],'rla':[0x17],'rra':[0x1f],'daa':[0x27],'cpl':[0x2f],
            'scf':[0x37],'ccf':[0x3f],'halt':[0x76],'exx':[0xd9],'di':[0xf3],'ei':[0xfb],
            'neg':[0xed,0x44],'retn':[0xed,0x45],'reti':[0xed,0x4d],'rrd':[0xed,0x67],'rld':[0xed,0x6f],
            'ldi':[0xed,0xa0],'cpi':[0xed,0xa1],'ini':[0xed,0xa2],'outi':[0xed,0xa3],
            'ldd':[0xed,0xa8],'cpd':[0xed,0xa9],'ind':[0xed,0xaa],'outd':[0xed,0xab],
            'ldir':[0xed,0xb0],'cpir':[0xed,0xb1],'inir':[0xed,0xb2],'otir':[0xed,0xb3],
            'lddr':[0xed,0xb8],'cpdr':[0xed,0xb9],'indr':[0xed,0xba],'otdr':[0xed,0xbb]}
        if mn in simple and n==0: return simple[mn]
        if mn=='ld': return s.enc_ld(O)
        if mn in ('add','adc','sub','sbc','and','xor','or','cp'):
            idx=['add','adc','sub','sbc','and','xor','or','cp'].index(mn)
            if n==2 and O[0].kind=='r16' and O[0].val==2 and mn in('add','adc','sbc'):
                if O[1].kind!='r16': raise AsmError('bad operand')
                if mn=='add': return [0x09+O[1].val*16]
                if mn=='adc': return [0xed,0x4a+O[1].val*16]
                return [0xed,0x42+O[1].val*16]
            if n==2 and O[0].kind=='xr' and mn=='add':
                src=O[1]
                code={'r16':None}
                if src.kind=='r16' and src.val!=2: return [O[0].pre,0x09+src.val*16]
                if src.kind=='xr' and src.pre==O[0].pre: return [O[0].pre,0x29]
                raise AsmError('bad add ix')
            if n==2:
                if O[0].kind=='r8' and O[0].val==7: src=O[1]
                else: raise AsmError('bad operand for '+mn)
            else: src=O[0]
            r=s.r8x(src)
            if r: return r[0]+[0x80+idx*8+r[1]]+r[2]
            return [0xc6+idx*8,s.b(src.expr)]
        if mn in ('inc','dec'):
            o=O[0]; d=1 if mn=='dec' else 0
            if o.kind=='r16': return [0x03+o.val*16+d*8]
            if o.kind=='xr': return [o.pre,0x23+d*8]
            r=s.r8x(o)
            return r[0]+[0x04+r[1]*8+d]+r[2]
        if mn in ('rlc','rrc','rl','rr','sla','sra','sll','srl'):
            idx=['rlc','rrc','rl','rr','sla','sra','sll','srl'].index(mn)
            r=s.r8x(O[0])
            if O[0].kind=='idx': return [O[0].pre,0xcb,s.disp(O[0]),idx*8+6]
            return [0xcb,idx*8+r[1]]
        if mn in ('bit','res','set'):
            base={'bit':0x40,'res':0x80,'set':0xc0}[mn]
            bt=s.ev(O[0].expr)
            if not 0<=bt<=7: raise AsmError('bit number')
            o=O[1]
            if o.kind=='idx': return [o.pre,0xcb,s.disp(o),base+bt*8+6]
            r=s.r8x(o); return [0xcb,base+bt*8+r[1]]
        if mn in ('jp','call'):
            if mn=='jp' and n==1 and O[0].kind=='mhl': return [0xe9]
            if mn=='jp' and n==1 and O[0].kind=='mem' and O[0].expr.lower().strip() in ('ix','iy'):
                return [0xdd if O[0].expr.lower().strip()=='ix' else 0xfd,0xe9]
            if n==2:
                c=s.cond(ops[0])
                if c is None: raise AsmError('bad condition')
                return [(0xc2 if mn=='jp' else 0xc4)+c*8]+s.w(O[1].expr)
            return [0xc3 if mn=='jp' else 0xcd]+s.w(O[0].expr)
        if mn in ('jr','djnz'):
            if mn=='djnz': op=0x10; tgt=O[0]
            elif n==2:
                c=s.cond(ops[0])
                if c is None or c>3: raise AsmError('bad jr condition')
                op=0x20+c*8; tgt=O[1]
            else: op=0x18; tgt=O[0]
            if mn=='jr' and s.curkey in s.promote:
                cc=0xc3 if n==1 else 0xc2+s.cond(ops[0])*8
                return [cc]+s.w(tgt.expr)
            t=s.ev(tgt.expr); d=t-(s.pc+2)
            if s.passno>=2 and not -128<=d<=127:
                if mn=='djnz': raise AsmError('djnz out of range (%d)'%d)
                s.promote.add(s.curkey); s.changed=True
            return [op,d&255]
        if mn=='ret':
            if n==0: return [0xc9]
            return [0xc0+s.cond(ops[0])*8]
        if mn=='rst':
            v=s.ev(O[0].expr); return [0xc7+v]
        if mn in ('push','pop'):
            o=O[0]; base=0xc5 if mn=='push' else 0xc1
            if o.kind=='xr': return [o.pre,base+0x20]
            if o.kind=='af': return [base+0x30]
            if o.kind=='r16' and o.val!=3: return [base+o.val*16]
            raise AsmError('bad push/pop')
        if mn=='ex':
            a,b2=ops[0].lower().replace(' ',''),ops[1].lower().replace(' ','')
            if a=='de' and b2=='hl': return [0xeb]
            if a=='af' and b2 in ("af'",'af'): return [0x08]
            if a=='(sp)' and b2=='hl': return [0xe3]
            if a=='(sp)' and b2 in('ix','iy'): return [0xdd if b2=='ix' else 0xfd,0xe3]
            raise AsmError('bad ex')
        if mn=='im':
            return [0xed,{0:0x46,1:0x56,2:0x5e}[s.ev(O[0].expr)]]
        if mn=='in':
            if n==2 and O[1].kind=='mem' and O[0].kind=='r8' and O[0].val==7:
                return [0xdb,s.b(O[1].expr)]
            if O[1].kind=='mc': return [0xed,0x40+O[0].val*8]
            raise AsmError('bad in')
        if mn=='out':
            if O[0].kind=='mem' and O[1].kind=='r8' and O[1].val==7: return [0xd3,s.b(O[0].expr)]
            if O[0].kind=='mc' and O[1].kind=='r8': return [0xed,0x41+O[1].val*8]
            raise AsmError('bad out')
        raise AsmError('unknown instruction '+mn)

    def enc_ld(s,O):
        d,src=O
        # 8-bit
        if d.kind in ('r8','mhl','idx','xh'):
            if d.kind=='r8' and d.val==7:
                if src.kind=='mreg': return [0x0a if src.val=='bc' else 0x1a]
                if src.kind=='mem': return [0x3a]+s.w(src.expr)
                if src.kind=='ir': return [0xed,0x57 if src.val=='i' else 0x5f]
            rs=s.r8x(src)
            rd=s.r8x(d)
            if rs:
                if d.kind in('mhl','idx') and src.kind in('mhl','idx'): raise AsmError('bad ld')
                pre=rd[0] or rs[0]
                return pre+[0x40+rd[1]*8+rs[1]]+rd[2]+rs[2]
            if src.kind=='imm':
                return rd[0]+[0x06+rd[1]*8]+rd[2]+[s.b(src.expr)]
            raise AsmError('bad ld')
        if d.kind=='mreg' and src.kind=='r8' and src.val==7: return [0x02 if d.val=='bc' else 0x12]
        if d.kind=='ir' and src.kind=='r8' and src.val==7: return [0xed,0x47 if d.val=='i' else 0x4f]
        if d.kind=='mem':
            if src.kind=='r8' and src.val==7: return [0x32]+s.w(d.expr)
            if src.kind=='r16':
                if src.val==2: return [0x22]+s.w(d.expr)
                return [0xed,0x43+src.val*16]+s.w(d.expr)
            if src.kind=='xr': return [src.pre,0x22]+s.w(d.expr)
            raise AsmError('bad ld (nn),x')
        if d.kind=='r16':
            if src.kind=='mem':
                if d.val==2: return [0x2a]+s.w(src.expr)
                return [0xed,0x4b+d.val*16]+s.w(src.expr)
            if src.kind=='imm': return [0x01+d.val*16]+s.w(src.expr)
            if d.val==3 and src.kind=='r16' and src.val==2: return [0xf9]
            if d.val==3 and src.kind=='xr': return [src.pre,0xf9]
            raise AsmError('bad ld rr')
        if d.kind=='xr':
            if src.kind=='mem': return [d.pre,0x2a]+s.w(src.expr)
            if src.kind=='imm': return [d.pre,0x21]+s.w(src.expr)
        raise AsmError('bad ld')

    # ---------- driver ----------
    def emit(s,bytes_):
        for v in bytes_:
            ph=(s.pc+s.dispoff)&0xFFFF
            if s.passno>=2:
                if ph in s.out and s.out_owner.get(ph)!=s.curkey and False: pass
                s.out[ph]=v&255
                s.minaddr=ph if s.minaddr is None else min(s.minaddr,ph)
                s.maxaddr=ph if s.maxaddr is None else max(s.maxaddr,ph)
            s.pc=(s.pc+1)&0xFFFF

    def strbytes(s,item):
        it=item.strip()
        if len(it)>=2 and it[0]=='"' and it[-1]=='"':
            return [ord(c) for c in it[1:-1].replace('\\"','"')]
        if len(it)>=3 and it[0]=="'" and it[-1]=="'" and len(it)>3:
            return [ord(c) for c in it[1:-1]]
        return None

    def line(s,ln,fname,lineno):
        # strip comment (not inside quotes)
        code=''; q=None
        for i,ch in enumerate(ln):
            if q:
                code+=ch
                if ch==q: q=None
                continue
            if ch in '"' : q=ch; code+=ch; continue
            if ch=="'" and not code.lower().rstrip().endswith('af'):
                # char literal
                q=ch; code+=ch; continue
            if ch==';': break
            code+=ch
        code=code.rstrip()
        if not code.strip(): return
        label=None
        m=re.match(r'^(\.?[A-Za-z_][\w.]*):?(?=\s|$|:)',code) if not code[0].isspace() else None
        if m:
            label=m.group(1); code=code[m.end():]
            if code.startswith(':'): code=code[1:]
        else:
            m=re.match(r'^\s*(\.?[A-Za-z_][\w.]*):(?!=)',code)
            if m: label=m.group(1); code=code[m.end():]
        parts=code.strip().split(None,1)
        mn=parts[0].lower() if parts else ''
        rest=parts[1] if len(parts)>1 else ''
        if mn in ('equ','=') or (mn.startswith('=') ):
            if mn.startswith('=') and mn!='=': rest=mn[1:]+' '+rest
            if not label: raise AsmError('equ without label')
            name=s.full(label)
            if not name.startswith('.') and not label.startswith('.'): pass
            s.syms[name]=s.ev(rest,need=True)
            return
        if label:
            if not label.startswith('.'): s.lastglobal=label
            name=s.full(label)
            if s.passno==1 and name in s.syms and s.syms[name]!=s.pc and name in s.defined:
                raise AsmError('duplicate label '+label)
            if s.passno>=2 and s.syms.get(name)!=s.pc: s.changed=True
            s.syms[name]=s.pc; s.defined.add(name)
        if not mn: return
        if mn=='org': s.pc=s.ev(rest); s.dispoff=0; return
        if mn in ('disp','phase'):
            ph=(s.pc+s.dispoff)&0xFFFF; s.pc=s.ev(rest); s.dispoff=(ph-s.pc)&0xFFFF; return
        if mn in ('ent','dephase'):
            s.pc=(s.pc+s.dispoff)&0xFFFF; s.dispoff=0; return
        if mn in ('db','defb','defm','dm','byte'):
            for it in split_ops(rest):
                sb=s.strbytes(it)
                if sb is not None: s.emit(sb)
                else: s.emit([s.b(it)])
            return
        if mn in ('dw','defw','word'):
            for it in split_ops(rest): s.emit(s.w(it))
            return
        if mn in ('ds','defs','block'):
            p=split_ops(rest); n=s.ev(p[0],need=True); f=s.ev(p[1]) if len(p)>1 else 0
            s.emit([f]*n); return
        if mn=='align':
            a=s.ev(rest); s.emit([0]*((a-s.pc%a)%a)); return
        if mn=='include':
            fn=rest.strip().strip('"')
            s.assemble_file(os.path.join(os.path.dirname(fname),fn)); return
        if mn=='incbin':
            fn=rest.strip().strip('"')
            with open(os.path.join(os.path.dirname(fname),fn),'rb') as f: s.emit(list(f.read()))
            return
        if mn=='assert':
            p=split_ops(rest)
            if s.passno>=2 and not s.ev(p[0]): raise AsmError('assertion failed: '+(p[1] if len(p)>1 else p[0]))
            return
        if mn=='savebin':
            p=split_ops(rest)
            if s.passno>=2: s.saves.append((p[0].strip().strip('"'),s.ev(p[1]),s.ev(p[2])))
            return
        if mn in ('end',): return
        s.emit(s.encode(mn,split_ops(rest)))

    def assemble_file(s,fname):
        with open(fname) as f: lines=f.read().split('\n')
        for i,ln in enumerate(lines):
            s.curkey=(fname,i)
            try: s.line(ln,fname,i+1)
            except AsmError as e:
                raise AsmError('%s:%d: %s\n    %s'%(fname,i+1,e,ln.strip()))

    def run(s,fname):
        for p in range(1,20):
            s.passno=1 if p==1 else 2
            s.pc=0; s.out={}; s.lastglobal=''; s.defined=set(); s.changed=False; s.minaddr=None
            s.dispoff=0; s.out_owner={}
            s.unresolved=False
            s.saves=[]
            s.assemble_file(fname)
            if p>1 and not s.changed: return
        raise AsmError('labels did not converge')

def main():
    if len(sys.argv)<3:
        print('usage: zasm.py src.asm out.bin [symfile]'); sys.exit(1)
    a=Assembler()
    try: a.run(sys.argv[1])
    except AsmError as e:
        print('ERROR',e); sys.exit(1)
    lo,hi=a.minaddr,a.maxaddr
    for fn,st,ln in a.saves:
        used=[i for i in range(st,st+ln) if i in a.out]
        end=(max(used)+1) if used else st
        d=bytes(a.out.get(i,0) for i in range(st,end))
        open(os.path.join(os.path.dirname(sys.argv[1]),fn),'wb').write(d)
        print('  savebin %s: %04X-%04X (%d bytes)'%(fn,st,end-1,len(d)))
    if a.saves: data=b''
    else: data=bytes(a.out.get(i,0) for i in range(lo,hi+1))
    if data: open(sys.argv[2],'wb').write(data)
    if len(sys.argv)>3:
        with open(sys.argv[3],'w') as f:
            for k,v in sorted(a.syms.items(),key=lambda x:x[1]):
                f.write('%04X %s\n'%(v&0xffff,k))
    print('assembled %s: %04X-%04X (%d bytes)'%(sys.argv[1],lo,hi,len(data)))

if __name__=='__main__': main()
