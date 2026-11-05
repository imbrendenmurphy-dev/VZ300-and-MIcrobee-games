#!/usr/bin/env python3
"""Small two-pass Z80 assembler (documented set + IXH/IXL/IYH/IYL).
Syntax: labels 'name:' or 'name' at column 0, '.local' labels scoped to the
last global label, EQU / '=', ORG, DB/DEFB/DM, DW/DEFW, DS/DEFS, INCLUDE,
INCBIN, ALIGN, ASSERT. Expressions: + - * / % & | ^ ~ << >> ( ), $ = current
address, numbers $FF 0FFh 0xFF %1010 'c'. Usage: z80asm.py src.asm out.bin [sym]
"""
import sys, os, re

R8 = {'b':0,'c':1,'d':2,'e':3,'h':4,'l':5,'a':7}
R16 = {'bc':0,'de':1,'hl':2,'sp':3}
R16AF = {'bc':0,'de':1,'hl':2,'af':3}
CC = {'nz':0,'z':1,'nc':2,'c':3,'po':4,'pe':5,'p':6,'m':7}
ALU = {'add':0,'adc':1,'sub':2,'sbc':3,'and':4,'xor':5,'or':6,'cp':7}
ROT = {'rlc':0,'rrc':1,'rl':2,'rr':3,'sla':4,'sra':5,'sll':6,'sl1':6,'srl':7}
IXH = {'ixh':(0xDD,4),'ixl':(0xDD,5),'iyh':(0xFD,4),'iyl':(0xFD,5)}
SIMPLE = {
 'nop':[0x00],'rlca':[0x07],'rrca':[0x0F],'rla':[0x17],'rra':[0x1F],'daa':[0x27],
 'cpl':[0x2F],'scf':[0x37],'ccf':[0x3F],'halt':[0x76],'exx':[0xD9],'di':[0xF3],
 'ei':[0xFB],'neg':[0xED,0x44],'retn':[0xED,0x45],'reti':[0xED,0x4D],
 'rrd':[0xED,0x67],'rld':[0xED,0x6F],'ldi':[0xED,0xA0],'cpi':[0xED,0xA1],
 'ini':[0xED,0xA2],'outi':[0xED,0xA3],'ldd':[0xED,0xA8],'cpd':[0xED,0xA9],
 'ind':[0xED,0xAA],'outd':[0xED,0xAB],'ldir':[0xED,0xB0],'cpir':[0xED,0xB1],
 'inir':[0xED,0xB2],'otir':[0xED,0xB3],'lddr':[0xED,0xB8],'cpdr':[0xED,0xB9],
 'indr':[0xED,0xBA],'otdr':[0xED,0xBB],
}

class AsmError(Exception): pass

def split_args(s):
    out, cur, depth, q = [], '', 0, None
    for ch in s:
        if q:
            cur += ch
            if ch == q: q = None
            continue
        if ch in '"\'':
            q = ch; cur += ch; continue
        if ch == '(': depth += 1
        if ch == ')': depth -= 1
        if ch == ',' and depth == 0:
            out.append(cur.strip()); cur = ''
        else: cur += ch
    if cur.strip(): out.append(cur.strip())
    return out

def strip_comment(line):
    q = None
    for i, ch in enumerate(line):
        if q:
            if ch == q: q = None
        elif ch in '"\'':
            # treat 'x' char literal, but af' handled by caller
            if ch == "'" and line[max(0,i-2):i].lower() == 'af': continue
            q = ch
        elif ch == ';':
            return line[:i]
    return line

