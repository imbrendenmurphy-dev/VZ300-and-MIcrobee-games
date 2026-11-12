"""Small two-pass Z80 assembler (subset of standard syntax) for the VZ flight sim.

Syntax notes
  label:            global label (sets scope for .local labels)
  .loc:             local label
  name equ expr     constant (does not change scope)
  org/db/dw/ds/align/include
  numbers: 123, $7f, 0x7f, %1010, 'A'
  $ = current address, high(x), low(x)
"""
import re, os

R8 = {'b': 0, 'c': 1, 'd': 2, 'e': 3, 'h': 4, 'l': 5, '(hl)': 6, 'a': 7}
R16 = {'bc': 0, 'de': 1, 'hl': 2, 'sp': 3}
R16A = {'bc': 0, 'de': 1, 'hl': 2, 'af': 3}
CC = {'nz': 0, 'z': 1, 'nc': 2, 'c': 3, 'po': 4, 'pe': 5, 'p': 6, 'm': 7}
ALU = {'add': 0, 'adc': 1, 'sub': 2, 'sbc': 3, 'and': 4, 'xor': 5, 'or': 6, 'cp': 7}
ROT = {'rlc': 0, 'rrc': 1, 'rl': 2, 'rr': 3, 'sla': 4, 'sra': 5, 'sll': 6, 'srl': 7}
SIMPLE = {
    'nop': [0], 'halt': [0x76], 'di': [0xF3], 'ei': [0xFB], 'daa': [0x27], 'cpl': [0x2F],
    'scf': [0x37], 'ccf': [0x3F], 'rlca': [0x07], 'rrca': [0x0F], 'rla': [0x17], 'rra': [0x1F],
    'exx': [0xD9], 'neg': [0xED, 0x44], 'ldi': [0xED, 0xA0], 'ldir': [0xED, 0xB0],
    'ldd': [0xED, 0xA8], 'lddr': [0xED, 0xB8], 'cpi': [0xED, 0xA1], 'cpir': [0xED, 0xB1],
    'reti': [0xED, 0x4D], 'retn': [0xED, 0x45], 'rld': [0xED, 0x6F], 'rrd': [0xED, 0x67],
}


class AsmError(Exception):
    pass


class NS(dict):
    def __init__(self, asm):
        super().__init__()
        self.asm = asm

    def __missing__(self, k):
        if self.asm.final:
            raise AsmError('undefined symbol ' + k)
        self.asm.unresolved = True
        return 0


