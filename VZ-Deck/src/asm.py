# tiny Z80 assembler built by inverting dz.dis (no IX/IY)
import re,sys
from dz import dis
def _build():
    lit={}; tok={}
    def add(seq):
        m=bytes(seq)+bytes([0x34,0x12]); n,s=dis(m,0x1000,0x1000); ln=n-0x1000
        if s.startswith('DB ') : return
        base=bytes(seq); kind=None
        if ln==len(seq)+2 and '1234h' in s: s=s.replace('1234h','\x01'); kind='NN'
        elif ln==len(seq)+1 and (s.startswith('JR') or s.startswith('DJNZ')):
            s=re.sub(r'[0-9A-F]{4}h','\x01',s); kind='E'
        elif ln==len(seq)+1 and '34h' in s: s=s.replace('34h','\x01'); kind='N'
        elif ln!=len(seq): return
        if kind is None: lit.setdefault(s,base)
        else:
            mn=s.split(' ')[0]
            rx=re.compile(re.escape(s).replace('\x01','(.+)')+'$')
            tok.setdefault(mn,[]).append((len(s),rx,base,kind,s))
    for op in range(256):
        if op in(0xCB,0xED,0xDD,0xFD): continue
        add([op])
    for op in range(256): add([0xCB,op]); add([0xED,op])
    for k in tok: tok[k].sort(key=lambda t:-t[0])
    return lit,tok
LIT,TOK=_build()
def _norm(s):
    s=re.sub(r"'(.)'",lambda m:str(ord(m.group(1))),s)
    s=s.split(';')[0].strip()
    return s
def _one(mn,ops,ev,pc,pas):
    t=mn+((' '+re.sub(r'\s+','',ops)) if ops else '')
    tu=t.upper()
    if tu in LIT: return bytearray(LIT[tu])
    for _,rx,bs,kind,tpl in TOK.get(mn,[]):
        mm=re.match(rx.pattern,t,re.I)
        if not mm: continue
        x=mm.group(1)
        if ',' in x: continue
        if x.upper() in ('A','B','C','D','E','H','L','HL','BC','DE','SP','AF','(HL)','(BC)','(DE)','(SP)','(C)','NZ','Z','NC','PO','PE','P','M','IX','IY','I','R'): continue
        v=ev(x); b=bytearray(bs)
        if kind=='NN': b+=bytes([v&255,(v>>8)&255])
        elif kind=='N': b.append(v&255)
        else: raise Exception('relative jump with index register')
        return b
    raise Exception('cannot assemble: '+t)
