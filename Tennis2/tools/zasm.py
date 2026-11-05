#!/usr/bin/env python3
"""zasm - compact two-pass Z80 assembler (BPM / Dracula's Castle II toolchain; SAVEBIN/DEVICE/DISPLAY added for Tennis 2)
Syntax: labels 'name:' ; local labels '.name' (scoped to previous global label)
Directives: ORG EQU = DB DEFB DM DW DEFW DS DEFS INCBIN INCLUDE ALIGN ASSERT IF/ELSE/ENDIF PHASE/DEPHASE? (not)
Expressions: + - * / % & | ^ << >> ~ ! == != < > <= >= , $ , LOW() HIGH(), $hex 0xhex 12h %bin 'c'
"""
import sys, os, re

R8 = {'B':0,'C':1,'D':2,'E':3,'H':4,'L':5,'(HL)':6,'A':7}
R16SP = {'BC':0,'DE':1,'HL':2,'SP':3}
R16AF = {'BC':0,'DE':1,'HL':2,'AF':3}
CC = {'NZ':0,'Z':1,'NC':2,'C':3,'PO':4,'PE':5,'P':6,'M':7}
ALU = {'ADD':0,'ADC':1,'SUB':2,'SBC':3,'AND':4,'XOR':5,'OR':6,'CP':7}
ROT = {'RLC':0,'RRC':1,'RL':2,'RR':3,'SLA':4,'SRA':5,'SLL':6,'SL1':6,'SRL':7}

class AsmError(Exception): pass