class Asm:
    def __init__(self, incpath='.'):
        self.incpath = incpath
        self.sym = NS(self)
        self.sym['high'] = lambda x: (x >> 8) & 255
        self.sym['low'] = lambda x: x & 255
        self.final = False

    # ---------------------------------------------------------------- utils
    @staticmethod
    def strip_comment(s):
        out = []
        q = None
        for ch in s:
            if q:
                out.append(ch)
                if ch == q:
                    q = None
            elif ch in '"\'':
                q = ch
                out.append(ch)
            elif ch == ';':
                break
            else:
                out.append(ch)
        return ''.join(out).rstrip()

    @staticmethod
    def lower_keep_quotes(s):
        out = []
        q = None
        for ch in s:
            if q:
                out.append(ch)
                if ch == q:
                    q = None
            elif ch in '"\'':
                q = ch
                out.append(ch)
            else:
                out.append(ch.lower())
        return ''.join(out)

    @staticmethod
    def split_ops(s):
        ops = []
        depth = 0
        q = None
        cur = ''
        for ch in s:
            if q:
                cur += ch
                if ch == q:
                    q = None
            elif ch in '"\'':
                q = ch
                cur += ch
            elif ch == '(':
                depth += 1
                cur += ch
            elif ch == ')':
                depth -= 1
                cur += ch
            elif ch == ',' and depth == 0:
                ops.append(cur.strip())
                cur = ''
            else:
                cur += ch
        if cur.strip():
            ops.append(cur.strip())
        return ops

    @staticmethod
    def isind(o):
        if not (o.startswith('(') and o.endswith(')')):
            return False
        d = 0
        for i, ch in enumerate(o):
            if ch == '(':
                d += 1
            elif ch == ')':
                d -= 1
                if d == 0 and i != len(o) - 1:
                    return False
        return True

    def ev(self, e):
        e = e.strip()
        e = re.sub(r"'(.)'", lambda m: str(ord(m.group(1))), e)
        e = re.sub(r"\$([0-9a-f]+)", r"0x\1", e)
        e = re.sub(r"(?<![\w)])%([01]+)", r"0b\1", e)
        e = e.replace('$', str(self.pc))
        e = re.sub(r"(?<![\w.])\.([a-z_]\w*)", lambda m: self.scope + '__' + m.group(1), e)
        e = re.sub(r"(?<!/)/(?!/)", '//', e)
        try:
            return int(eval(e, {'__builtins__': {}}, self.sym))
        except AsmError:
            raise
        except Exception as ex:
            raise AsmError('bad expression "%s": %s' % (e, ex))

    # ------------------------------------------------------------- encoder
    def enc(self, mn, ops):
        ev = self.ev
        n = len(ops)
        isind = self.isind

        def idx(o):
            m = re.match(r'^\((ix|iy)\s*(.*)\)$', o)
            if m:
                return (0xDD if m.group(1) == 'ix' else 0xFD, m.group(2) or '0')
            return None

        def b8(e):
            v = ev(e)
            if self.final and not -128 <= v <= 255:
                raise AsmError('8-bit value out of range: %d' % v)
            return v & 0xFF

        def d8(e):
            v = ev(e)
            if self.final and not -128 <= v <= 127:
                raise AsmError('displacement out of range: %d' % v)
            return v & 0xFF

        def w16(e):
            v = ev(e)
            if self.final and not -32768 <= v <= 65535:
                raise AsmError('16-bit value out of range: %d' % v)
            return [v & 0xFF, (v >> 8) & 0xFF]

        def rel(e):
            v = ev(e) - (self.pc + 2)
            if self.final and not -128 <= v <= 127:
                raise AsmError('relative jump out of range: %d' % v)
            return v & 0xFF

        def pfx(r):
            return 0xDD if r == 'ix' else 0xFD

        if mn in SIMPLE and n == 0:
            return list(SIMPLE[mn])

        if mn == 'ld':
            a, b = ops
            if a in R8 and b in R8 and not (a == '(hl)' and b == '(hl)'):
                return [0x40 | R8[a] << 3 | R8[b]]
            ia, ib = idx(a), idx(b)
            if a in R8 and a != '(hl)' and ib:
                return [ib[0], 0x46 | R8[a] << 3, d8(ib[1])]
            if ia and b in R8 and b != '(hl)':
                return [ia[0], 0x70 | R8[b], d8(ia[1])]
            if ia:
                return [ia[0], 0x36, d8(ia[1]), b8(b)]
            if a == 'a':
                if b == '(bc)': return [0x0A]
                if b == '(de)': return [0x1A]
                if b == 'i': return [0xED, 0x57]
                if b == 'r': return [0xED, 0x5F]
                if isind(b): return [0x3A] + w16(b[1:-1])
            if b == 'a':
                if a == '(bc)': return [0x02]
                if a == '(de)': return [0x12]
                if a == 'i': return [0xED, 0x47]
                if a == 'r': return [0xED, 0x4F]
                if isind(a): return [0x32] + w16(a[1:-1])
            if a in R8 and not isind(b):
                return [0x06 | R8[a] << 3, b8(b)]
            if a == 'sp' and b == 'hl': return [0xF9]
            if a == 'sp' and b in ('ix', 'iy'): return [pfx(b), 0xF9]
            if a in R16:
                if isind(b):
                    if a == 'hl': return [0x2A] + w16(b[1:-1])
                    return [0xED, 0x4B | R16[a] << 4] + w16(b[1:-1])
                return [0x01 | R16[a] << 4] + w16(b)
            if a in ('ix', 'iy'):
                if isind(b): return [pfx(a), 0x2A] + w16(b[1:-1])
                return [pfx(a), 0x21] + w16(b)
            if isind(a):
                if b == 'hl': return [0x22] + w16(a[1:-1])
                if b in R16: return [0xED, 0x43 | R16[b] << 4] + w16(a[1:-1])
                if b in ('ix', 'iy'): return [pfx(b), 0x22] + w16(a[1:-1])
            raise AsmError('bad ld operands')

        if mn in ALU:
            if n == 2 and ops[0] == 'hl':
                p = R16[ops[1]]
                if mn == 'add': return [0x09 | p << 4]
                if mn == 'adc': return [0xED, 0x4A | p << 4]
                if mn == 'sbc': return [0xED, 0x42 | p << 4]
                raise AsmError('bad 16-bit alu')
            if n == 2 and ops[0] in ('ix', 'iy') and mn == 'add':
                mp = {'bc': 0, 'de': 1, ops[0]: 2, 'sp': 3}
                return [pfx(ops[0]), 0x09 | mp[ops[1]] << 4]
            if n == 2 and ops[0] != 'a':
                raise AsmError('bad alu operands')
            s = ops[-1]
            k = ALU[mn]
            if s in R8: return [0x80 | k << 3 | R8[s]]
            i = idx(s)
            if i: return [i[0], 0x86 | k << 3, d8(i[1])]
            if isind(s): raise AsmError('bad alu operand ' + s)
            return [0xC6 | k << 3, b8(s)]

        if mn in ('inc', 'dec'):
            o = ops[0]
            d = 0 if mn == 'inc' else 1
            if o in R8: return [0x04 | d | R8[o] << 3]
            if o in R16: return [0x03 | d << 3 | R16[o] << 4]
            if o in ('ix', 'iy'): return [pfx(o), 0x23 | d << 3]
            i = idx(o)
            if i: return [i[0], 0x34 | d, d8(i[1])]
            raise AsmError('bad inc/dec')

        if mn in ('push', 'pop'):
            o = ops[0]
            base = 0xC5 if mn == 'push' else 0xC1
            if o in R16A: return [base | R16A[o] << 4]
            if o in ('ix', 'iy'): return [pfx(o), base | 0x20]
            raise AsmError('bad push/pop')

        if mn == 'ex':
            a, b = ops
            if a == 'de' and b == 'hl': return [0xEB]
            if a == 'af' and b == "af'": return [0x08]
            if a == '(sp)' and b == 'hl': return [0xE3]
            if a == '(sp)' and b in ('ix', 'iy'): return [pfx(b), 0xE3]
            raise AsmError('bad ex')

        if mn == 'jp':
            if n == 1:
                if ops[0] == '(hl)': return [0xE9]
                if ops[0] in ('(ix)', '(iy)'): return [pfx(ops[0][1:3]), 0xE9]
                return [0xC3] + w16(ops[0])
            return [0xC2 | CC[ops[0]] << 3] + w16(ops[1])
        if mn == 'jr':
            if n == 1: return [0x18, rel(ops[0])]
            c = CC[ops[0]]
            if c > 3: raise AsmError('bad jr condition')
            return [0x20 | c << 3, rel(ops[1])]
        if mn == 'djnz':
            return [0x10, rel(ops[0])]
        if mn == 'call':
            if n == 1: return [0xCD] + w16(ops[0])
            return [0xC4 | CC[ops[0]] << 3] + w16(ops[1])
        if mn == 'ret':
            if n == 0: return [0xC9]
            return [0xC0 | CC[ops[0]] << 3]
        if mn == 'rst':
            return [0xC7 | (ev(ops[0]) & 0x38)]

        if mn in ROT:
            o = ops[0]
            k = ROT[mn]
            if o in R8: return [0xCB, k << 3 | R8[o]]
            i = idx(o)
            if i: return [i[0], 0xCB, d8(i[1]), k << 3 | 6]
            raise AsmError('bad rotate operand')
        if mn in ('bit', 'res', 'set'):
            base = {'bit': 0x40, 'res': 0x80, 'set': 0xC0}[mn]
            bn = ev(ops[0])
            if not 0 <= bn <= 7: raise AsmError('bad bit number')
            o = ops[1]
            if o in R8: return [0xCB, base | bn << 3 | R8[o]]
            i = idx(o)
            if i: return [i[0], 0xCB, d8(i[1]), base | bn << 3 | 6]
            raise AsmError('bad bit operand')

        if mn == 'im':
            return [0xED, [0x46, 0x56, 0x5E][ev(ops[0])]]
        if mn == 'in':
            a, b = ops
            if b == '(c)': return [0xED, 0x40 | R8[a] << 3]
            if a == 'a' and isind(b): return [0xDB, b8(b[1:-1])]
            raise AsmError('bad in')
        if mn == 'out':
            a, b = ops
            if a == '(c)': return [0xED, 0x41 | R8[b] << 3]
            if b == 'a' and isind(a): return [0xD3, b8(a[1:-1])]
            raise AsmError('bad out')
        raise AsmError('unknown instruction ' + mn)

    # ---------------------------------------------------------------- pass
    def load(self, fname):
        lines = []
        with open(os.path.join(self.incpath, fname)) as f:
            for i, raw in enumerate(f):
                s = self.lower_keep_quotes(self.strip_comment(raw.rstrip('\n')))
                m = re.match(r'^\s*include\s+"(.*)"\s*$', s)
                if m:
                    lines += self.load(m.group(1))
                elif s.strip():
                    lines.append((fname, i + 1, s))
        return lines

    def one_pass(self, lines):
        self.pc = 0
        self.scope = ''
        self.mem = bytearray(65536)
        self.lo = None
        self.hi = 0
        changed = False
        self.unresolved = False

        def define(name, val):
            nonlocal changed
            if dict.get(self.sym, name) != val:
                changed = True
            self.sym[name] = val

        def emit(bs):
            if self.lo is None or self.pc < self.lo:
                self.lo = self.pc
            for b in bs:
                self.mem[self.pc] = b & 0xFF
                self.pc += 1
            if self.pc > self.hi:
                self.hi = self.pc

        for fname, ln, s in lines:
            try:
                st = s.strip()
                m = re.match(r'^([.\w]+):\s*(.*)$', st)
                if m:
                    name = m.group(1)
                    if name.startswith('.'):
                        name = self.scope + '__' + name[1:]
                    else:
                        self.scope = name
                    define(name, self.pc)
                    st = m.group(2).strip()
                    if not st:
                        continue
                m = re.match(r'^(\w+)\s+equ\s+(.*)$', st)
                if m:
                    define(m.group(1), self.ev(m.group(2)))
                    continue
                parts = st.split(None, 1)
                mn = parts[0]
                rest = parts[1] if len(parts) > 1 else ''
                ops = self.split_ops(rest)
                if mn == 'org':
                    self.pc = self.ev(ops[0])
                elif mn == 'align':
                    a = self.ev(ops[0])
                    self.pc = (self.pc + a - 1) // a * a
                elif mn in ('db', 'defb'):
                    bs = []
                    for o in ops:
                        if o.startswith('"'):
                            bs += [ord(c) for c in o[1:-1]]
                        else:
                            v = self.ev(o)
                            if self.final and not -128 <= v <= 255:
                                raise AsmError('db out of range %d' % v)
                            bs.append(v & 0xFF)
                    emit(bs)
                elif mn in ('dw', 'defw'):
                    bs = []
                    for o in ops:
                        v = self.ev(o)
                        bs += [v & 0xFF, (v >> 8) & 0xFF]
                    emit(bs)
                elif mn in ('ds', 'defs'):
                    self.pc += self.ev(ops[0])
                else:
                    emit(self.enc(mn, ops))
            except AsmError as ex:
                raise AsmError('%s:%d: %s   [%s]' % (fname, ln, ex, s.strip()))
            except (KeyError, ValueError, IndexError) as ex:
                raise AsmError('%s:%d: bad operands (%r)   [%s]' % (fname, ln, ex, s.strip()))
        return changed

    def assemble(self, fname):
        lines = self.load(fname)
        for i in range(8):
            self.final = False
            if not self.one_pass(lines):
                break
        self.final = True
        self.one_pass(lines)
        syms = {k: v for k, v in self.sym.items() if isinstance(v, int)}
        return self.lo, bytes(self.mem[self.lo:self.hi]), syms


if __name__ == '__main__':
    import sys
    a = Asm(os.path.dirname(sys.argv[1]) or '.')
    org, code, syms = a.assemble(os.path.basename(sys.argv[1]))
    print('org %04X len %d' % (org, len(code)))