class Asm:
    def __init__(self):
        self.sym = {}
        self.pass_no = 1
        self.out = {}
        self.pc = 0
        self.glob = ''
        self.errors = []
        self.unresolved = False

    # ---------------- expressions ----------------
    def tok(self, s):
        toks = []
        i = 0
        while i < len(s):
            c = s[i]
            if c.isspace(): i += 1; continue
            if s[i:i+2] in ('<=', '>=', '==', '!='):
                toks.append(s[i:i+2]); i += 2; continue
            if s.startswith('<<', i) or s.startswith('>>', i):
                toks.append(s[i:i+2]); i += 2; continue
            if c in '+-*/%&|^~()': toks.append(c); i += 1; continue
            if c == "'" and i+2 < len(s) and s[i+2] == "'":
                toks.append(('n', ord(s[i+1]))); i += 3; continue
            if c == '$' and (i+1 >= len(s) or not re.match(r'[0-9a-fA-F]', s[i+1])):
                toks.append(('n', self.pc)); i += 1; continue
            m = re.match(r'\$[0-9a-fA-F]+|0x[0-9a-fA-F]+|%[01]+|[0-9][0-9a-fA-F]*[hH]\b|[0-9]+|[A-Za-z_.@][A-Za-z0-9_.@]*', s[i:])
            if not m: raise AsmError('bad expression: ' + s)
            t = m.group(0); i += len(t)
            if t[0] == '$': toks.append(('n', int(t[1:], 16)))
            elif t[:2].lower() == '0x': toks.append(('n', int(t[2:], 16)))
            elif t[0] == '%': toks.append(('n', int(t[1:], 2)))
            elif t[0].isdigit() and t[-1] in 'hH': toks.append(('n', int(t[:-1], 16)))
            elif t[0].isdigit(): toks.append(('n', int(t)))
            else: toks.append(('s', t))
        return toks

    def lookup(self, name):
        n = name
        if n.startswith('.'): n = self.glob + n
        if n in self.sym: return self.sym[n]
        if self.pass_no == 1:
            self.unresolved = True
            return 0
        raise AsmError('undefined symbol ' + name)

    def eval(self, s):
        toks = self.tok(s)
        pos = [0]
        def peek(): return toks[pos[0]] if pos[0] < len(toks) else None
        def nxt():
            t = peek(); pos[0] += 1; return t
        def prim():
            t = nxt()
            if t is None: raise AsmError('bad expression: ' + s)
            if t == '(':
                v = orx()
                if nxt() != ')': raise AsmError('missing ) in ' + s)
                return v
            if t == '-': return -prim()
            if t == '+': return prim()
            if t == '~': return ~prim()
            if isinstance(t, tuple):
                return t[1] if t[0] == 'n' else self.lookup(t[1])
            raise AsmError('bad token in ' + s)
        def mul():
            v = prim()
            while peek() in ('*', '/', '%'):
                o = nxt(); r = prim()
                if o == '*': v *= r
                elif o == '/': v = v // r if r else 0
                else: v = v % r if r else 0
            return v
        def add():
            v = mul()
            while peek() in ('+', '-'):
                o = nxt(); r = mul(); v = v + r if o == '+' else v - r
            return v
        def sh():
            v = add()
            while peek() in ('<<', '>>'):
                o = nxt(); r = add(); v = v << r if o == '<<' else v >> r
            return v
        def andx():
            v = sh()
            while peek() == '&': nxt(); v &= sh()
            return v
        def xorx():
            v = andx()
            while peek() == '^': nxt(); v ^= andx()
            return v
        def orx():
            v = xorx()
            while peek() == '|': nxt(); v |= xorx()
            return v
        def cmpx():
            v = orx()
            while peek() in ('<=', '>=', '==', '!='):
                o = nxt(); r = orx()
                v = int({'<=': v <= r, '>=': v >= r, '==': v == r, '!=': v != r}[o])
            return v
        v = cmpx()
        if pos[0] != len(toks): raise AsmError('junk in expression: ' + s)
        return v

    # ---------------- operand classification ----------------
    def op(self, a):
        """Return (kind, value...). kinds: r8, r16, ind_r16 (hl/bc/de/sp), idx (ix/iy, d),
        ixr (ix/iy reg), imm, mem, cc, i, r, af, af_, c_ind, ixh"""
        al = a.lower().replace(' ', '')
        if al in R8: return ('r8', R8[al])
        if al in ('bc','de','hl','sp'): return ('r16', al)
        if al in ('ix','iy'): return ('ixr', al)
        if al == 'af': return ('af',)
        if al == "af'": return ('af_',)
        if al == 'i': return ('i',)
        if al == 'r': return ('r',)
        if al in IXH: return ('ixh', al)
        if al == '(c)': return ('c_ind',)
        if al in ('(hl)','(bc)','(de)','(sp)'): return ('ind', al[1:-1])
        m = re.match(r'^\((ix|iy)([+-].*)?\)$', al)
        if m:
            raw = a.replace(' ', '')
            d = self.eval(raw[3:-1]) if m.group(2) else 0
            return ('idx', m.group(1), d)
        if a.strip().startswith('(') and a.strip().endswith(')'):
            # make sure the parens wrap the whole thing
            inner = a.strip()[1:-1]
            depth = 0; whole = True
            for i, ch in enumerate(inner):
                if ch == '(': depth += 1
                elif ch == ')':
                    depth -= 1
                    if depth < 0: whole = False; break
            if whole:
                return ('mem', self.eval(inner))
        return ('imm', self.eval(a))

    # ---------------- encoding ----------------
    def d8(self, d):
        if self.pass_no == 2 and not (-128 <= d <= 127): raise AsmError('index offset out of range %d' % d)
        return d & 0xFF
    def n8(self, v):
        if self.pass_no == 2 and not (-128 <= v <= 255): raise AsmError('byte out of range %d' % v)
        return v & 0xFF
    def n16(self, v):
        return [v & 0xFF, (v >> 8) & 0xFF]
    def rel(self, target, size=2):
        d = target - (self.pc + size)
        if self.pass_no == 2 and not (-128 <= d <= 127): raise AsmError('relative jump out of range (%d)' % d)
        return d & 0xFF

    def r8src(self, o):
        """For ops taking r/(hl)/(ix+d)/ixh: return (prefix bytes, regcode, disp-list)"""
        if o[0] == 'r8': return ([], o[1], [])
        if o[0] == 'ind' and o[1] == 'hl': return ([], 6, [])
        if o[0] == 'idx': return ([0xDD if o[1] == 'ix' else 0xFD], 6, [self.d8(o[2])])
        if o[0] == 'ixh': return ([IXH[o[1]][0]], IXH[o[1]][1], [])
        return None

    def encode(self, mn, args):
        if mn in ('jp','jr','call','ret') and args and args[0].lower().strip() in CC and (len(args) == 2 or mn == 'ret'):
            ops = [None] + [self.op(a) for a in args[1:]]
        else:
            ops = [self.op(a) for a in args]
        if mn in SIMPLE and not args: return list(SIMPLE[mn])
        if mn in ALU:
            if len(ops) == 2:
                if ops[0][0] == 'r8' and ops[0][1] == 7: ops = [ops[1]]
                elif mn in ('add','adc','sbc'):
                    return self.enc16alu(mn, ops)
                else: raise AsmError('bad operands')
            o = ops[0]
            s = self.r8src(o)
            k = ALU[mn]
            if s:
                p, r, d = s
                return p + [0x80 | k << 3 | r] + d
            if o[0] == 'imm': return [0xC6 | k << 3, self.n8(o[1])]
            raise AsmError('bad operands')
        if mn in ('inc','dec'):
            o = ops[0]; isdec = mn == 'dec'
            if o[0] == 'r16': return [(0x0B if isdec else 0x03) | R16[o[1]] << 4]
            if o[0] == 'ixr': return [0xDD if o[1] == 'ix' else 0xFD, 0x2B if isdec else 0x23]
            s = self.r8src(o)
            if s:
                p, r, d = s
                return p + [(0x05 if isdec else 0x04) | r << 3] + d
            raise AsmError('bad operands')
        if mn == 'ld': return self.enc_ld(ops)
        if mn in ('push','pop'):
            o = ops[0]; base = 0xC5 if mn == 'push' else 0xC1
            if o[0] == 'ixr': return [0xDD if o[1] == 'ix' else 0xFD, base + 0x20]
            if o[0] == 'af': return [base | 3 << 4]
            if o[0] == 'r16' and o[1] != 'sp': return [base | R16[o[1]] << 4]
            raise AsmError('bad operands')
        if mn in ('jp','jr','call','djnz'):
            return self.enc_jump(mn, args, ops)
        if mn == 'ret':
            if not args: return [0xC9]
            return [0xC0 | CC[args[0].lower()] << 3]
        if mn == 'rst':
            v = ops[0][1]
            return [0xC7 | (v & 0x38)]
        if mn == 'ex':
            a0, a1 = args[0].lower().replace(' ',''), args[1].lower().replace(' ','')
            if a0 == 'af' and a1 == "af'": return [0x08]
            if a0 == 'de' and a1 == 'hl': return [0xEB]
            if a0 == '(sp)' and a1 == 'hl': return [0xE3]
            if a0 == '(sp)' and a1 in ('ix','iy'): return [0xDD if a1 == 'ix' else 0xFD, 0xE3]
            raise AsmError('bad ex')
        if mn == 'im':
            return [0xED, {0:0x46,1:0x56,2:0x5E}[ops[0][1]]]
        if mn in ROT:
            o = ops[0]; k = ROT[mn]
            if o[0] == 'r8': return [0xCB, k << 3 | o[1]]
            if o[0] == 'ind': return [0xCB, k << 3 | 6]
            if o[0] == 'idx': return [0xDD if o[1]=='ix' else 0xFD, 0xCB, self.d8(o[2]), k << 3 | 6]
            raise AsmError('bad operands')
        if mn in ('bit','res','set'):
            b = self.eval(args[0]) & 7; o = ops[1]
            base = {'bit':0x40,'res':0x80,'set':0xC0}[mn]
            if o[0] == 'r8': return [0xCB, base | b << 3 | o[1]]
            if o[0] == 'ind': return [0xCB, base | b << 3 | 6]
            if o[0] == 'idx': return [0xDD if o[1]=='ix' else 0xFD, 0xCB, self.d8(o[2]), base | b << 3 | 6]
            raise AsmError('bad operands')
        if mn == 'in':
            if len(ops) == 1 and ops[0][0] == 'c_ind': return [0xED, 0x70]
            d, s = ops
            if d[0] == 'r8' and d[1] == 7 and s[0] == 'mem': return [0xDB, self.n8(s[1])]
            if d[0] == 'r8' and s[0] == 'c_ind': return [0xED, 0x40 | d[1] << 3]
            raise AsmError('bad in')
        if mn == 'out':
            d, s = ops
            if d[0] == 'mem' and s[0] == 'r8' and s[1] == 7: return [0xD3, self.n8(d[1])]
            if d[0] == 'c_ind' and s[0] == 'r8': return [0xED, 0x41 | s[1] << 3]
            if d[0] == 'c_ind' and s[0] == 'imm' and s[1] == 0: return [0xED, 0x71]
            raise AsmError('bad out')
        raise AsmError('unknown mnemonic ' + mn)

    def enc16alu(self, mn, ops):
        d, s = ops
        if d[0] == 'r16' and d[1] == 'hl' and s[0] == 'r16':
            r = R16[s[1]]
            if mn == 'add': return [0x09 | r << 4]
            if mn == 'adc': return [0xED, 0x4A | r << 4]
            if mn == 'sbc': return [0xED, 0x42 | r << 4]
        if d[0] == 'ixr' and mn == 'add':
            p = 0xDD if d[1] == 'ix' else 0xFD
            if s[0] == 'ixr' and s[1] == d[1]: return [p, 0x29]
            if s[0] == 'r16' and s[1] in ('bc','de','sp'): return [p, 0x09 | R16[s[1]] << 4]
        raise AsmError('bad 16-bit alu')

    def enc_jump(self, mn, args, ops):
        if mn == 'djnz': return [0x10, self.rel(ops[0][1])]
        if mn == 'jr':
            if self.curkey in self.longjr:
                if len(args) == 1: return [0xC3] + self.n16(ops[0][1])
                c = CC[args[0].lower()]
                return [0xC2 | c << 3] + self.n16(self.op(args[1])[1])
            tgt = ops[0][1] if len(args) == 1 else self.op(args[1])[1]
            d = tgt - (self.pc + 2)
            if self.pass_no == 2 and not (-128 <= d <= 127):
                self.newlong.add(self.curkey)
                d = 0
            if len(args) == 1: return [0x18, d & 0xFF]
            c = CC[args[0].lower()]
            if c > 3: raise AsmError('bad jr condition')
            return [0x20 | c << 3, d & 0xFF]
        if mn == 'jp':
            if len(args) == 1:
                o = ops[0]
                if o[0] == 'ind' and o[1] == 'hl': return [0xE9]
                if o[0] == 'idx' or o[0] == 'ixr': return [0xDD if o[1]=='ix' else 0xFD, 0xE9]
                if o[0] in ('imm','mem'): return [0xC3] + self.n16(o[1])
                raise AsmError('bad jp')
            c = CC[args[0].lower()]
            return [0xC2 | c << 3] + self.n16(self.op(args[1])[1])
        if mn == 'call':
            if len(args) == 1: return [0xCD] + self.n16(ops[0][1])
            c = CC[args[0].lower()]
            return [0xC4 | c << 3] + self.n16(self.op(args[1])[1])

    def enc_ld(self, ops):
        d, s = ops
        # 8-bit register / (hl) / (ix+d) / ixh
        ds, ss = self.r8src(d), self.r8src(s)
        if ds and ss:
            pd, rd, dd = ds; ps, rs, dsp = ss
            if rd == 6 and rs == 6: raise AsmError('bad ld')
            pre = pd or ps
            if pd and ps and pd != ps: raise AsmError('mixed index regs')
            # (ix+d) with h/l not allowed, ixh with (hl) not allowed - trust user
            return pre + [0x40 | rd << 3 | rs] + (dd or dsp)
        if ds and s[0] == 'imm':
            pd, rd, dd = ds
            return pd + [0x06 | rd << 3] + dd + [self.n8(s[1])]
        if d[0] == 'r8' and d[1] == 7:
            if s[0] == 'ind' and s[1] == 'bc': return [0x0A]
            if s[0] == 'ind' and s[1] == 'de': return [0x1A]
            if s[0] == 'mem': return [0x3A] + self.n16(s[1])
            if s[0] == 'i': return [0xED, 0x57]
            if s[0] == 'r': return [0xED, 0x5F]
        if s[0] == 'r8' and s[1] == 7:
            if d[0] == 'ind' and d[1] == 'bc': return [0x02]
            if d[0] == 'ind' and d[1] == 'de': return [0x12]
            if d[0] == 'mem': return [0x32] + self.n16(d[1])
            if d[0] == 'i': return [0xED, 0x47]
            if d[0] == 'r': return [0xED, 0x4F]
        if d[0] == 'r16':
            r = R16[d[1]]
            if s[0] == 'imm': return [0x01 | r << 4] + self.n16(s[1])
            if s[0] == 'mem':
                if d[1] == 'hl': return [0x2A] + self.n16(s[1])
                return [0xED, 0x4B | r << 4] + self.n16(s[1])
            if d[1] == 'sp' and s[0] == 'r16' and s[1] == 'hl': return [0xF9]
            if d[1] == 'sp' and s[0] == 'ixr': return [0xDD if s[1]=='ix' else 0xFD, 0xF9]
        if d[0] == 'ixr':
            p = 0xDD if d[1] == 'ix' else 0xFD
            if s[0] == 'imm': return [p, 0x21] + self.n16(s[1])
            if s[0] == 'mem': return [p, 0x2A] + self.n16(s[1])
        if d[0] == 'mem':
            if s[0] == 'r16':
                if s[1] == 'hl': return [0x22] + self.n16(d[1])
                return [0xED, 0x43 | R16[s[1]] << 4] + self.n16(d[1])
            if s[0] == 'ixr': return [0xDD if s[1]=='ix' else 0xFD, 0x22] + self.n16(d[1])
        raise AsmError('bad ld operands')

    # ---------------- driver ----------------
    def emit(self, bs):
        if self.virtual:
            self.pc += len(bs); return
        for b in bs:
            if self.pass_no == 2:
                a = self.pc + self.phase_off
                if a in self.out:
                    raise AsmError('overlapping output at %04X' % a)
                self.out[a] = b & 0xFF
            self.pc += 1

    def define(self, name, val):
        n = name
        if n.startswith('.'): n = self.glob + n
        if self.pass_no == 1 and n in self.sym and self.sym[n] != val and n not in self.redef:
            raise AsmError('duplicate symbol ' + name)
        self.sym[n] = val

    def run_file(self, path):
        with open(path) as f:
            lines = f.read().split('\n')
        base = os.path.dirname(path)
        for ln, raw in enumerate(lines, 1):
            self.curkey = (path, ln)
            try:
                self.line(raw, base)
            except AsmError as e:
                if self.pass_no == 2 or 'duplicate' in str(e):
                    self.errors.append('%s:%d: %s\n    %s' % (path, ln, e, raw.strip()))
            except Exception as e:
                self.errors.append('%s:%d: internal %r\n    %s' % (path, ln, e, raw.strip()))

    def line(self, raw, base):
        line = strip_comment(raw).rstrip()
        if not line.strip(): return
        label = None
        m = re.match(r'^([A-Za-z_.@][A-Za-z0-9_.@]*):?(\s+|$)', line) if not line[0].isspace() else None
        if m is None:
            m2 = re.match(r'^\s*([A-Za-z_.@][A-Za-z0-9_.@]*):(\s+|$)', line)
            if m2: m = m2
        rest = line
        if m:
            cand = m.group(1)
            if cand.lower() in SIMPLE and not line.rstrip().endswith(':') and line[0].isspace():
                pass
            else:
                label = cand
                rest = line[m.end():]
        rest = rest.strip()
        parts = rest.split(None, 1)
        mn = parts[0].lower() if parts else ''
        argstr = parts[1] if len(parts) > 1 else ''
        if mn in ('equ', '=') or (label and rest.startswith('=')):
            if rest.startswith('='): argstr = rest[1:]
            v = self.eval(argstr)
            self.define(label, v)
            return
        if label:
            if not label.startswith('.'): self.glob = label
            self.define(label, self.pc)
        if not mn: return
        if mn == 'org':
            self.pc = self.eval(argstr); return
        if mn == 'dsect':
            self.saved_pc = self.pc; self.virtual = True
            self.pc = self.eval(argstr); return
        if mn == 'phase':
            v = self.eval(argstr)
            self.phase_off = self.pc + self.phase_off - v
            self.pc = v; return
        if mn == 'dephase':
            self.pc = self.pc + self.phase_off; self.phase_off = 0; return
        if mn == 'dend':
            self.virtual = False; self.pc = self.saved_pc; return
        if mn in ('db','defb','dm','defm','byte'):
            for a in split_args(argstr):
                if len(a) >= 2 and a[0] == a[-1] and a[0] in '"' :
                    self.emit([ord(c) for c in a[1:-1]])
                elif len(a) > 3 and a[0] == "'" and a[-1] == "'":
                    self.emit([ord(c) for c in a[1:-1]])
                else:
                    self.emit([self.n8(self.eval(a))])
            return
        if mn in ('dw','defw','word'):
            for a in split_args(argstr): self.emit(self.n16(self.eval(a)))
            return
        if mn in ('ds','defs','block'):
            a = split_args(argstr)
            n = self.eval(a[0]); fill = self.eval(a[1]) if len(a) > 1 else 0
            self.emit([fill] * n); return
        if mn == 'align':
            n = self.eval(argstr)
            while self.pc % n: self.emit([0])
            return
        if mn == 'include':
            p = argstr.strip().strip('"\'')
            self.run_file(os.path.join(base, p)); return
        if mn == 'incbin':
            p = argstr.strip().strip('"\'')
            with open(os.path.join(base, p), 'rb') as f: self.emit(list(f.read()))
            return
        if mn == 'assert':
            if self.pass_no == 2 and not self.eval(argstr):
                raise AsmError('assertion failed: ' + argstr)
            return
        if mn == 'display':
            if self.pass_no == 2:
                print('  ', argstr, '=', hex(self.eval(argstr)))
            return
        args = split_args(argstr)
        self.emit(self.encode(mn, args))

    def assemble(self, path):
        self.redef = set()
        self.longjr = set()
        for it in range(20):
            self.newlong = set()
            self.errors = []
            for p in (1, 2):
                self.pass_no = p
                self.pc = 0; self.glob = ''
                if p == 1: self.sym = {}
                self.out = {}; self.ds_area = set(); self.virtual = False; self.phase_off = 0
                self.run_file(path)
                if self.errors: break
            if self.errors or not self.newlong: break
            self.longjr |= self.newlong
        if self.longjr: print('%d jr relaxed to jp' % len(self.longjr))
        return self.errors

def main():
    src, outp = sys.argv[1], sys.argv[2]
    a = Asm()
    errs = a.assemble(src)
    if errs:
        print('\n'.join(errs[:40])); print('%d errors' % len(errs)); sys.exit(1)
    lo, hi = min(a.out), max(a.out)
    data = bytes(a.out.get(i, 0) for i in range(lo, hi + 1))
    with open(outp, 'wb') as f: f.write(data)
    print('assembled %04X-%04X (%d bytes)' % (lo, hi, len(data)))
    if len(sys.argv) > 3:
        with open(sys.argv[3], 'w') as f:
            for k, v in sorted(a.sym.items(), key=lambda kv: kv[1]):
                f.write('%04X %s\n' % (v & 0xFFFF, k))

if __name__ == '__main__':
    main()