class Asm:
    def __init__(self):
        self.sym = {}
        self.pass_no = 0
        self.out = {}
        self.listing = []
        self.undefined = False

    # ---------------- expressions ----------------
    def tok_expr(self, s):
        toks = []
        i = 0
        while i < len(s):
            c = s[i]
            if c.isspace(): i += 1; continue
            m = re.match(r"\$[0-9A-Fa-f]+|0[xX][0-9A-Fa-f]+|[0-9][0-9A-Fa-f]*[hH]\b|%[01]+|[0-9]+", s[i:])
            if m and not (c == '$' and len(m.group()) == 1):
                t = m.group()
                if t.startswith('$'): v = int(t[1:], 16)
                elif t[:2].lower() == '0x': v = int(t[2:], 16)
                elif t[-1] in 'hH': v = int(t[:-1], 16)
                elif t.startswith('%'): v = int(t[1:], 2)
                else: v = int(t)
                toks.append(('n', v)); i += len(t); continue
            if c == "'" and i + 2 < len(s) and s[i+2] == "'":
                toks.append(('n', ord(s[i+1]))); i += 3; continue
            m = re.match(r"[A-Za-z_.][A-Za-z0-9_.]*", s[i:])
            if m:
                toks.append(('id', m.group())); i += len(m.group()); continue
            if c == '$': toks.append(('n', self.pc)); i += 1; continue
            for op in ('<<','>>','<=','>=','==','!=','&&','||'):
                if s.startswith(op, i): toks.append(('op', op)); i += 2; break
            else:
                toks.append(('op', c)); i += 1
        return toks

    def resolve(self, name):
        u = name.upper()
        if name.startswith('.'): name = self.glabel + name
        if name in self.sym: return self.sym[name]
        if u in self.sym: return self.sym[u]
        if self.pass_no == 2: raise AsmError('undefined symbol ' + name)
        self.undefined = True
        return 0

    def eval(self, s):
        toks = self.tok_expr(s)
        py = []
        i = 0
        while i < len(toks):
            k, v = toks[i]
            if k == 'n': py.append(str(v))
            elif k == 'id':
                u = v.upper()
                if u in ('LOW', 'HIGH') and i+1 < len(toks) and toks[i+1] == ('op', '('):
                    py.append('_lo' if u == 'LOW' else '_hi')
                else:
                    py.append(str(self.resolve(v)))
            else:
                if v == '/': py.append('//')
                elif v == '!': py.append(' not ')
                elif v == '&&': py.append(' and ')
                elif v == '||': py.append(' or ')
                else: py.append(v)
            i += 1
        try:
            r = eval(''.join(py), {'__builtins__': {}}, {'_lo': lambda x: x & 255, '_hi': lambda x: (x >> 8) & 255})
        except Exception as e:
            raise AsmError('bad expression "%s" (%s)' % (s, e))
        return int(r)

    # ---------------- operands ----------------
    def split_ops(self, s):
        ops = []; cur = ''; depth = 0; q = None
        for c in s:
            if q:
                cur += c
                if c == q: q = None
                continue
            if c in '"\'' :
                # char literal 'x' or string
                q = c; cur += c; continue
            if c == '(': depth += 1
            if c == ')': depth -= 1
            if c == ',' and depth == 0:
                ops.append(cur.strip()); cur = ''
            else: cur += c
        if cur.strip(): ops.append(cur.strip())
        return ops

    def classify(self, op):
        """returns (kind, value) kinds: r8, r16, idx (IX/IY), ixh, ind_idx(prefix,d), ind_hl, ind_r16, ind_imm, imm, cc?, ind_c, i, r"""
        u = op.upper().replace(' ', '')
        if u in R8 and u != '(HL)': return ('r8', R8[u])
        if u == '(HL)': return ('r8', 6)
        if u in ('IXH','IXL','IYH','IYL','XH','XL','YH','YL','HX','LX','HY','LY'):
            pre = 0xDD if 'X' in u else 0xFD
            low = u in ('IXL','XL','IYL','YL','LX','LY')
            return ('ixr', (pre, 5 if low else 4))
        if u in ('BC','DE','HL','SP','AF'): return ('r16', u)
        if u == "AF'": return ('afp', 0)
        if u in ('IX','IY'): return ('idx', 0xDD if u == 'IX' else 0xFD)
        if u in ('(BC)','(DE)'): return ('ind_r16', u[1:3])
        if u == '(SP)': return ('ind_sp', 0)
        if u == '(C)': return ('ind_c', 0)
        if u == 'I': return ('i', 0)
        if u == 'R': return ('r', 0)
        m = re.match(r'^\((I[XY])([+-].*)?\)$', u)
        if m:
            pre = 0xDD if m.group(1) == 'IX' else 0xFD
            d = 0
            if m.group(2):
                # evaluate original-case expression
                inner = op.strip()[1:-1].strip()[2:]
                d = self.eval(inner) if inner.strip() else 0
            if self.pass_no == 2 and not -128 <= d <= 127: raise AsmError('index offset out of range')
            return ('ind_idx', (pre, d & 255))
        if u.startswith('(') and u.endswith(')') and self.balanced(op.strip()[1:-1]):
            return ('ind_imm', self.eval(op.strip()[1:-1]))
        return ('imm', op)

    def balanced(self, s):
        d = 0
        for c in s:
            if c == '(': d += 1
            elif c == ')':
                d -= 1
                if d < 0: return False
        return d == 0

    def imm8(self, v):
        x = self.eval(v) if isinstance(v, str) else v
        if self.pass_no == 2 and not -128 <= x <= 255: raise AsmError('byte out of range: %s = %d' % (v, x))
        return x & 255

    def imm16(self, v):
        x = self.eval(v) if isinstance(v, str) else v
        if self.pass_no == 2 and not -32768 <= x <= 65535: raise AsmError('word out of range')
        return [x & 255, (x >> 8) & 255]

    # ---------------- encoder ----------------
    def encode(self, mn, ops):
        c = [self.classify(o) for o in ops]
        k = [x[0] for x in c]
        n = len(ops)
        M = mn

        def rel(target):
            t = self.eval(target)
            d = t - (self.pc + 2)
            if self.pass_no == 2 and not -128 <= d <= 127: raise AsmError('relative jump out of range (%d)' % d)
            return d & 255

        simple = {'NOP':[0],'HALT':[0x76],'DI':[0xF3],'EI':[0xFB],'EXX':[0xD9],'RLCA':[7],'RRCA':[0xF],'RLA':[0x17],
                  'RRA':[0x1F],'DAA':[0x27],'CPL':[0x2F],'SCF':[0x37],'CCF':[0x3F],'NEG':[0xED,0x44],'RETI':[0xED,0x4D],
                  'RETN':[0xED,0x45],'RLD':[0xED,0x6F],'RRD':[0xED,0x67],'LDI':[0xED,0xA0],'LDIR':[0xED,0xB0],
                  'LDD':[0xED,0xA8],'LDDR':[0xED,0xB8],'CPI':[0xED,0xA1],'CPIR':[0xED,0xB1],'CPD':[0xED,0xA9],
                  'CPDR':[0xED,0xB9],'INI':[0xED,0xA2],'INIR':[0xED,0xB2],'IND':[0xED,0xAA],'INDR':[0xED,0xBA],
                  'OUTI':[0xED,0xA3],'OTIR':[0xED,0xB3],'OUTD':[0xED,0xAB],'OTDR':[0xED,0xBB]}
        if M in simple and n == 0: return simple[M]

        def r8code(ci):
            """returns (prefixbytes, regcode, dispbytes)"""
            kind, v = ci
            if kind == 'r8': return ([], v, [])
            if kind == 'ixr': return ([v[0]], v[1], [])
            if kind == 'ind_idx': return ([v[0]], 6, [v[1]])
            return None

        if M == 'LD':
            a, b = c
            # 8-bit register loads
            ra, rb = r8code(a), r8code(b)
            if ra and rb:
                if ra[0] and rb[0] and ra[0] != rb[0]: raise AsmError('mixed index regs')
                if (a[0] == 'ind_idx' or b[0] == 'ind_idx') and (a[0] == 'ixr' or b[0] == 'ixr'): raise AsmError('bad LD')
                if (a[0] == 'ixr' or b[0] == 'ixr') and (a[1] in (4,5) and a[0]=='r8' or b[0]=='r8' and b[1] in (4,5,6)):
                    raise AsmError('cannot mix H/L with IXH/IXL')
                if ra[1] == 6 and rb[1] == 6: raise AsmError('LD (HL),(HL)')
                pre = ra[0] or rb[0]
                return pre + [0x40 | ra[1] << 3 | rb[1]] + ra[2] + rb[2]
            if ra and b[0] == 'imm':
                return ra[0] + [0x06 | ra[1] << 3] + ra[2] + [self.imm8(b[1])]
            if a == ('r8', 7):
                if b[0] == 'ind_r16': return [0x0A if b[1] == 'BC' else 0x1A]
                if b[0] == 'ind_imm': return [0x3A] + self.imm16(b[1])
                if b[0] == 'i': return [0xED, 0x57]
                if b[0] == 'r': return [0xED, 0x5F]
            if b == ('r8', 7):
                if a[0] == 'ind_r16': return [0x02 if a[1] == 'BC' else 0x12]
                if a[0] == 'ind_imm': return [0x32] + self.imm16(a[1])
                if a[0] == 'i': return [0xED, 0x47]
                if a[0] == 'r': return [0xED, 0x4F]
            if a[0] == 'r16' and a[1] != 'AF':
                r = R16SP[a[1]]
                if b[0] == 'imm': return [0x01 | r << 4] + self.imm16(b[1])
                if b[0] == 'ind_imm':
                    if a[1] == 'HL': return [0x2A] + self.imm16(b[1])
                    return [0xED, 0x4B | r << 4] + self.imm16(b[1])
                if a[1] == 'SP' and b == ('r16', 'HL'): return [0xF9]
                if a[1] == 'SP' and b[0] == 'idx': return [b[1], 0xF9]
            if a[0] == 'idx':
                if b[0] == 'imm': return [a[1], 0x21] + self.imm16(b[1])
                if b[0] == 'ind_imm': return [a[1], 0x2A] + self.imm16(b[1])
            if a[0] == 'ind_imm':
                if b[0] == 'r16' and b[1] != 'AF':
                    if b[1] == 'HL': return [0x22] + self.imm16(a[1])
                    return [0xED, 0x43 | R16SP[b[1]] << 4] + self.imm16(a[1])
                if b[0] == 'idx': return [b[1], 0x22] + self.imm16(a[1])
            raise AsmError('bad LD operands')

        if M in ('PUSH', 'POP'):
            base = 0xC5 if M == 'PUSH' else 0xC1
            if k[0] == 'r16' and c[0][1] != 'SP': return [base | R16AF[c[0][1]] << 4]
            if k[0] == 'idx': return [c[0][1], base | 0x20]
            raise AsmError('bad PUSH/POP')

        if M == 'EX':
            a, b = c
            if a == ('r16', 'DE') and b == ('r16', 'HL'): return [0xEB]
            if a == ('r16', 'AF') and b[0] == 'afp': return [0x08]
            if a[0] == 'ind_sp':
                if b == ('r16', 'HL'): return [0xE3]
                if b[0] == 'idx': return [b[1], 0xE3]
            raise AsmError('bad EX')

        if M in ALU:
            if n == 2 and c[0] == ('r8', 7) and M in ('ADD','ADC','SBC','SUB','AND','XOR','OR','CP'):
                src = c[1]
            elif n == 1:
                src = c[0]
            else:
                src = None
            if src is not None:
                r = r8code(src)
                if r: return r[0] + [0x80 | ALU[M] << 3 | r[1]] + r[2]
                if src[0] == 'imm': return [0xC6 | ALU[M] << 3, self.imm8(src[1])]
            # 16 bit
            if n == 2:
                a, b = c
                if a == ('r16', 'HL') and b[0] == 'r16' and b[1] != 'AF':
                    r = R16SP[b[1]]
                    if M == 'ADD': return [0x09 | r << 4]
                    if M == 'ADC': return [0xED, 0x4A | r << 4]
                    if M == 'SBC': return [0xED, 0x42 | r << 4]
                if a[0] == 'idx' and M == 'ADD':
                    if b[0] == 'r16' and b[1] in ('BC','DE','SP'): return [a[1], 0x09 | R16SP[b[1]] << 4]
                    if b == a: return [a[1], 0x29]
            raise AsmError('bad ALU op')

        if M in ('INC', 'DEC'):
            a = c[0]
            r = r8code(a)
            if r: return r[0] + [(0x04 if M == 'INC' else 0x05) | r[1] << 3] + r[2]
            if a[0] == 'r16' and a[1] != 'AF': return [(0x03 if M == 'INC' else 0x0B) | R16SP[a[1]] << 4]
            if a[0] == 'idx': return [a[1], 0x23 if M == 'INC' else 0x2B]
            raise AsmError('bad INC/DEC')

        if M in ('JP', 'CALL'):
            if n == 1:
                if M == 'JP' and c[0] == ('r8', 6): return [0xE9]
                if M == 'JP' and k[0] == 'ind_idx' or k[0] == 'idx' and M == 'JP': return [c[0][1] if k[0]=='idx' else c[0][1][0], 0xE9]
                return [0xC3 if M == 'JP' else 0xCD] + self.imm16(ops[0])
            cc = CC[ops[0].upper()]
            return [(0xC2 if M == 'JP' else 0xC4) | cc << 3] + self.imm16(ops[1])

        if M == 'JR':
            if n == 1: return [0x18, rel(ops[0])]
            cc = ops[0].upper()
            if cc not in ('NZ','Z','NC','C'): raise AsmError('bad JR cond')
            return [0x20 | CC[cc] << 3, rel(ops[1])]
        if M == 'DJNZ': return [0x10, rel(ops[0])]

        if M == 'RET':
            if n == 0: return [0xC9]
            return [0xC0 | CC[ops[0].upper()] << 3]

        if M == 'RST':
            v = self.eval(ops[0])
            return [0xC7 | (v & 0x38)]

        if M == 'IM':
            return [0xED, {0: 0x46, 1: 0x56, 2: 0x5E}[self.eval(ops[0])]]

        if M in ROT or M in ('BIT', 'SET', 'RES'):
            if M in ROT:
                tgt = c[0]; base = ROT[M] << 3
                extra = c[1] if n == 2 else None
            else:
                b = self.eval(ops[0])
                tgt = c[1]; base = {'BIT': 0x40, 'RES': 0x80, 'SET': 0xC0}[M] | (b & 7) << 3
                extra = c[2] if n == 3 else None
            if tgt[0] == 'ind_idx':
                reg = 6 if extra is None else extra[1]
                return [tgt[1][0], 0xCB, tgt[1][1], base | reg]
            if tgt[0] == 'r8': return [0xCB, base | tgt[1]]
            raise AsmError('bad CB op')

        if M == 'IN':
            if n == 2 and c[1][0] == 'ind_imm' and c[0] == ('r8', 7): return [0xDB, self.imm8(c[1][1])]
            if n == 2 and c[1][0] == 'ind_c' and c[0][0] == 'r8' and c[0][1] != 6: return [0xED, 0x40 | c[0][1] << 3]
            if n == 1 and c[0][0] == 'ind_c': return [0xED, 0x70]
            raise AsmError('bad IN')
        if M == 'OUT':
            if c[0][0] == 'ind_imm' and c[1] == ('r8', 7): return [0xD3, self.imm8(c[0][1])]
            if c[0][0] == 'ind_c' and c[1][0] == 'r8' and c[1][1] != 6: return [0xED, 0x41 | c[1][1] << 3]
            if c[0][0] == 'ind_c' and c[1] == ('imm', '0'): return [0xED, 0x71]
            raise AsmError('bad OUT')
        raise AsmError('unknown instruction ' + M)

    # ---------------- driver ----------------
    def emit(self, bs):
        for b in bs:
            if self.pass_no == 2 and not self.noemit:
                if self.pc in self.out: raise AsmError('overlapping output at %04X' % self.pc)
                self.out[self.pc] = b & 255
            self.pc = (self.pc + 1) & 0xFFFF

    def parse_db(self, args):
        res = []
        for a in self.split_ops(args):
            if len(a) >= 2 and a[0] == '"' and a[-1] == '"':
                res += [ord(ch) for ch in a[1:-1]]
            elif len(a) > 3 and a[0] == "'" and a[-1] == "'":
                res += [ord(ch) for ch in a[1:-1]]
            else:
                res.append(self.imm8(a))
        return res

    def run_file(self, fname):
        base = os.path.dirname(os.path.abspath(fname))
        with open(fname) as f:
            lines = f.read().split('\n')
        for ln, line in enumerate(lines, 1):
            try:
                self.do_line(line, base)
            except AsmError as e:
                raise AsmError('%s:%d: %s\n    %s' % (fname, ln, e, line.strip()))

    def strip_comment(self, line):
        q = None; out = ''
        for i, ch in enumerate(line):
            if q:
                out += ch
                if ch == q: q = None
                continue
            if ch == '"': q = ch
            elif ch == "'" and not (out.upper().endswith('AF')):
                # char literal
                if i + 2 < len(line) and line[i+2] == "'": q = "'"
            if ch == ';': break
            out += ch
        return out.rstrip()

    def do_line(self, line, base):
        s = self.strip_comment(line)
        if not s.strip(): return
        # sjasmplus-style multiple statements: "op1 : op2" (colon with spaces, outside quotes)
        if ' :' in s or ': ' in s:
            parts = []; q = None; cur = ''
            for i, ch in enumerate(s):
                if q:
                    cur += ch
                    if ch == q: q = None
                    continue
                if ch == '"': q = ch
                if ch == ':' and 0 < i < len(s) - 1 and s[i-1].isspace() and s[i+1].isspace():
                    parts.append(cur); cur = ''; continue
                cur += ch
            parts.append(cur)
            if len(parts) > 1:
                self.do_line1(parts[0], base, line)
                for p in parts[1:]: self.do_line1(' ' + p.strip(), base, line)
                return
        self.do_line1(s, base, line)

    def do_line1(self, s, base, line):
        if not s.strip(): return
        # conditional assembly
        st = s.strip(); u = st.upper()
        if u.startswith('IF ') : self.cond.append(self.cond_on() and bool(self.eval(st[3:]))); return
        if u == 'ELSE': top = self.cond.pop(); self.cond.append((not top) and self.cond_on()); return
        if u == 'ENDIF': self.cond.pop(); return
        if not self.cond_on(): return
        label = None
        m = re.match(r'^([A-Za-z_.][A-Za-z0-9_.]*):?(\s+|$)', s) if not s[0].isspace() else None
        if m:
            label = m.group(1); s = s[m.end():]
        else:
            m = re.match(r'^\s*([A-Za-z_.][A-Za-z0-9_.]*):(\s+|$)', s)
            if m: label = m.group(1); s = s[m.end():]
        parts = s.strip().split(None, 1)
        mn = parts[0].upper() if parts else ''
        args = parts[1] if len(parts) > 1 else ''
        if mn in ('EQU', '=') or (mn == '' and False):
            name = label if not label.startswith('.') else self.glabel + label
            v = self.eval(args)
            self.sym[name] = v
            return
        if label:
            if label.startswith('.'): name = self.glabel + label
            else: name = label; self.glabel = label
            if self.pass_no == 1 and name in self.sym and self.sym[name] != self.pc and name not in self.redef:
                raise AsmError('duplicate label ' + name)
            self.sym[name] = self.pc
            if self.pass_no == 1: self.redef.discard(name)
        if not mn: return
        if mn == 'ORG': self.pc = self.eval(args); return
        if mn in ('DEVICE', 'OUTPUT', 'END'): return
        if mn == 'DISPLAY':
            if self.pass_no == 2: print('>', args)
            return
        if mn == 'SAVEBIN':
            if self.pass_no == 2:
                a = self.split_ops(args)
                self.savebins.append((os.path.join(base, a[0].strip('"')), self.eval(a[1]), self.eval(a[2])))
            return
        if mn == 'NOEMIT': self.noemit = True; return
        if mn == 'EMIT': self.noemit = False; return
        if mn in ('DB', 'DEFB', 'DM', 'DEFM', 'BYTE'): self.emit(self.parse_db(args)); return
        if mn in ('DW', 'DEFW', 'WORD'):
            for a in self.split_ops(args): self.emit(self.imm16(a))
            return
        if mn in ('DS', 'DEFS'):
            a = self.split_ops(args); cnt = self.eval(a[0]); fill = self.eval(a[1]) if len(a) > 1 else 0
            if self.pass_no == 2 and cnt < 0: raise AsmError('negative DS')
            self.emit([fill] * cnt); return
        if mn == 'ALIGN':
            al = self.eval(args)
            while self.pc % al: self.emit([0])
            return
        if mn == 'ASSERT':
            a0 = self.split_ops(args)
            if len(a0) > 1 and a0[-1].strip().startswith('"'): args = ','.join(a0[:-1])
            if self.pass_no == 2 and not self.eval(args): raise AsmError('assertion failed: ' + args)
            return
        if mn == 'INCBIN':
            fn = os.path.join(base, args.strip().strip('"'))
            self.emit(open(fn, 'rb').read()); return
        if mn == 'INCLUDE':
            fn = os.path.join(base, args.strip().strip('"'))
            self.run_file(fn); return
        ops = self.split_ops(args)
        start = self.pc
        bs = self.encode(mn, ops)
        self.emit(bs)
        if self.pass_no == 2: self.listing.append((start, bs, line))

    def cond_on(self):
        return all(self.cond)

    def assemble(self, fname):
        self.redef = set()
        for p in (1, 2):
            self.pass_no = p; self.pc = 0; self.glabel = ''; self.cond = []; self.noemit = False
            if p == 2: self.out = {}; self.savebins = []
            self.run_file(fname)
        for fn, st, ln in self.savebins:
            open(fn, 'wb').write(bytes(self.out.get(i, 0) for i in range(st, st + ln)))
        return self.out

def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('src'); ap.add_argument('-o', '--out'); ap.add_argument('--sym'); ap.add_argument('--lst')
    ap.add_argument('--start', type=lambda x: int(x, 0)); ap.add_argument('--end', type=lambda x: int(x, 0))
    a = ap.parse_args()
    asm = Asm()
    try:
        out = asm.assemble(a.src)
    except AsmError as e:
        print('ERROR:', e); sys.exit(1)
    lo = a.start if a.start is not None else min(out); hi = a.end if a.end is not None else max(out) + 1
    data = bytes(out.get(i, 0) for i in range(lo, hi))
    if a.out: open(a.out, 'wb').write(data)
    if a.sym:
        with open(a.sym, 'w') as f:
            for k, v in sorted(asm.sym.items(), key=lambda x: x[1]): f.write('%04X %s\n' % (v & 0xFFFF, k))
    if a.lst:
        with open(a.lst, 'w') as f:
            for pc, bs, line in asm.listing: f.write('%04X %-12s %s\n' % (pc, ''.join('%02X' % b for b in bs), line))
    print('assembled %04X-%04X (%d bytes)' % (lo, hi - 1, len(data)))

if __name__ == '__main__':
    main()
