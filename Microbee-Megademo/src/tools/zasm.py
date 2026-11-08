#!/usr/bin/env python3
"""zasm - a small Z80 assembler accepting the sjasmplus syntax used by
VZ-TYPE and uB-TYPE: labels (with or without ':'), .local labels (and
global.local references), EQU/=, ORG, DB/DW/DS/DZ (+DEFB/DEFW/DEFS/DEFM),
INCLUDE, INCBIN, REPT/ENDR, IF/ELSE/ENDIF, ALIGN, ASSERT, DISPLAY,
SAVEBIN, DEVICE (ignored), MACRO/ENDM (positional \\1.. or named params).
Undocumented IXH/IXL/IYH/IYL and SLL are supported.

usage: zasm.py main.asm [--sym=file] [--lst=file]
"""
import os
import re
import sys


class AsmError(Exception):
    pass


R8 = {'b': 0, 'c': 1, 'd': 2, 'e': 3, 'h': 4, 'l': 5, 'a': 7}
IXH = {'ixh': (0xDD, 4), 'ixl': (0xDD, 5), 'iyh': (0xFD, 4), 'iyl': (0xFD, 5),
       'xh': (0xDD, 4), 'xl': (0xDD, 5), 'yh': (0xFD, 4), 'yl': (0xFD, 5)}
RP = {'bc': 0, 'de': 1, 'hl': 2, 'sp': 3}
RPAF = {'bc': 0, 'de': 1, 'hl': 2, 'af': 3}
CC = {'nz': 0, 'z': 1, 'nc': 2, 'c': 3, 'po': 4, 'pe': 5, 'p': 6, 'm': 7}
ALU = {'add': 0, 'adc': 1, 'sub': 2, 'sbc': 3, 'and': 4, 'xor': 5, 'or': 6, 'cp': 7}
ROT = {'rlc': 0, 'rrc': 1, 'rl': 2, 'rr': 3, 'sla': 4, 'sra': 5, 'sll': 6, 'sl1': 6, 'srl': 7}
SIMPLE = {'nop': [0x00], 'rlca': [0x07], 'rrca': [0x0F], 'rla': [0x17], 'rra': [0x1F], 'daa': [0x27],
          'cpl': [0x2F], 'scf': [0x37], 'ccf': [0x3F], 'halt': [0x76], 'exx': [0xD9], 'di': [0xF3],
          'ei': [0xFB], 'neg': [0xED, 0x44], 'retn': [0xED, 0x45], 'reti': [0xED, 0x4D],
          'rrd': [0xED, 0x67], 'rld': [0xED, 0x6F], 'ldi': [0xED, 0xA0], 'cpi': [0xED, 0xA1],
          'ini': [0xED, 0xA2], 'outi': [0xED, 0xA3], 'ldd': [0xED, 0xA8], 'cpd': [0xED, 0xA9],
          'ind': [0xED, 0xAA], 'outd': [0xED, 0xAB], 'ldir': [0xED, 0xB0], 'cpir': [0xED, 0xB1],
          'inir': [0xED, 0xB2], 'otir': [0xED, 0xB3], 'lddr': [0xED, 0xB8], 'cpdr': [0xED, 0xB9],
          'indr': [0xED, 0xBA], 'otdr': [0xED, 0xBB]}


def split_args(s):
    """split operands at top-level commas (respecting quotes and parens)"""
    out, cur, depth, q = [], '', 0, None
    i = 0
    while i < len(s):
        ch = s[i]
        if q:
            cur += ch
            if ch == q:
                q = None
        elif ch in '"\'':
            # af' is not a quote
            if ch == "'" and cur.strip().lower() == 'af':
                cur += ch
            else:
                q = ch
                cur += ch
        elif ch == '(':
            depth += 1
            cur += ch
        elif ch == ')':
            depth -= 1
            cur += ch
        elif ch == ',' and depth == 0:
            out.append(cur.strip())
            cur = ''
        else:
            cur += ch
        i += 1
    if cur.strip() or out:
        out.append(cur.strip())
    return out


