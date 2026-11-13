#!/usr/bin/env python3
"""zasm - a compact sjasmplus-compatible Z80 assembler (the subset these
sources use).  Multi-pass, 64K device image, OUTPUT/SAVEBIN, MACRO, DUP/REPT,
IF/IFDEF/IFNDEF/ELSE/ENDIF, DISP/ENT, ASSERT, local .labels, ':' statements,
undocumented IXH/IXL/IYH/IYL forms.

usage: zasm.py file.asm [--sym=out.sym] [-DNAME[=v]]
"""
import sys, os, re

class AsmError(Exception):
    pass

R8 = {'b': 0, 'c': 1, 'd': 2, 'e': 3, 'h': 4, 'l': 5, '(hl)': 6, 'a': 7}
R16 = {'bc': 0, 'de': 1, 'hl': 2, 'sp': 3}
R16AF = {'bc': 0, 'de': 1, 'hl': 2, 'af': 3}
CC = {'nz': 0, 'z': 1, 'nc': 2, 'c': 3, 'po': 4, 'pe': 5, 'p': 6, 'm': 7}
IDX = {'ix': 0xDD, 'iy': 0xFD}
IDXH = {'ixh': (0xDD, 4), 'ixl': (0xDD, 5), 'iyh': (0xFD, 4), 'iyl': (0xFD, 5),
        'xh': (0xDD, 4), 'xl': (0xDD, 5), 'yh': (0xFD, 4), 'yl': (0xFD, 5)}
ALU = {'add': 0, 'adc': 1, 'sub': 2, 'sbc': 3, 'and': 4, 'xor': 5, 'or': 6, 'cp': 7}
ROT = {'rlc': 0, 'rrc': 1, 'rl': 2, 'rr': 3, 'sla': 4, 'sra': 5, 'sll': 6, 'sli': 6, 'srl': 7}
SIMPLE = {'nop': [0], 'halt': [0x76], 'di': [0xF3], 'ei': [0xFB], 'exx': [0xD9], 'rlca': [7], 'rrca': [0x0F],
          'rla': [0x17], 'rra': [0x1F], 'daa': [0x27], 'cpl': [0x2F], 'scf': [0x37], 'ccf': [0x3F],
          'neg': [0xED, 0x44], 'retn': [0xED, 0x45], 'reti': [0xED, 0x4D], 'rrd': [0xED, 0x67], 'rld': [0xED, 0x6F],
          'ldi': [0xED, 0xA0], 'cpi': [0xED, 0xA1], 'ini': [0xED, 0xA2], 'outi': [0xED, 0xA3],
          'ldd': [0xED, 0xA8], 'cpd': [0xED, 0xA9], 'ind': [0xED, 0xAA], 'outd': [0xED, 0xAB],
          'ldir': [0xED, 0xB0], 'cpir': [0xED, 0xB1], 'inir': [0xED, 0xB2], 'otir': [0xED, 0xB3],
          'lddr': [0xED, 0xB8], 'cpdr': [0xED, 0xB9], 'indr': [0xED, 0xBA], 'otdr': [0xED, 0xBB]}


def split_top(s, sep):
    """split s on sep outside quotes/parens"""
    out, cur, q, depth, i = [], '', None, 0, 0
    while i < len(s):
        ch = s[i]
        if q:
            cur += ch
            if ch == q:
                q = None
        elif ch in '"\'':
            if ch == "'" and re.search(r'(?i)\baf$', cur):
                cur += ch
            else:
                q = ch
                cur += ch
        elif ch == '(':
            depth += 1; cur += ch
        elif ch == ')':
            depth -= 1; cur += ch
        elif ch == sep and depth == 0:
            out.append(cur); cur = ''
        else:
            cur += ch
        i += 1
    out.append(cur)
    return out


def strip_comment(s):
    q = None
    for i, ch in enumerate(s):
        if q:
            if ch == q:
                q = None
        elif ch in '"\'':
            if ch == "'" and re.search(r'(?i)\baf$', s[:i]):
                continue
            q = ch
        elif ch == ';':
            return s[:i]
        elif ch == '/' and s[i:i + 2] == '//':
            return s[:i]
    return s