def assemble(src,org=0x8000,syms=None):
    syms=dict(syms or {}); out=None
    for pas in (1,2):
        pc=org; out=bytearray(); base=org
        def ev(x):
            try: return int(eval(x,{},syms))
            except Exception as e:
                if pas==1: return 0
                raise Exception("eval %r: %s"%(x,e))
        for ln,raw in enumerate(src.split('\n'),1):
            if '"' in raw and (';' not in raw or raw.index('"')<raw.index(';')):
                pre,_,rest=raw.partition('"'); line=_norm(pre)+' "'+rest
            else: line=_norm(raw)
            if not line: continue
            m=re.match(r'^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$',line)
            if m:
                if pas==1 and m.group(1) in syms: raise Exception("line %d: duplicate label %s"%(ln,m.group(1)))
                syms[m.group(1)]=pc; line=m.group(2).strip()
                if not line: continue
            m=re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\s+EQU\s+(.+)$',line,re.I)
            if m:
                if pas==1 and m.group(1) in syms: raise Exception("line %d: duplicate name %s"%(ln,m.group(1)))
                syms[m.group(1)]=ev(m.group(2)); continue
            parts=line.split(None,1); mn=parts[0].upper(); ops=parts[1] if len(parts)>1 else ''
            b=bytearray()
            if mn=='PHASE':
                pc=ev(ops); continue
            if mn=='DEPHASE':
                pc=org+len(out); continue
            if mn=='ORG':
                v=ev(ops); assert v>=pc; b=bytearray(v-pc)
            elif mn=='DB':
                for item in re.findall(r'"[^"]*"|[^,]+',ops):
                    item=item.strip()
                    if item.startswith('"'): b+=item[1:-1].encode('ascii')
                    else: b.append(ev(item)&255)
            elif mn=='DW':
                for item in ops.split(','): v=ev(item)&0xFFFF; b+=bytes([v&255,v>>8])
            elif mn=='DS': b=bytearray(ev(ops))
            elif re.search(r'\bI[XY]\b',ops,re.I):
                pre=0xDD if re.search(r'\bIX\b',ops,re.I) else 0xFD
                m2=re.search(r'\(\s*I[XY]\s*([+-][^)]*)?\)',ops,re.I)
                if m2:
                    dexp=m2.group(1) or '+0'; dv=ev('0'+dexp)
                    sub=ops[:m2.start()]+'(HL)'+ops[m2.end():]
                    inner,_=assemble(' '+mn+' '+sub,pc,syms) if False else (None,None)
                    bb=_one(mn,sub,ev,pc,pas)
                    if bb[0]==0xCB: b=bytearray([pre,0xCB,dv&255,bb[1]])
                    else: b=bytearray([pre,bb[0],dv&255])+bb[1:]
                else:
                    sub=re.sub(r'\bI[XY]\b','HL',ops,flags=re.I)
                    bb=_one(mn,sub,ev,pc,pas); b=bytearray([pre])+bb
            else:
                t=mn+((' '+re.sub(r'\s+','',ops)) if ops else '')
                tu=t.upper()
                if tu in LIT: b+=LIT[tu]
                else:
                    done=False
                    for _,rx,bs,kind,tpl in TOK.get(mn,[]):
                        # match case-insensitively on literal part but keep operand case
                        mm=re.match(rx.pattern,t,re.I)
                        if not mm: continue
                        x=mm.group(1)
                        if ',' in x: continue
                        if x.upper() in ('A','B','C','D','E','H','L','HL','BC','DE','SP','AF','(HL)','(BC)','(DE)','(SP)','(C)','NZ','Z','NC','PO','PE','P','M','IX','IY','I','R'): continue
                        v=ev(x); b+=bs
                        if kind=='NN': b+=bytes([v&255,(v>>8)&255])
                        elif kind=='N':
                            if pas==2 and not -128<=v<=255: raise Exception("line %d: byte range %s"%(ln,raw))
                            b.append(v&255)
                        else:
                            d=v-(pc+len(bs)+1)
                            if pas==2 and not -128<=d<=127: raise Exception("line %d: JR range %d: %s"%(ln,d,raw))
                            b.append(d&255)
                        done=True; break
                    if not done: raise Exception("line %d: cannot assemble: %s"%(ln,raw))
            out+=b; pc+=len(b)
    return bytes(out),syms
if __name__=='__main__':
    # round-trip self test against DOS code
    m=open('../testfiles/VZDOS.VZ','rb').read()[24:]
    pc=0x4D48; src=[]
    while pc<0x4F9C:
        n,s=dis(m,pc,0x4000); src.append(' '+re.sub(r'([0-9A-F]{2,4})h',r'0x\1',s)); pc=n
    b,_=assemble('\n'.join(src),0x4D48)
    print('roundtrip ok' if b==m[0xD48:0xF9C] else 'MISMATCH', len(b))
    pc=0x5535; src=[]
    while pc<0x585D:
        n,s=dis(m,pc,0x4000); src.append(' '+re.sub(r'([0-9A-F]{2,4})h',r'0x\1',s)); pc=n
    b,_=assemble('\n'.join(src),0x5535)
    print('roundtrip ok' if b==m[0x1535:0x185D] else 'MISMATCH', len(b))