def strip_comment(line):
    q = None
    for i, ch in enumerate(line):
        if q:
            if ch == q:
                q = None
        elif ch in '"':
            q = ch
        elif ch == "'":
            # af' or a char constant 'x'
            if i + 2 < len(line) and line[i + 2] == "'":
                q = ch
            elif i >= 2 and line[i - 2:i].lower() == 'af':
                pass
            else:
                q = ch
        elif ch == ';':
            return line[:i]
    return line


TOK = re.compile(r"\s*(?:(0x[0-9a-fA-F]+|\$[0-9a-fA-F]+|%[01]+|0b[01]+|[0-9][0-9a-fA-F]*[hH]|[0-9]+)|"
                 r"('(?:[^'\\]|\\.)')|(\"(?:[^\"\\]|\\.)*\")|([A-Za-z_.@?][A-Za-z0-9_.@?]*)|"
                 r"(<<|>>|<=|>=|==|!=|&&|\|\||[-+*/%&|^~!()<>=$]))")


class Asm:
    def __init__(self, main, defines=None):
        self.main = os.path.abspath(main)
        self.base = os.path.dirname(self.main)
        self.syms = {}
        self.defines = dict(defines or {})
        self.macros = {}

    # ------------------------------------------------------------ expressions
    def num(self, t):
        tl = t.lower()
        if tl.startswith('0x'):
            return int(t[2:], 16)
        if t.startswith('$'):
            return int(t[1:], 16)
        if t.startswith('%'):
            return int(t[1:], 2)
        if tl.startswith('0b') and len(t) > 2 and all(c in '01' for c in t[2:]):
            return int(t[2:], 2)
        if tl.endswith('h'):
            return int(t[:-1], 16)
        return int(t, 10)

    def lookup(self, name):
        n = name
        if n.startswith('.'):
            n = self.glabel + n
        if n in self.syms:
            return self.syms[n]
        nl = n
        if self.final:
            raise AsmError('undefined symbol: ' + name)
        self.unresolved = True
        return 0

    def eval(self, s):
        toks = []
        pos = 0
        s = s.strip()
        while pos < len(s):
            m = TOK.match(s, pos)
            if not m or m.end() == pos:
                raise AsmError('bad expression: ' + s)
            pos = m.end()
            n, ch, st, ident, op = m.groups()
            if n is not None:
                toks.append(('n', self.num(n)))
            elif ch is not None:
                c = ch[1:-1]
                if c.startswith('\\'):
                    c = {'n': '\n', 'r': '\r', 't': '\t', '0': '\0'}.get(c[1], c[1])
                toks.append(('n', ord(c)))
            elif st is not None:
                body = st[1:-1]
                if len(body) == 1:
                    toks.append(('n', ord(body)))
                else:
                    raise AsmError('string in expression: ' + s)
            elif ident is not None:
                toks.append(('i', ident))
            else:
                toks.append(('o', op))
        self._t = toks
        self._p = 0
        v = self._expr(0)
        if self._p != len(toks):
            raise AsmError('bad expression: ' + s)
        return v

    PREC = {'||': 1, '&&': 2, '|': 3, '^': 4, '&': 5, '==': 6, '=': 6, '!=': 6, '<': 7, '>': 7, '<=': 7, '>=': 7,
            '<<': 8, '>>': 8, '+': 9, '-': 9, '*': 10, '/': 10, '%': 10}

    def _peek(self):
        return self._t[self._p] if self._p < len(self._t) else (None, None)

    def _expr(self, minp):
        left = self._unary()
        while True:
            k, v = self._peek()
            if k == 'o' and v in self.PREC and self.PREC[v] > minp:
                p = self.PREC[v]
                self._p += 1
                right = self._expr(p)
                left = self._bin(v, left, right)
            else:
                return left

    def _bin(self, op, a, b):
        if op == '+': return a + b
        if op == '-': return a - b
        if op == '*': return a * b
        if op == '/': return int(a / b) if b else 0
        if op == '%': return a % b if b else 0
        if op == '<<': return a << b
        if op == '>>': return a >> b
        if op == '&': return a & b
        if op == '|': return a | b
        if op == '^': return a ^ b
        if op in ('==', '='): return int(a == b)
        if op == '!=': return int(a != b)
        if op == '<': return int(a < b)
        if op == '>': return int(a > b)
        if op == '<=': return int(a <= b)
        if op == '>=': return int(a >= b)
        if op == '&&': return int(bool(a) and bool(b))
        if op == '||': return int(bool(a) or bool(b))
        raise AsmError(op)

    def _unary(self):
        k, v = self._peek()
        if k == 'o' and v in ('-', '+', '~', '!'):
            self._p += 1
            x = self._unary()
            return {'-': -x, '+': x, '~': ~x, '!': int(not x)}[v]
        if k == 'o' and v == '(':
            self._p += 1
            x = self._expr(0)
            if self._peek() != ('o', ')'):
                raise AsmError('missing )')
            self._p += 1
            return x
        if k == 'o' and v == '$':
            self._p += 1
            return self.pc
        if k == 'n':
            self._p += 1
            return v
        if k == 'i':
            self._p += 1
            lv = v.lower()
            if lv in ('low', 'high') and self._peek() == ('o', '('):
                self._p += 1
                x = self._expr(0)
                self._p += 1
                return (x & 0xFF) if lv == 'low' else ((x >> 8) & 0xFF)
            if lv == 'defined' and self._peek() == ('o', '('):
                self._p += 1
                k2, nm = self._peek()
                self._p += 2
                return int(nm in self.syms or nm in self.defines)
            return self.lookup(v)
        raise AsmError('bad expression')

    # ------------------------------------------------------------ output
    def emit(self, bs):
        for b in bs:
            if self.out_on:
                a = (self.pc - self.disp) & 0xFFFF
                self.mem[a] = b & 0xFF
                self.written[a] = 1
            self.pc += 1

    # ------------------------------------------------------------ operands
    def classify(self, o):
        ol = o.lower().replace(' ', '')
        if ol in R8:
            return ('r', R8[ol])
        if ol in IXH:
            return ('xr', IXH[ol])
        if ol in ('i', 'r'):
            return ('ir', ol)
        if ol in ('bc', 'de', 'hl', 'sp'):
            return ('rp', ol)
        if ol in ('af',):
            return ('af', 0)
        if ol == "af'":
            return ('af_', 0)
        if ol in ('ix', 'iy'):
            return ('xx', 0xDD if ol == 'ix' else 0xFD)
        if ol.startswith('(') and ol.endswith(')') and self.wrapped(o.strip()):
            inner = o.strip()[1:-1].strip()
            il = inner.lower().replace(' ', '')
            if il in ('bc', 'de', 'hl', 'sp', 'c'):
                return ('ind', il)
            m = re.match(r'^(ix|iy)\s*([+-].*)?$', inner, re.I)
            if m:
                d = self.eval(m.group(2)) if m.group(2) else 0
                if self.final and not -128 <= d <= 127:
                    raise AsmError('index offset out of range')
                return ('idx', (0xDD if m.group(1).lower() == 'ix' else 0xFD, d & 0xFF))
            return ('mem', self.eval(inner))
        return ('imm', o)

    @staticmethod
    def wrapped(s):
        if not (s.startswith('(') and s.endswith(')')):
            return False
        depth = 0
        for i, ch in enumerate(s):
            if ch == '(':
                depth += 1
            elif ch == ')':
                depth -= 1
                if depth == 0 and i != len(s) - 1:
                    return False
        return True

    def imm8(self, o):
        v = self.eval(o)
        if self.final and not -256 < v < 256:
            raise AsmError('byte out of range: %s = %d' % (o, v))
        return v & 0xFF

    def imm16(self, o):
        return self.eval(o) & 0xFFFF

    def rel(self, o, size=2):
        tgt = self.eval(o)
        d = tgt - (self.pc + size)
        if self.final and not -128 <= d <= 127:
            raise AsmError('relative jump out of range (%d)' % d)
        return d & 0xFF

    # ------------------------------------------------------------ instructions
    def instr(self, mn, args):
        ops = split_args(args) if args.strip() else []
        if mn in SIMPLE and not ops:
            return SIMPLE[mn]
        c = [self.classify(o) for o in ops]
        k = [x[0] for x in c]

        def r8(i):     # register / (hl) / (ix+d) operand -> (prefix, code, disp)
            t, v = c[i]
            if t == 'r':
                return (None, v, None)
            if t == 'ind' and v == 'hl':
                return (None, 6, None)
            if t == 'idx':
                return (v[0], 6, v[1])
            if t == 'xr':
                return (v[0], v[1], None)
            return None

        def wrap(pfx, body, disp=None):
            out = [] if pfx is None else [pfx]
            if disp is not None:
                out += [body[0], disp] + body[1:]
            else:
                out += body
            return out

        if mn == 'ld':
            a, b = c
            if a[0] in ('r', 'xr', 'ind', 'idx') and b[0] in ('r', 'xr', 'ind', 'idx') and \
                    not (a[0] == 'ind' and a[1] != 'hl') and not (b[0] == 'ind' and b[1] != 'hl'):
                pa, ra, da = r8(0)
                pb, rb, db = r8(1)
                if ra == 6 and rb == 6:
                    raise AsmError('ld (hl),(hl)')
                pfx = pa or pb
                if pa and pb and pa != pb:
                    raise AsmError('mixed index registers')
                if (da is not None or db is not None) and (a[0] == 'xr' or b[0] == 'xr'):
                    raise AsmError('bad ld')
                return wrap(pfx, [0x40 | (ra << 3) | rb], da if da is not None else db)
            if a[0] in ('r', 'xr', 'ind', 'idx') and b[0] == 'imm' and (a[0] != 'ind' or a[1] == 'hl'):
                pa, ra, da = r8(0)
                if da is not None:
                    return [pa, 0x06 | (ra << 3), da, self.imm8(ops[1])]
                return wrap(pa, [0x06 | (ra << 3), self.imm8(ops[1])])
            if a == ('r', 7):
                if b == ('ind', 'bc'): return [0x0A]
                if b == ('ind', 'de'): return [0x1A]
                if b[0] == 'mem': return [0x3A, b[1] & 0xFF, (b[1] >> 8) & 0xFF]
                if b == ('ir', 'i'): return [0xED, 0x57]
                if b == ('ir', 'r'): return [0xED, 0x5F]
            if b == ('r', 7):
                if a == ('ind', 'bc'): return [0x02]
                if a == ('ind', 'de'): return [0x12]
                if a[0] == 'mem': return [0x32, a[1] & 0xFF, (a[1] >> 8) & 0xFF]
                if a == ('ir', 'i'): return [0xED, 0x47]
                if a == ('ir', 'r'): return [0xED, 0x4F]
            if a[0] == 'rp' and b[0] == 'imm':
                v = self.imm16(ops[1])
                return [0x01 | (RP[a[1]] << 4), v & 0xFF, v >> 8]
            if a[0] == 'xx' and b[0] == 'imm':
                v = self.imm16(ops[1])
                return [a[1], 0x21, v & 0xFF, v >> 8]
            if a[0] == 'rp' and b[0] == 'mem':
                v = b[1] & 0xFFFF
                if a[1] == 'hl': return [0x2A, v & 0xFF, v >> 8]
                return [0xED, 0x4B | (RP[a[1]] << 4), v & 0xFF, v >> 8]
            if a[0] == 'xx' and b[0] == 'mem':
                v = b[1] & 0xFFFF
                return [a[1], 0x2A, v & 0xFF, v >> 8]
            if a[0] == 'mem' and b[0] == 'rp':
                v = a[1] & 0xFFFF
                if b[1] == 'hl': return [0x22, v & 0xFF, v >> 8]
                return [0xED, 0x43 | (RP[b[1]] << 4), v & 0xFF, v >> 8]
            if a[0] == 'mem' and b[0] == 'xx':
                v = a[1] & 0xFFFF
                return [b[1], 0x22, v & 0xFF, v >> 8]
            if a == ('rp', 'sp'):
                if b == ('rp', 'hl'): return [0xF9]
                if b[0] == 'xx': return [b[1], 0xF9]
            raise AsmError('bad ld operands')

        if mn in ALU:
            if len(ops) == 2 and c[0] == ('r', 7) and mn in ('add', 'adc', 'sub', 'sbc', 'and', 'xor', 'or', 'cp'):
                c = c[1:]
                ops = ops[1:]
                k = k[1:]
            if len(ops) == 2:
                a, b = c
                if mn in ('add', 'adc', 'sbc') and a == ('rp', 'hl') and b[0] == 'rp':
                    if mn == 'add': return [0x09 | (RP[b[1]] << 4)]
                    if mn == 'adc': return [0xED, 0x4A | (RP[b[1]] << 4)]
                    return [0xED, 0x42 | (RP[b[1]] << 4)]
                if mn == 'add' and a[0] == 'xx':
                    if b[0] == 'rp' and b[1] != 'hl': return [a[1], 0x09 | (RP[b[1]] << 4)]
                    if b[0] == 'xx' and b[1] == a[1]: return [a[1], 0x29]
                raise AsmError('bad ' + mn)
            op = ALU[mn]
            if c[0][0] == 'imm':
                return [0xC6 | (op << 3), self.imm8(ops[0])]
            p, r, d = r8(0)
            return wrap(p, [0x80 | (op << 3) | r], d)

        if mn in ('inc', 'dec'):
            t, v = c[0]
            if t == 'rp':
                return [(0x03 if mn == 'inc' else 0x0B) | (RP[v] << 4)]
            if t == 'xx':
                return [v, 0x23 if mn == 'inc' else 0x2B]
            p, r, d = r8(0)
            return wrap(p, [(0x04 if mn == 'inc' else 0x05) | (r << 3)], d)

        if mn in ROT or mn in ('bit', 'set', 'res'):
            if mn in ROT:
                base = ROT[mn] << 3
                i = 0
            else:
                b = self.eval(ops[0])
                if not 0 <= b <= 7:
                    raise AsmError('bit number')
                base = {'bit': 0x40, 'res': 0x80, 'set': 0xC0}[mn] | (b << 3)
                i = 1
            p, r, d = r8(i)
            if d is not None:
                extra = r8(i + 1)[1] if len(ops) > i + 1 else 6
                return [p, 0xCB, d, base | extra]
            return [0xCB, base | r]

        if mn in ('jp', 'jr', 'call', 'ret', 'djnz', 'rst'):
            if mn == 'ret':
                if not ops: return [0xC9]
                return [0xC0 | (CC[ops[0].lower()] << 3)]
            if mn == 'rst':
                v = self.eval(ops[0])
                return [0xC7 | (v & 0x38)]
            if mn == 'djnz':
                return [0x10, self.rel(ops[0])]
            if mn == 'jp' and len(ops) == 1:
                if c[0] == ('ind', 'hl') or c[0] == ('rp', 'hl'): return [0xE9]
                if c[0][0] == 'idx' or c[0][0] == 'xx':
                    return [c[0][1][0] if c[0][0] == 'idx' else c[0][1], 0xE9]
            if len(ops) == 2:
                cc = CC[ops[0].lower()]
                tgt = ops[1]
            else:
                cc = None
                tgt = ops[0]
            if mn == 'jr':
                if cc is not None and cc > 3:
                    raise AsmError('jr condition')
                return [0x18 if cc is None else 0x20 | (cc << 3), self.rel(tgt)]
            v = self.imm16(tgt)
            if mn == 'jp':
                return [0xC3 if cc is None else 0xC2 | (cc << 3), v & 0xFF, v >> 8]
            return [0xCD if cc is None else 0xC4 | (cc << 3), v & 0xFF, v >> 8]

        if mn in ('push', 'pop'):
            t, v = c[0]
            base = 0xC5 if mn == 'push' else 0xC1
            if t in ('rp', 'af') and (t == 'af' or v != 'sp'):
                return [base | ((3 if t == 'af' else RPAF[v]) << 4)]
            if t == 'xx':
                return [v, base | 0x20]
            raise AsmError('bad push/pop')

        if mn == 'ex':
            a, b = c
            if a[0] == 'af' and b[0] == 'af_': return [0x08]
            if a == ('rp', 'de') and b == ('rp', 'hl'): return [0xEB]
            if a == ('ind', 'sp'):
                if b == ('rp', 'hl'): return [0xE3]
                if b[0] == 'xx': return [b[1], 0xE3]
            raise AsmError('bad ex')

        if mn == 'out':
            a, b = c
            if a == ('ind', 'c'):
                if b[0] == 'imm' and self.eval(ops[1]) == 0: return [0xED, 0x71]
                return [0xED, 0x41 | (b[1] << 3)]
            if a[0] == 'mem' and b == ('r', 7):
                return [0xD3, a[1] & 0xFF]
            raise AsmError('bad out')
        if mn == 'in':
            if len(ops) == 1 and c[0] == ('ind', 'c'):
                return [0xED, 0x70]
            a, b = c
            if b == ('ind', 'c'):
                if a[0] == 'r': return [0xED, 0x40 | (a[1] << 3)]
            if a == ('r', 7) and b[0] == 'mem':
                return [0xDB, b[1] & 0xFF]
            raise AsmError('bad in')
        if mn == 'im':
            v = self.eval(ops[0])
            return [0xED, {0: 0x46, 1: 0x56, 2: 0x5E}[v]]
        raise AsmError('unknown instruction: ' + mn)

    # ------------------------------------------------------------ source handling
    def read_lines(self, path):
        with open(path, encoding='latin-1') as f:
            return [(path, i + 1, l.rstrip('\n').rstrip('\r')) for i, l in enumerate(f)]

    def resolve_path(self, name, cur):
        for base in (os.path.dirname(cur), self.base):
            p = os.path.join(base, name)
            if os.path.exists(p):
                return p
        raise AsmError('file not found: ' + name)

    def parse(self, line):
        """-> (label, mnemonic, args)"""
        s = strip_comment(line)
        if not s.strip():
            return None, None, ''
        label = None
        if s[0] not in ' \t':
            m = re.match(r'^([A-Za-z_.@?][A-Za-z0-9_.@?]*):?', s)
            if not m:
                raise AsmError('bad label')
            label = m.group(1)
            s = s[m.end():]
        else:
            m = re.match(r'^\s+([A-Za-z_.@?][A-Za-z0-9_.@?]*):(?=\s|$)', s)
            if m:
                label = m.group(1)
                s = s[m.end():]
        s = s.strip()
        if not s:
            return label, None, ''
        m = re.match(r'^(\S+)\s*(.*)$', s)
        mn, args = m.group(1), m.group(2).strip()
        if mn.startswith('='):
            return label, 'equ', mn[1:] + ' ' + args
        return label, mn, args

    def define_label(self, label, value):
        if label.startswith('.'):
            name = self.glabel + label
        else:
            name = label
            if not label.startswith('@'):
                self.glabel = label
        if self.final and name in self.defset:
            raise AsmError('label defined twice: ' + name)
        self.defset.add(name)
        if self.syms.get(name) != value:
            self.changed = True
        self.syms[name] = value

    def run_lines(self, lines):
        i = 0
        n = len(lines)
        while i < n:
            path, ln, text = lines[i]
            self.where = (path, ln, text)
            try:
                label, mn, args = self.parse(text)
            except AsmError as e:
                raise AsmError('%s:%d: %s' % (path, ln, e))
            mnl = mn.lower() if mn else None
            # conditional assembly
            if mnl in ('if', 'ifdef', 'ifndef'):
                depth = 1
                j = i + 1
                else_at = None
                while j < n:
                    _, m2, _ = self.parse(lines[j][2])
                    m2 = m2.lower() if m2 else None
                    if m2 in ('if', 'ifdef', 'ifndef'):
                        depth += 1
                    elif m2 == 'endif':
                        depth -= 1
                        if depth == 0:
                            break
                    elif m2 == 'else' and depth == 1:
                        else_at = j
                    j += 1
                if mnl == 'if':
                    cond = self.eval(args)
                else:
                    nm = args.strip()
                    cond = (nm in self.syms or nm in self.defines)
                    if mnl == 'ifndef':
                        cond = not cond
                if cond:
                    self.run_lines(lines[i + 1:else_at if else_at is not None else j])
                elif else_at is not None:
                    self.run_lines(lines[else_at + 1:j])
                i = j + 1
                continue
            if mnl in ('rept', 'dup'):
                depth = 1
                j = i + 1
                while j < n:
                    _, m2, _ = self.parse(lines[j][2])
                    m2 = m2.lower() if m2 else None
                    if m2 in ('rept', 'dup'):
                        depth += 1
                    elif m2 in ('endr', 'edup'):
                        depth -= 1
                        if depth == 0:
                            break
                    j += 1
                ra = split_args(args)
                cnt = self.eval(ra[0])
                var = ra[1].strip() if len(ra) > 1 else None
                if label:
                    self.define_label(label, self.pc)
                for k in range(cnt):
                    if var:
                        self.syms[var] = k
                    self.run_lines(lines[i + 1:j])
                i = j + 1
                continue
            if mnl == 'macro':
                name = label or split_args(args)[0]
                params = split_args(args)[1:] if not label else split_args(args)
                j = i + 1
                while j < n:
                    _, m2, _ = self.parse(lines[j][2])
                    if m2 and m2.lower() == 'endm':
                        break
                    j += 1
                self.macros[name.lower()] = ([p.strip() for p in params if p.strip()], lines[i + 1:j])
                i = j + 1
                continue
            try:
                self.line(label, mn, args, path)
            except AsmError as e:
                if str(e).startswith(path):
                    raise
                raise AsmError('%s:%d: %s\n    %s' % (os.path.basename(path), ln, e, text))
            i += 1

    def line(self, label, mn, args, path):
        mnl = mn.lower() if mn else None
        if mnl in ('equ',):
            if not label:
                raise AsmError('equ without label')
            v = self.eval(args)
            name = self.glabel + label if label.startswith('.') else label
            if self.syms.get(name) != v:
                self.changed = True
            self.syms[name] = v
            return
        if label:
            self.define_label(label, self.pc)
        if not mn:
            return
        if mnl in self.macros:
            params, body = self.macros[mnl]
            vals = split_args(args) if args else []
            self.macro_n += 1
            sub = []
            for (p, l, t) in body:
                for k, v in enumerate(vals):
                    t = t.replace('\\%d' % (k + 1), v)
                    if k < len(params):
                        t = re.sub(r'\b%s\b' % re.escape(params[k]), v, t)
                t = t.replace('\\@', str(self.macro_n))
                sub.append((p, l, t))
            self.run_lines(sub)
            return
        if mnl == 'org':
            self.pc = self.eval(args)
            self.disp = 0
            return
        if mnl in ('disp', 'phase'):
            a = self.eval(args)
            self.disp = a - (self.pc - self.disp)
            self.pc = a
            return
        if mnl in ('ent', 'dephase', 'unphase'):
            self.pc -= self.disp
            self.disp = 0
            return
        if mnl in ('device', 'end', 'opt', 'output', 'endif', 'else'):
            return
        if mnl in ('db', 'defb', 'byte', 'defm', 'dm', 'dz'):
            for a in split_args(args):
                if len(a) >= 2 and a[0] == '"' and a[-1] == '"' or (len(a) > 3 and a[0] == "'" and a[-1] == "'"):
                    body = a[1:-1]
                    out = []
                    k = 0
                    while k < len(body):
                        ch = body[k]
                        if ch == '\\' and k + 1 < len(body):
                            k += 1
                            ch = {'n': '\n', 'r': '\r', 't': '\t', '0': '\0', '\\': '\\', '"': '"'}.get(body[k], body[k])
                        out.append(ord(ch))
                        k += 1
                    self.emit(out)
                else:
                    self.emit([self.imm8(a)])
            if mnl == 'dz':
                self.emit([0])
            return
        if mnl in ('dw', 'defw', 'word'):
            for a in split_args(args):
                v = self.imm16(a)
                self.emit([v & 0xFF, v >> 8])
            return
        if mnl in ('ds', 'defs', 'block'):
            p = split_args(args)
            cnt = self.eval(p[0])
            fill = self.eval(p[1]) if len(p) > 1 else 0
            if len(p) > 1:
                self.emit([fill] * cnt)
            else:
                self.pc += cnt
            return
        if mnl == 'align':
            a = self.eval(args)
            pad = (-self.pc) % a
            self.pc += pad
            return
        if mnl == 'include':
            name = args.strip().strip('"').strip("'")
            p = self.resolve_path(name, path)
            self.run_lines(self.read_lines(p))
            return
        if mnl == 'incbin':
            p = split_args(args)
            name = p[0].strip('"').strip("'")
            fp = self.resolve_path(name, path)
            data = open(fp, 'rb').read()
            off = self.eval(p[1]) if len(p) > 1 else 0
            ln = self.eval(p[2]) if len(p) > 2 else len(data) - off
            self.emit(data[off:off + ln])
            return
        if mnl == 'assert':
            if self.final and not self.eval(args):
                raise AsmError('assertion failed: ' + args)
            return
        if mnl == 'display':
            if self.final:
                msg = ''
                hexmode = True
                for a in split_args(args):
                    if a.startswith('"'):
                        msg += a[1:-1]
                    elif a.upper() == '/D':
                        hexmode = False
                    elif a.upper() == '/H':
                        hexmode = True
                    else:
                        v = self.eval(a)
                        msg += ('%d' % v) if not hexmode else ('0x%04X' % (v & 0xFFFF))
                        hexmode = True
                self.display.append(msg)
            return
        if mnl == 'savebin':
            if self.final:
                p = split_args(args)
                name = p[0].strip('"')
                st = self.eval(p[1])
                ln = self.eval(p[2])
                self.saves.append((name, st, ln, os.path.dirname(path)))
            return
        if mnl == 'error':
            if self.final:
                raise AsmError(args)
            return
        bs = self.instr(mnl, args)
        self.emit(bs)

    def assemble(self):
        self.final = False
        prev = None
        for npass in range(12):
            self.mem = bytearray(65536)
            self.written = bytearray(65536)
            self.pc = 0
            self.glabel = ''
            self.changed = False
            self.unresolved = False
            self.display = []
            self.saves = []
            self.out_on = True
            self.disp = 0
            self.macro_n = 0
            self.redefinable = set()
            self.defset = set()
            self.run_lines(self.read_lines(self.main))
            snap = dict(self.syms)
            if not self.unresolved and snap == prev:
                break
            prev = snap
        self.final = True
        self.defset = set()
        self.mem = bytearray(65536)
        self.written = bytearray(65536)
        self.pc = 0
        self.glabel = ''
        self.display = []
        self.saves = []
        self.macro_n = 0
        self.disp = 0
        self.run_lines(self.read_lines(self.main))
        return self


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    opts = dict(a[2:].split('=', 1) for a in sys.argv[1:] if a.startswith('--') and '=' in a)
    asm = Asm(args[0])
    try:
        asm.assemble()
    except AsmError as e:
        print('error:', e)
        sys.exit(1)
    for d in asm.display:
        print('>', d)
    for (name, st, ln, d) in asm.saves:
        with open(os.path.join(os.getcwd(), name), 'wb') as f:
            f.write(asm.mem[st:st + ln])
    if 'sym' in opts:
        with open(opts['sym'], 'w') as f:
            for k in sorted(asm.syms, key=lambda k: asm.syms[k]):
                f.write('%s: equ 0x%04X\n' % (k, asm.syms[k] & 0xFFFF))


if __name__ == '__main__':
    main()