class Asm:
    def __init__(self, defines=None):
        self.defines = defines or {}

    # ------------------------------------------------------------- source
    def load(self, path):
        lines = []
        self._load(path, lines)
        return lines

    def _load(self, path, lines):
        with open(path, encoding='latin-1') as f:
            for n, raw in enumerate(f, 1):
                lines.append((path, n, raw.rstrip('\r\n')))

    # ------------------------------------------------------------- symbols
    def fullname(self, name):
        if name.startswith('.'):
            return self.lastglobal + name
        if name.startswith('@'):
            return name[1:]
        return name

    def lookup(self, name):
        n = self.fullname(name)
        if n in self.sym:
            return self.sym[n]
        # sjasmplus also searches the module-less form of local names
        if self.final:
            raise AsmError('undefined symbol ' + n)
        self.unresolved = True
        return 0

    # ------------------------------------------------------------- expressions
    TOK = re.compile(r"\s*(?:(?P<num>\$[0-9A-Fa-f]+|#[0-9A-Fa-f]+|0[xX][0-9A-Fa-f]+|%[01]+|[0-9][0-9A-Fa-f]*[hH]\b|[01]+[bB]\b|[0-9]+)"
                     r"|(?P<chr>'(?:[^'\\]|\\.)')|(?P<id>[.@A-Za-z_][A-Za-z0-9_.@?]*)|(?P<dollar>\$\$?)"
                     r"|(?P<op><<|>>|<=|>=|==|!=|&&|\|\||[-+*/%&|^~()<>!=?:]))")

    def eval(self, s):
        s = s.strip()
        if not s:
            raise AsmError('empty expression')
        toks = []
        pos = 0
        while pos < len(s):
            m = self.TOK.match(s, pos)
            if not m or m.end() == pos:
                if s[pos:].strip() == '':
                    break
                raise AsmError('bad expression: ' + s)
            pos = m.end()
            if m.group('num'):
                t = m.group('num')
                if t[0] in '$#':
                    v = int(t[1:], 16)
                elif t[:2].lower() == '0x':
                    v = int(t[2:], 16)
                elif t[0] == '%':
                    # binary only where an operand is expected
                    if toks and toks[-1] not in ('(', 'op'):
                        toks.append(('op', '%'))
                        v = int(t[1:], 10)
                    else:
                        v = int(t[1:], 2)
                elif t[-1] in 'hH':
                    v = int(t[:-1], 16)
                elif t[-1] in 'bB':
                    v = int(t[:-1], 2)
                else:
                    v = int(t)
                toks.append(('n', v))
            elif m.group('chr'):
                c = m.group('chr')[1:-1]
                if c.startswith('\\'):
                    c = {'n': '\n', 'r': '\r', 't': '\t', '0': '\0'}.get(c[1], c[1])
                toks.append(('n', ord(c)))
            elif m.group('id'):
                name = m.group('id')
                if name.lower() in ('high', 'low') :
                    toks.append(('fn', name.lower()))
                else:
                    toks.append(('n', self.lookup(name)))
            elif m.group('dollar'):
                toks.append(('n', self.pc))
            else:
                toks.append(('op', m.group('op')))
        self.toks = toks
        self.tp = 0
        v = self.e_ternary()
        if self.tp != len(toks):
            raise AsmError('trailing junk in expression: ' + s)
        return v

    def peek(self):
        return self.toks[self.tp] if self.tp < len(self.toks) else (None, None)

    def take(self):
        t = self.toks[self.tp]; self.tp += 1; return t

    def e_ternary(self):
        c = self.e_bin(0)
        if self.peek() == ('op', '?'):
            self.take(); a = self.e_ternary()
            if self.take() != ('op', ':'):
                raise AsmError('expected :')
            b = self.e_ternary()
            return a if c else b
        return c

    PREC = [['||'], ['&&'], ['|'], ['^'], ['&'], ['==', '!=', '='], ['<', '>', '<=', '>='], ['<<', '>>'], ['+', '-'], ['*', '/', '%']]

    def e_bin(self, lvl):
        if lvl == len(self.PREC):
            return self.e_unary()
        v = self.e_bin(lvl + 1)
        while True:
            k, o = self.peek()
            if k == 'op' and o in self.PREC[lvl]:
                self.take()
                r = self.e_bin(lvl + 1)
                if o == '||': v = int(bool(v) or bool(r))
                elif o == '&&': v = int(bool(v) and bool(r))
                elif o == '|': v |= r
                elif o == '^': v ^= r
                elif o == '&': v &= r
                elif o in ('==', '='): v = int(v == r)
                elif o == '!=': v = int(v != r)
                elif o == '<': v = int(v < r)
                elif o == '>': v = int(v > r)
                elif o == '<=': v = int(v <= r)
                elif o == '>=': v = int(v >= r)
                elif o == '<<': v <<= r
                elif o == '>>': v >>= r
                elif o == '+': v += r
                elif o == '-': v -= r
                elif o == '*': v *= r
                elif o == '/':
                    if r == 0:
                        if self.final: raise AsmError('division by zero')
                        v = 0
                    else:
                        v = int(v / r)
                elif o == '%':
                    v = 0 if r == 0 else int(v - r * int(v / r))
            else:
                return v

    def e_unary(self):
        k, o = self.peek()
        if k == 'op' and o in ('-', '+', '~', '!'):
            self.take()
            v = self.e_unary()
            return -v if o == '-' else v if o == '+' else ~v if o == '~' else int(not v)
        if k == 'fn':
            self.take()
            v = self.e_unary()
            return (v >> 8) & 255 if o == 'high' else v & 255
        if k == 'op' and o == '(':
            self.take()
            v = self.e_ternary()
            if self.take() != ('op', ')'):
                raise AsmError('expected )')
            return v
        if k == 'n':
            self.take()
            return o
        raise AsmError('bad operand in expression')

    # ------------------------------------------------------------- output
    def emit(self, bs):
        for b in bs:
            if not self.final and isinstance(b, int) is False:
                b = 0
            b &= 0xFF
            if self.device:
                self.mem[self.phys & 0xFFFF] = b
            self.stream.append(b)
            self.phys += 1
            self.pc += 1

    def byte(self, v):
        if self.final and not (-256 <= v <= 255):
            raise AsmError('byte value out of range: %d' % v)
        return v & 255

    def sbyte(self, v):
        if self.final and not (-128 <= v <= 255):
            raise AsmError('offset out of range: %d' % v)
        return v & 255

    def word(self, v):
        if self.final and not (-65536 <= v <= 65535):
            raise AsmError('word value out of range: %d' % v)
        return [v & 255, (v >> 8) & 255]

    # ------------------------------------------------------------- operands
    def operand(self, s):
        """classify an operand string -> (kind, value)"""
        t = s.strip()
        tl = t.lower()
        if tl in R8 and tl != '(hl)':
            return ('r', R8[tl])
        if re.fullmatch(r'\(\s*hl\s*\)', tl):
            return ('r', 6)
        if tl in IDXH:
            return ('xr', IDXH[tl])
        if tl in ('bc', 'de', 'hl', 'sp', 'af'):
            return ('rr', tl)
        if tl in ("af'",):
            return ('afx', 0)
        if tl in IDX:
            return ('ix', IDX[tl])
        if tl in ('i', 'r'):
            return ('ir', tl)
        if re.fullmatch(r'\(\s*(bc|de|sp)\s*\)', tl):
            return ('ind', tl.strip('() '))
        if re.fullmatch(r'\(\s*c\s*\)', tl):
            return ('ind', 'c')
        m = re.fullmatch(r'\(\s*(ix|iy)\s*(([+-]).*)?\)', tl, re.S)
        if m and self.balanced(t[1:-1]):
            off = 0
            if m.group(2):
                inner = t[1:-1].strip()[2:]
                off = self.eval(inner)
            return ('idx', (IDX[m.group(1)], off))
        if t.startswith('(') and t.endswith(')') and self.balanced(t[1:-1]):
            return ('mem', self.eval(t[1:-1]))
        return ('imm', self.eval(t))

    @staticmethod
    def balanced(s):
        d = 0
        for ch in s:
            if ch == '(':
                d += 1
            elif ch == ')':
                d -= 1
                if d < 0:
                    return False
        return d == 0

    def ccode(self, s):
        return CC.get(s.strip().lower())

    # ------------------------------------------------------------- instructions
    def instr(self, mn, args):
        ops = [a.strip() for a in split_top(args, ',')] if args.strip() else []
        m = mn.lower()
        if m in SIMPLE and not ops:
            return SIMPLE[m]
        if m == 'ld':
            return self.i_ld(ops)
        if m in ALU:
            if len(ops) == 2:
                if m in ('add', 'adc', 'sbc') and ops[0].lower() in ('hl', 'ix', 'iy'):
                    return self.i_add16(m, ops)
                if ops[0].lower() != 'a':
                    raise AsmError('bad ' + m)
                ops = ops[1:]
            k, v = self.operand(ops[0])
            n = ALU[m]
            if k == 'r':
                return [0x80 | n << 3 | v]
            if k == 'xr':
                return [v[0], 0x80 | n << 3 | v[1]]
            if k == 'idx':
                return [v[0], 0x86 | n << 3, self.sbyte(v[1])]
            if k == 'imm':
                return [0xC6 | n << 3, self.byte(v)]
            raise AsmError('bad ' + m)
        if m in ('inc', 'dec'):
            k, v = self.operand(ops[0])
            d = 0 if m == 'inc' else 1
            if k == 'r':
                return [0x04 | v << 3 | d]
            if k == 'xr':
                return [v[0], 0x04 | v[1] << 3 | d]
            if k == 'idx':
                return [v[0], 0x34 | d, self.sbyte(v[1])]
            if k == 'rr' and v != 'af':
                return [0x03 | R16[v] << 4 | d << 3]
            if k == 'ix':
                return [v, 0x23 | d << 3]
            raise AsmError('bad inc/dec')
        if m in ROT or m in ('bit', 'set', 'res'):
            return self.i_cb(m, ops)
        if m in ('jp', 'jr', 'call', 'djnz', 'ret'):
            return self.i_flow(m, ops)
        if m == 'rst':
            v = self.eval(ops[0])
            return [0xC7 | (v & 0x38)]
        if m in ('push', 'pop'):
            out = []
            for o in ops:  # sjasmplus allows push af,bc
                k, v = self.operand(o)
                base = 0xC5 if m == 'push' else 0xC1
                if k == 'rr' and v != 'sp':
                    out += [base | R16AF[v] << 4]
                elif k == 'ix':
                    out += [v, base | 0x20]
                else:
                    raise AsmError('bad push/pop')
            return out
        if m == 'ex':
            a = [o.lower().replace(' ', '') for o in ops]
            if a == ['de', 'hl'] or a == ['hl', 'de']:
                return [0xEB]
            if a[0] == 'af':
                return [0x08]
            if a[0] == '(sp)':
                if a[1] == 'hl': return [0xE3]
                if a[1] in IDX: return [IDX[a[1]], 0xE3]
            raise AsmError('bad ex')
        if m == 'im':
            return [0xED, {0: 0x46, 1: 0x56, 2: 0x5E}[self.eval(ops[0])]]
        if m == 'in':
            if len(ops) == 1:
                ops = ['f'] + ops
            k, v = self.operand(ops[1])
            r = ops[0].lower()
            if k == 'ind' and v == 'c':
                rr = 6 if r == 'f' else R8[r]
                return [0xED, 0x40 | rr << 3]
            if k == 'mem' and r == 'a':
                return [0xDB, self.byte(v)]
            raise AsmError('bad in')
        if m == 'out':
            k, v = self.operand(ops[0])
            if k == 'ind' and v == 'c':
                if ops[1].strip() == '0':
                    return [0xED, 0x71]
                return [0xED, 0x41 | R8[ops[1].lower()] << 3]
            if k == 'mem' and ops[1].lower() == 'a':
                return [0xD3, self.byte(v)]
            raise AsmError('bad out')
        raise AsmError('unknown instruction ' + mn)

    def i_add16(self, m, ops):
        d = ops[0].lower()
        k, v = self.operand(ops[1])
        if d == 'hl':
            if k != 'rr' or v == 'af':
                raise AsmError('bad 16-bit ' + m)
            if m == 'add':
                return [0x09 | R16[v] << 4]
            return [0xED, (0x4A if m == 'adc' else 0x42) | R16[v] << 4]
        if m != 'add':
            raise AsmError('bad ' + m)
        p = IDX[d]
        if k == 'rr' and v in ('bc', 'de', 'sp'):
            return [p, 0x09 | R16[v] << 4]
        if k == 'ix' and v == p:
            return [p, 0x29]
        raise AsmError('bad add ' + d)

    def i_cb(self, m, ops):
        if m in ROT:
            n = ROT[m] << 3
            tgt = ops[0]
            extra = ops[1] if len(ops) > 1 else None
        else:
            b = self.eval(ops[0])
            if self.final and not 0 <= b <= 7:
                raise AsmError('bit number')
            n = {'bit': 0x40, 'res': 0x80, 'set': 0xC0}[m] | (b & 7) << 3
            tgt = ops[1]
            extra = ops[2] if len(ops) > 2 else None
        k, v = self.operand(tgt)
        if k == 'r':
            return [0xCB, n | v]
        if k == 'idx':
            r = 6 if extra is None else R8[extra.lower()]
            return [v[0], 0xCB, self.sbyte(v[1]), n | r]
        raise AsmError('bad ' + m)

    def i_flow(self, m, ops):
        if m == 'ret':
            if not ops:
                return [0xC9]
            return [0xC0 | self.ccode(ops[0]) << 3]
        cc = None
        if len(ops) == 2:
            cc = self.ccode(ops[0])
            if cc is None:
                raise AsmError('bad condition')
            tgt = ops[1]
        else:
            tgt = ops[0]
        if m == 'jp':
            tl = tgt.lower().replace(' ', '')
            if tl in ('(hl)', 'hl'):
                return [0xE9]
            if tl in ('(ix)', 'ix', '(iy)', 'iy'):
                return [IDX[tl.strip('()')], 0xE9]
            v = self.eval(tgt)
            return ([0xC3] if cc is None else [0xC2 | cc << 3]) + self.word(v)
        if m == 'call':
            v = self.eval(tgt)
            return ([0xCD] if cc is None else [0xC4 | cc << 3]) + self.word(v)
        v = self.eval(tgt)
        rel = v - (self.pc + 2)
        if self.final and not -128 <= rel <= 127:
            raise AsmError('relative jump out of range (%d)' % rel)
        if m == 'djnz':
            return [0x10, rel & 255]
        if cc is None:
            return [0x18, rel & 255]
        if cc > 3:
            raise AsmError('jr condition')
        return [0x20 | cc << 3, rel & 255]

    def i_ld(self, ops):
        if len(ops) != 2:
            raise AsmError('ld needs two operands')
        dk, dv = self.operand(ops[0])
        sk, sv = self.operand(ops[1]) if not (ops[1].strip().lower() in ('a', 'b', 'c', 'd', 'e', 'h', 'l')) else ('r', R8[ops[1].strip().lower()])
        if dk == 'r':
            if sk == 'r':
                if dv == 6 and sv == 6:
                    raise AsmError('ld (hl),(hl)')
                return [0x40 | dv << 3 | sv]
            if sk == 'imm':
                return [0x06 | dv << 3, self.byte(sv)]
            if sk == 'idx' and dv != 6:
                return [sv[0], 0x46 | dv << 3, self.sbyte(sv[1])]
            if sk == 'xr' and dv not in (4, 5, 6):
                return [sv[0][0] if False else sv[0], 0x40 | dv << 3 | sv[1]]
            if dv == 7:
                if sk == 'ind' and sv == 'bc': return [0x0A]
                if sk == 'ind' and sv == 'de': return [0x1A]
                if sk == 'mem': return [0x3A] + self.word(sv)
                if sk == 'ir': return [0xED, 0x57 if sv == 'i' else 0x5F]
            raise AsmError('bad ld ' + ops[0])
        if dk == 'xr':
            p, r = dv
            if sk == 'imm':
                return [p, 0x06 | r << 3, self.byte(sv)]
            if sk == 'r' and sv not in (4, 5, 6):
                return [p, 0x40 | r << 3 | sv]
            if sk == 'xr' and sv[0] == p:
                return [p, 0x40 | r << 3 | sv[1]]
            raise AsmError('bad ld ' + ops[0])
        if dk == 'idx':
            if sk == 'r' and sv != 6:
                return [dv[0], 0x70 | sv, self.sbyte(dv[1])]
            if sk == 'imm':
                return [dv[0], 0x36, self.sbyte(dv[1]), self.byte(sv)]
            raise AsmError('bad ld (ix+d)')
        if dk == 'ind':
            if ops[1].strip().lower() == 'a' and dv in ('bc', 'de'):
                return [0x02 if dv == 'bc' else 0x12]
            raise AsmError('bad ld (rr)')
        if dk == 'mem':
            if sk == 'r' and sv == 7:
                return [0x32] + self.word(dv)
            if sk == 'rr':
                if sv == 'hl': return [0x22] + self.word(dv)
                if sv == 'af': raise AsmError('ld (nn),af')
                return [0xED, 0x43 | R16[sv] << 4] + self.word(dv)
            if sk == 'ix':
                return [sv, 0x22] + self.word(dv)
            raise AsmError('bad ld (nn)')
        if dk == 'rr':
            if sk == 'imm':
                if dv == 'af': raise AsmError('ld af')
                return [0x01 | R16[dv] << 4] + self.word(sv)
            if sk == 'mem':
                if dv == 'hl': return [0x2A] + self.word(sv)
                return [0xED, 0x4B | R16[dv] << 4] + self.word(sv)
            if dv == 'sp' and sk == 'rr' and sv == 'hl':
                return [0xF9]
            if dv == 'sp' and sk == 'ix':
                return [sv, 0xF9]
            # fake 16-bit register copies (sjasmplus: ld bc,de etc.)
            if sk == 'rr' and sv != 'af' and dv != 'sp' and sv != 'sp':
                hi = {'bc': (0, 1), 'de': (2, 3), 'hl': (4, 5)}
                d, s = hi[dv], hi[sv]
                return [0x40 | d[0] << 3 | s[0], 0x40 | d[1] << 3 | s[1]]
            raise AsmError('bad ld rr')
        if dk == 'ix':
            if sk == 'imm':
                return [dv, 0x21] + self.word(sv)
            if sk == 'mem':
                return [dv, 0x2A] + self.word(sv)
            raise AsmError('bad ld ix')
        if dk == 'ir':
            if sk == 'r' and sv == 7:
                return [0xED, 0x47 if dv == 'i' else 0x4F]
        raise AsmError('bad ld')

    # ------------------------------------------------------------- data
    def data(self, kind, args):
        out = []
        for a in split_top(args, ','):
            a = a.strip()
            if not a:
                continue
            if kind == 'b' and len(a) >= 2 and a[0] == '"' and a[-1] == '"':
                s = a[1:-1]
                i = 0
                while i < len(s):
                    ch = s[i]
                    if ch == '\\' and i + 1 < len(s):
                        i += 1
                        ch = {'n': '\n', 'r': '\r', 't': '\t', '0': '\0', '"': '"', '\\': '\\'}.get(s[i], s[i])
                    out.append(ord(ch))
                    i += 1
                continue
            if kind == 'b' and len(a) > 3 and a[0] == "'" and a[-1] == "'" and a.count("'") == 2:
                out += [ord(c) for c in a[1:-1]]
                continue
            v = self.eval(a)
            if kind == 'b':
                out.append(self.byte(v))
            elif kind == 'w':
                out += self.word(v)
            else:
                out += [v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >> 24) & 255]
        return out

    # ------------------------------------------------------------- driver
    def run(self, path):
        self.root = os.path.dirname(os.path.abspath(path))
        self.sym = {}
        prev = None
        for p in range(12):
            self.final = False
            self.do_pass(path)
            snap = dict(self.sym)
            if snap == prev and not self.unresolved:
                break
            prev = snap
        self.final = True
        self.do_pass(path)
        return self

    def do_pass(self, path):
        self.pc = 0
        self.phys = 0
        self.disp = None
        self.device = False
        self.mem = bytearray(65536)
        self.stream = bytearray()
        self.outputs = []          # (filename, bytearray)
        self.savebins = []
        self.cur_out = None
        self.lastglobal = ''
        self.unresolved = False
        self.macros = {}
        self.redef = set()
        self.listing_messages = []
        self.cond = []             # stack of (active, taken)
        self.defined_this_pass = set()
        for k, v in self.defines.items():
            self.sym[k] = v
            self.defined_this_pass.add(k)
        self.process(self.load(path), os.path.dirname(os.path.abspath(path)))
        if self.cur_out is not None:
            self.outputs.append(self.cur_out)

    def active(self):
        return all(c[0] for c in self.cond)

    def process(self, lines, cwd):
        i = 0
        while i < len(lines):
            src, ln, text = lines[i]
            i += 1
            try:
                i = self.line(lines, i, src, ln, text, cwd)
            except AsmError as e:
                raise AsmError('%s:%d: %s\n    %s' % (src, ln, e, text))

    def collect_block(self, lines, i, start_kw, end_kws):
        depth = 1
        body = []
        while i < len(lines):
            src, ln, text = lines[i]
            i += 1
            t = strip_comment(text).strip()
            w = t.split(None, 1)[0].upper() if t else ''
            # labels in front of keywords are not used with these blocks
            if w in start_kw:
                depth += 1
            elif w in end_kws:
                depth -= 1
                if depth == 0:
                    return body, i
            body.append((src, ln, text))
        raise AsmError('unterminated block')

    def define(self, name, value, reassign=False):
        n = self.fullname(name)
        if not reassign and n in self.defined_this_pass and self.final and self.sym.get(n) != value:
            raise AsmError('symbol redefined: ' + n)
        self.sym[n] = value
        self.defined_this_pass.add(n)

    def line(self, lines, i, src, ln, text, cwd):
        t = strip_comment(text)
        if not t.strip():
            return i
        label = None
        if t[0] not in ' \t':
            m = re.match(r'([.@A-Za-z_][A-Za-z0-9_.@?]*)(:?)', t)
            if m:
                label = m.group(1)
                rest = t[m.end():]
                # 'label = expr' / 'label equ expr'
                t = rest
        stmts = [s.strip() for s in split_top(t, ':')]
        # first statement may contain a colon-less label handled above
        first_kw = stmts[0].split(None, 1)[0].upper() if stmts[0] else ''
        # conditional assembly is processed even when inactive
        if first_kw in ('IF', 'IFDEF', 'IFNDEF', 'ELSE', 'ENDIF', 'IFN'):
            arg = stmts[0][len(first_kw):].strip()
            if first_kw == 'IF':
                v = bool(self.eval(arg)) if self.active() else False
                self.cond.append([v, v])
            elif first_kw == 'IFN':
                v = (not self.eval(arg)) if self.active() else False
                self.cond.append([v, v])
            elif first_kw == 'IFDEF':
                v = (self.fullname(arg) in self.sym) if self.active() else False
                self.cond.append([v, v])
            elif first_kw == 'IFNDEF':
                v = (self.fullname(arg) not in self.sym) if self.active() else False
                self.cond.append([v, v])
            elif first_kw == 'ELSE':
                c = self.cond[-1]
                outer = all(x[0] for x in self.cond[:-1])
                c[0] = outer and not c[1]
                c[1] = c[1] or c[0]
            else:
                self.cond.pop()
            return i
        if not self.active():
            return i
        # label definitions
        if label is not None:
            kw0 = stmts[0].split(None, 1)
            k = kw0[0].upper() if kw0 else ''
            if stmts[0].startswith('=') or k in ('EQU', 'DEFL', '='):
                expr = stmts[0][1:] if stmts[0].startswith('=') else stmts[0][len(kw0[0]):]
                v = self.eval(expr)
                self.define(label, v, reassign=(stmts[0].startswith('=') or k == 'DEFL'))
                return i
            if k == 'MACRO':
                body, i = self.collect_block(lines, i, ('MACRO',), ('ENDM',))
                params = [p.strip() for p in stmts[0][5:].split(',') if p.strip()]
                self.macros[label.upper()] = (params, body)
                return i
            if not label.startswith('.'):
                self.lastglobal = label
            self.define(label, self.pc)
        for si, s in enumerate(stmts):
            if not s:
                continue
            parts = s.split(None, 1)
            kw = parts[0]
            arg = parts[1] if len(parts) > 1 else ''
            K = kw.upper()
            if K == 'MACRO':
                body, i = self.collect_block(lines, i, ('MACRO',), ('ENDM',))
                ps = [p.strip() for p in arg.split(',')]
                name = ps[0].split()[0] if ps else ''
                first = arg.split(None, 1)
                name = first[0].rstrip(',')
                params = [p.strip() for p in (first[1] if len(first) > 1 else '').split(',') if p.strip()]
                self.macros[name.upper()] = (params, body)
                return i
            if K in ('DUP', 'REPT'):
                body, i = self.collect_block(lines, i, ('DUP', 'REPT'), ('EDUP', 'ENDR'))
                n = self.eval(arg) if arg.strip() else 0
                for _ in range(n):
                    self.process(body, cwd)
                return i
            if K in self.macros:
                params, body = self.macros[K]
                vals = [a.strip() for a in split_top(arg, ',')] if arg.strip() else []
                sub = []
                for (bs, bl, bt) in body:
                    for pn, pv in zip(params, vals):
                        bt = re.sub(r'(?<![A-Za-z0-9_.])' + re.escape(pn) + r'(?![A-Za-z0-9_])', pv, bt)
                    sub.append((bs, bl, bt))
                self.process(sub, cwd)
                continue
            self.directive_or_instr(K, kw, arg, cwd, s)
        return i

    def directive_or_instr(self, K, kw, arg, cwd, s):
        if K == 'ORG':
            v = self.eval(split_top(arg, ',')[0])
            self.pc = v
            self.phys = v
            return
        if K in ('DB', 'DEFB', 'BYTE', 'DM', 'DEFM'):
            self.emit(self.data('b', arg)); return
        if K in ('DW', 'DEFW', 'WORD'):
            self.emit(self.data('w', arg)); return
        if K in ('DD', 'DWORD'):
            self.emit(self.data('d', arg)); return
        if K in ('DS', 'DEFS', 'BLOCK'):
            a = split_top(arg, ',')
            n = self.eval(a[0])
            f = self.eval(a[1]) if len(a) > 1 else 0
            if n < 0:
                if self.final: raise AsmError('negative DS')
                n = 0
            self.emit([f] * n); return
        if K == 'ALIGN':
            a = split_top(arg, ',')
            n = self.eval(a[0]) if a[0].strip() else 4
            f = self.eval(a[1]) if len(a) > 1 else 0
            pad = (-self.pc) % n
            self.emit([f] * pad); return
        if K == 'INCLUDE':
            fn = arg.strip().strip('"<>')
            path = os.path.join(cwd, fn)
            self.process(self.load(path), os.path.dirname(path))
            return
        if K == 'INCBIN':
            a = split_top(arg, ',')
            fn = a[0].strip().strip('"')
            data = open(os.path.join(cwd, fn), 'rb').read()
            off = self.eval(a[1]) if len(a) > 1 else 0
            ln = self.eval(a[2]) if len(a) > 2 else len(data) - off
            self.emit(data[off:off + ln]); return
        if K == 'DEVICE':
            self.device = arg.strip().upper() != 'NONE'
            return
        if K == 'OUTPUT':
            if self.cur_out is not None:
                self.outputs.append(self.cur_out)
            self.cur_out = (os.path.join(cwd, arg.strip().strip('"')), len(self.stream))
            return
        if K == 'SAVEBIN':
            a = split_top(arg, ',')
            fn = a[0].strip().strip('"')
            st = self.eval(a[1])
            ln = self.eval(a[2]) if len(a) > 2 else 65536 - st
            self.savebins.append((os.path.join(cwd, fn), st, ln))
            return
        if K == 'DISP' or K == 'PHASE':
            self.disp = self.pc
            self.pc = self.eval(arg)
            return
        if K in ('ENT', 'DEPHASE', 'UNPHASE'):
            self.pc = self.phys
            self.disp = None
            return
        if K == 'ASSERT':
            a = split_top(arg, ',')
            if self.final and not self.eval(a[0]):
                raise AsmError('assertion failed: ' + arg)
            return
        if K == 'DISPLAY':
            if self.final:
                msg = ''
                for part in split_top(arg, ','):
                    p = part.strip()
                    if p.startswith('"'):
                        msg += p.strip('"')
                    elif p.upper() in ('/H', '/D', '/A'):
                        continue
                    else:
                        msg += '0x%04X' % (self.eval(p) & 0xFFFF)
                self.listing_messages.append(msg)
            return
        if K in ('END',):
            return
        if K in ('SLOT', 'PAGE', 'MODULE', 'ENDMODULE', 'OPT', 'LUA', 'ENDLUA', 'EXPORT', 'LABELSLIST', 'CSPECTMAP'):
            return
        if K in ('EQU',):
            raise AsmError('EQU without label')
        self.emit(self.instr(kw, arg))

    def write(self, symfile=None):
        stream = bytes(self.stream)
        # OUTPUT files receive emitted bytes from their start to the next OUTPUT
        outs = self.outputs
        for idx, (fn, st) in enumerate(outs):
            en = outs[idx + 1][1] if idx + 1 < len(outs) else len(stream)
            os.makedirs(os.path.dirname(fn) or '.', exist_ok=True)
            open(fn, 'wb').write(stream[st:en])
        for fn, st, ln in self.savebins:
            os.makedirs(os.path.dirname(fn) or '.', exist_ok=True)
            open(fn, 'wb').write(bytes(self.mem[st:st + ln]))
        if symfile:
            with open(symfile, 'w') as f:
                for k in sorted(self.sym):
                    f.write('%s: EQU 0x%08X\n' % (k, self.sym[k] & 0xFFFFFFFF))
        for m in self.listing_messages:
            print('> ' + m)


def main(argv):
    sym = None
    defines = {}
    src = None
    for a in argv[1:]:
        if a.startswith('--sym='):
            sym = a[6:]
        elif a.startswith('-D'):
            k, _, v = a[2:].partition('=')
            defines[k] = int(v, 0) if v else 1
        elif a.startswith('--'):
            pass
        else:
            src = a
    try:
        asm = Asm(defines).run(src)
    except AsmError as e:
        print('error:', e, file=sys.stderr)
        return 1
    cwd = os.getcwd()
    asm.write(os.path.join(cwd, sym) if sym else None)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
