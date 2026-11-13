#!/usr/bin/env python3
"""
z80asm.py - small two-pass Z80 assembler for VZ300 projects (ViBED by BPM)

Usage: z80asm.py source.asm out.bin [out.vz NAME] [--lst listing.txt]

Syntax
  label:            labels end with ':' (local style '.x' allowed, global scope)
  NAME EQU expr     constants   (also NAME = expr)
  ORG expr          set address (first ORG is the load address)
  DB/DEFB a,"str"   bytes        DW/DEFW  words       DS/DEFS n[,fill]
  ALIGN n           pad to multiple of n
  INCBIN "file"     include raw bytes
  expressions: + - * / % & | ^ ~ << >> ( ), $ = current address,
               numbers 123, $7F, 7Fh, 0x7F, %1010, 'c'
Full documented Z80 instruction set including CB, ED, DD/FD (IX/IY) forms.
"""
import sys, re, os

R8 = {'B': 0, 'C': 1, 'D': 2, 'E': 3, 'H': 4, 'L': 5, '(HL)': 6, 'A': 7}
R16 = {'BC': 0, 'DE': 1, 'HL': 2, 'SP': 3}
R16AF = {'BC': 0, 'DE': 1, 'HL': 2, 'AF': 3}
CC = {'NZ': 0, 'Z': 1, 'NC': 2, 'C': 3, 'PO': 4, 'PE': 5, 'P': 6, 'M': 7}
ALU = {'ADD': 0, 'ADC': 1, 'SUB': 2, 'SBC': 3, 'AND': 4, 'XOR': 5, 'OR': 6, 'CP': 7}
ROT = {'RLC': 0, 'RRC': 1, 'RL': 2, 'RR': 3, 'SLA': 4, 'SRA': 5, 'SLL': 6, 'SRL': 7}
SIMPLE = {
    'NOP': [0x00], 'RLCA': [0x07], 'RRCA': [0x0F], 'RLA': [0x17], 'RRA': [0x1F],
    'DAA': [0x27], 'CPL': [0x2F], 'SCF': [0x37], 'CCF': [0x3F], 'HALT': [0x76],
    'EXX': [0xD9], 'DI': [0xF3], 'EI': [0xFB],
    'NEG': [0xED, 0x44], 'RETN': [0xED, 0x45], 'RETI': [0xED, 0x4D],
    'RRD': [0xED, 0x67], 'RLD': [0xED, 0x6F],
    'LDI': [0xED, 0xA0], 'CPI': [0xED, 0xA1], 'INI': [0xED, 0xA2], 'OUTI': [0xED, 0xA3],
    'LDD': [0xED, 0xA8], 'CPD': [0xED, 0xA9], 'IND': [0xED, 0xAA], 'OUTD': [0xED, 0xAB],
    'LDIR': [0xED, 0xB0], 'CPIR': [0xED, 0xB1], 'INIR': [0xED, 0xB2], 'OTIR': [0xED, 0xB3],
    'LDDR': [0xED, 0xB8], 'CPDR': [0xED, 0xB9], 'INDR': [0xED, 0xBA], 'OTDR': [0xED, 0xBB],
}

class AsmError(Exception): pass

class Asm:
    def __init__(self):
        self.sym = {}
        self.pass_no = 1

    # ---------------- expressions ----------------
    def num(self, tok):
        t = tok
        if re.fullmatch(r"'.'", t): return ord(t[1])
        if re.fullmatch(r"\$[0-9A-Fa-f]+", t): return int(t[1:], 16)
        if re.fullmatch(r"0[xX][0-9A-Fa-f]+", t): return int(t[2:], 16)
        if re.fullmatch(r"[0-9][0-9A-Fa-f]*[hH]", t): return int(t[:-1], 16)
        if re.fullmatch(r"%[01]+", t): return int(t[1:], 2)
        if re.fullmatch(r"[01]+[bB]", t): return int(t[:-1], 2)
        if re.fullmatch(r"[0-9]+", t): return int(t)
        return None

    def ev(self, expr):
        e = expr.strip()
        if not e: raise AsmError('empty expression')
        out = []
        i = 0
        toks = re.findall(r"'.'|\$[0-9A-Fa-f]+|0[xX][0-9A-Fa-f]+|[0-9][0-9A-Fa-f]*[hH]\b|%[01]+|[0-9]+[bB]\b|[0-9]+|[A-Za-z_.][A-Za-z0-9_.]*|<<|>>|\$|[-+*/%&|^~()]|\s+", e)
        if ''.join(toks) != e: raise AsmError(f'bad expression: {expr}')
        for t in toks:
            if t.isspace(): continue
            n = self.num(t)
            if n is not None: out.append(str(n)); continue
            if t == '$': out.append(str(self.pc)); continue
            if re.fullmatch(r"[A-Za-z_.][A-Za-z0-9_.]*", t):
                k = self.scoped(t)
                if k in self.sym: out.append(str(self.sym[k]))
                elif self.pass_no == 1: out.append('0')
                else: raise AsmError(f'undefined symbol {t}')
                continue
            out.append({'/': '//'}.get(t, t))
        try:
            return int(eval(''.join(out), {'__builtins__': {}}))
        except Exception:
            raise AsmError(f'cannot evaluate {expr}')

    # ---------------- operand helpers ----------------
    @staticmethod
    def split_ops(s):
        ops, depth, cur, q = [], 0, '', False
        for ch in s:
            if ch in '"' : q = not q
            if not q and ch == '(': depth += 1
            if not q and ch == ')': depth -= 1
            if ch == ',' and depth == 0 and not q:
                ops.append(cur.strip()); cur = ''
            else: cur += ch
        if cur.strip(): ops.append(cur.strip())
        return ops

    @staticmethod
    def is_paren(o):
        if not (o.startswith('(') and o.endswith(')')): return False
        d = 0
        for i, ch in enumerate(o):
            if ch == '(': d += 1
            elif ch == ')':
                d -= 1
                if d == 0 and i != len(o) - 1: return False
        return True

    def idx(self, o):
        """(IX+d)/(IY+d) -> (prefix, d) or None"""
        u = o.upper().replace(' ', '')
        m = re.fullmatch(r"\((IX|IY)([+-].*)?\)", u)
        if not m: return None
        pre = 0xDD if m.group(1) == 'IX' else 0xFD
        d = 0
        if m.group(2):
            # evaluate using original-case text
            inner = o.strip()[1:-1].strip()[2:]
            d = self.ev(inner) if inner.strip() else 0
        if self.pass_no == 2 and not -128 <= d <= 127: raise AsmError('index offset out of range')
        return pre, d & 0xFF

    def b8(self, v):
        if self.pass_no == 2 and not -128 <= v <= 255: raise AsmError(f'byte out of range: {v}')
        return v & 0xFF

    def w16(self, v):
        v &= 0xFFFF; return [v & 0xFF, v >> 8]

    def rel(self, target):
        d = target - (self.pc + 2)
        if self.pass_no == 2 and not -128 <= d <= 127: raise AsmError(f'relative jump out of range ({d})')
        return d & 0xFF

    # ---------------- instruction encoding ----------------
    def encode(self, mn, ops):
        U = [o.upper().replace(' ', '') for o in ops]
        n = len(ops)
        if mn in SIMPLE and n == 0: return SIMPLE[mn]

        if mn == 'LD': return self.enc_ld(ops, U)
        if mn in ('PUSH', 'POP'):
            base = 0xC5 if mn == 'PUSH' else 0xC1
            if U[0] == 'IX': return [0xDD, base + 0x20]
            if U[0] == 'IY': return [0xFD, base + 0x20]
            return [base + (R16AF[U[0]] << 4)]
        if mn == 'EX':
            if U == ['AF', "AF'"] or U == ['AF', 'AF']: return [0x08]
            if U == ['DE', 'HL']: return [0xEB]
            if U == ['(SP)', 'HL']: return [0xE3]
            if U == ['(SP)', 'IX']: return [0xDD, 0xE3]
            if U == ['(SP)', 'IY']: return [0xFD, 0xE3]
        if mn in ALU:
            a = ALU[mn]
            if n == 2 and U[0] == 'A': ops, U, n = ops[1:], U[1:], 1
            if n == 2 and mn in ('ADD', 'ADC', 'SBC'):
                if U[0] == 'HL':
                    r = R16[U[1]]
                    if mn == 'ADD': return [0x09 + (r << 4)]
                    if mn == 'ADC': return [0xED, 0x4A + (r << 4)]
                    return [0xED, 0x42 + (r << 4)]
                if U[0] in ('IX', 'IY') and mn == 'ADD':
                    pre = 0xDD if U[0] == 'IX' else 0xFD
                    rr = {'BC': 0, 'DE': 1, U[0]: 2, 'SP': 3}[U[1]]
                    return [pre, 0x09 + (rr << 4)]
            if n == 1:
                o = U[0]
                if o in R8: return [0x80 + (a << 3) + R8[o]]
                ix = self.idx(ops[0])
                if ix: return [ix[0], 0x86 + (a << 3), ix[1]]
                if o in ('IXH', 'IXL', 'IYH', 'IYL'):
                    return [0xDD if o[1] == 'X' else 0xFD, 0x80 + (a << 3) + (4 if o[2] == 'H' else 5)]
                return [0xC6 + (a << 3), self.b8(self.ev(ops[0]))]
        if mn in ('INC', 'DEC'):
            o = U[0]
            if o in R8: return [(0x04 if mn == 'INC' else 0x05) + (R8[o] << 3)]
            if o in R16: return [(0x03 if mn == 'INC' else 0x0B) + (R16[o] << 4)]
            if o == 'IX': return [0xDD, 0x23 if mn == 'INC' else 0x2B]
            if o == 'IY': return [0xFD, 0x23 if mn == 'INC' else 0x2B]
            ix = self.idx(ops[0])
            if ix: return [ix[0], 0x34 if mn == 'INC' else 0x35, ix[1]]
            if o in ('IXH', 'IXL', 'IYH', 'IYL'):
                r = 4 if o[2] == 'H' else 5
                return [0xDD if o[1] == 'X' else 0xFD, (0x04 if mn == 'INC' else 0x05) + (r << 3)]
        if mn in ROT:
            r = ROT[mn]
            ix = self.idx(ops[0])
            if ix: return [ix[0], 0xCB, ix[1], (r << 3) + 6]
            return [0xCB, (r << 3) + R8[U[0]]]
        if mn in ('BIT', 'SET', 'RES'):
            b = self.ev(ops[0]) & 7
            base = {'BIT': 0x40, 'RES': 0x80, 'SET': 0xC0}[mn]
            ix = self.idx(ops[1])
            if ix: return [ix[0], 0xCB, ix[1], base + (b << 3) + 6]
            return [0xCB, base + (b << 3) + R8[U[1]]]
        if mn == 'JP':
            if n == 1:
                if U[0] in ('(HL)', 'HL'): return [0xE9]
                if U[0] in ('(IX)', 'IX'): return [0xDD, 0xE9]
                if U[0] in ('(IY)', 'IY'): return [0xFD, 0xE9]
                return [0xC3] + self.w16(self.ev(ops[0]))
            return [0xC2 + (CC[U[0]] << 3)] + self.w16(self.ev(ops[1]))
        if mn == 'JR':
            if n == 1: return [0x18, self.rel(self.ev(ops[0]))]
            c = CC[U[0]]
            if c > 3: raise AsmError('JR condition must be NZ/Z/NC/C')
            return [0x20 + (c << 3), self.rel(self.ev(ops[1]))]
        if mn == 'DJNZ': return [0x10, self.rel(self.ev(ops[0]))]
        if mn == 'CALL':
            if n == 1: return [0xCD] + self.w16(self.ev(ops[0]))
            return [0xC4 + (CC[U[0]] << 3)] + self.w16(self.ev(ops[1]))
        if mn == 'RET':
            if n == 0: return [0xC9]
            return [0xC0 + (CC[U[0]] << 3)]
        if mn == 'RST':
            v = self.ev(ops[0])
            if v & ~0x38: raise AsmError('bad RST')
            return [0xC7 + v]
        if mn == 'IM':
            return [0xED, {0: 0x46, 1: 0x56, 2: 0x5E}[self.ev(ops[0])]]
        if mn == 'IN':
            if U[1] == '(C)': return [0xED, 0x40 + (R8[U[0]] << 3)]
            return [0xDB, self.b8(self.ev(ops[1][1:-1]))]
        if mn == 'OUT':
            if U[0] == '(C)': return [0xED, 0x41 + (R8[U[1]] << 3)]
            return [0xD3, self.b8(self.ev(ops[0][1:-1]))]
        raise AsmError(f'unknown instruction: {mn} {",".join(ops)}')

    def enc_ld(self, ops, U):
        d, s = U
        # 8-bit register to register
        if d in R8 and s in R8:
            if d == '(HL)' and s == '(HL)': raise AsmError('LD (HL),(HL) invalid')
            return [0x40 + (R8[d] << 3) + R8[s]]
        ixd, ixs = self.idx(ops[0]), self.idx(ops[1])
        if ixd and s in R8 and s != '(HL)': return [ixd[0], 0x70 + R8[s], ixd[1]]
        if ixs and d in R8 and d != '(HL)': return [ixs[0], 0x46 + (R8[d] << 3), ixs[1]]
        if ixd: return [ixd[0], 0x36, ixd[1], self.b8(self.ev(ops[1]))]
        # special A forms
        if d == 'A' and s == '(BC)': return [0x0A]
        if d == 'A' and s == '(DE)': return [0x1A]
        if d == '(BC)' and s == 'A': return [0x02]
        if d == '(DE)' and s == 'A': return [0x12]
        if d == 'A' and s == 'I': return [0xED, 0x57]
        if d == 'A' and s == 'R': return [0xED, 0x5F]
        if d == 'I' and s == 'A': return [0xED, 0x47]
        if d == 'R' and s == 'A': return [0xED, 0x4F]
        if d == 'SP' and s == 'HL': return [0xF9]
        if d == 'SP' and s == 'IX': return [0xDD, 0xF9]
        if d == 'SP' and s == 'IY': return [0xFD, 0xF9]
        # memory absolute
        if self.is_paren(ops[1]) and s not in R8 and s not in ('(BC)', '(DE)'):
            addr = self.ev(ops[1].strip()[1:-1])
            if d == 'A': return [0x3A] + self.w16(addr)
            if d == 'HL': return [0x2A] + self.w16(addr)
            if d == 'IX': return [0xDD, 0x2A] + self.w16(addr)
            if d == 'IY': return [0xFD, 0x2A] + self.w16(addr)
            if d in R16: return [0xED, 0x4B + (R16[d] << 4)] + self.w16(addr)
        if self.is_paren(ops[0]) and d not in R8 and d not in ('(BC)', '(DE)'):
            addr = self.ev(ops[0].strip()[1:-1])
            if s == 'A': return [0x32] + self.w16(addr)
            if s == 'HL': return [0x22] + self.w16(addr)
            if s == 'IX': return [0xDD, 0x22] + self.w16(addr)
            if s == 'IY': return [0xFD, 0x22] + self.w16(addr)
            if s in R16: return [0xED, 0x43 + (R16[s] << 4)] + self.w16(addr)
        # index-register halves as source
        if s in ('IXH', 'IXL', 'IYH', 'IYL') and d in ('A', 'B', 'C', 'D', 'E'):
            pre = 0xDD if s[1] == 'X' else 0xFD
            return [pre, 0x40 + (R8[d] << 3) + (4 if s[2] == 'H' else 5)]
        # immediates
        if d in R8: return [0x06 + (R8[d] << 3), self.b8(self.ev(ops[1]))]
        if d in R16: return [0x01 + (R16[d] << 4)] + self.w16(self.ev(ops[1]))
        if d == 'IX': return [0xDD, 0x21] + self.w16(self.ev(ops[1]))
        if d == 'IY': return [0xFD, 0x21] + self.w16(self.ev(ops[1]))
        if d in ('IXH', 'IXL', 'IYH', 'IYL'):
            pre = 0xDD if d[1] == 'X' else 0xFD
            r = 4 if d[2] == 'H' else 5
            if s in ('A', 'B', 'C', 'D', 'E'): return [pre, 0x40 + (r << 3) + R8[s]]
            return [pre, 0x06 + (r << 3), self.b8(self.ev(ops[1]))]
        raise AsmError(f'bad LD {ops[0]},{ops[1]}')

    # ---------------- driver ----------------
    def data_bytes(self, ops, size):
        out = []
        for o in ops:
            if o.startswith('"') and o.endswith('"') and size == 1:
                out += [ord(ch) for ch in o[1:-1]]
            else:
                v = self.ev(o)
                out += [self.b8(v)] if size == 1 else self.w16(v)
        return out

    def run_pass(self, lines, srcdir):
        self.pc = None; self.org = None; self.scope = ''
        self.mem = {}
        self.listing = []
        for ln, raw in enumerate(lines, 1):
            line = raw.split(';', 1)[0] if '"' not in raw else self.strip_comment(raw)
            line = line.rstrip()
            if not line.strip(): continue
            try:
                self.do_line(line, srcdir, raw)
            except AsmError as e:
                raise AsmError(f'line {ln}: {e}\n    {raw.rstrip()}')
            except KeyError as e:
                raise AsmError(f'line {ln}: bad operand {e}\n    {raw.rstrip()}')

    @staticmethod
    def strip_comment(raw):
        q = False
        for i, ch in enumerate(raw):
            if ch == '"': q = not q
            if ch == ';' and not q: return raw[:i]
        return raw

    def scoped(self, name):
        k = name.upper()
        return (self.scope + k) if k.startswith('.') else k

    def define(self, name, val):
        k = self.scoped(name)
        if self.pass_no == 1 and k in self.sym and self.sym[k] != val:
            raise AsmError(f'duplicate symbol {name}')
        self.sym[k] = val

    def emit(self, bs, raw):
        if self.pc is None: raise AsmError('code before ORG')
        start = self.pc
        for b in bs:
            self.mem[self.pc] = b & 0xFF; self.pc += 1
        if self.pass_no == 2:
            self.listing.append(f'{start:04X}  {" ".join(f"{b:02X}" for b in bs[:8]):24s} {raw.rstrip()}')

    def do_line(self, line, srcdir, raw):
        m = re.match(r"^\s*([A-Za-z_.][A-Za-z0-9_.]*)\s*(EQU|=)\s*(.+)$", line, re.I)
        if m:
            self.define(m.group(1), self.ev(m.group(3))); return
        m = re.match(r"^\s*(@?[A-Za-z_.][A-Za-z0-9_.]*):(.*)$", line)
        if m:
            if self.pc is None: raise AsmError('label before ORG')
            name = m.group(1)
            if name.startswith('@'):            # global label that keeps the local scope
                self.define(name[1:], self.pc)
            else:
                if not name.startswith('.'): self.scope = name.upper()
                self.define(name, self.pc)
            line = m.group(2)
            if not line.strip(): return
        parts = line.strip().split(None, 1)
        mn = parts[0].upper()
        ops = self.split_ops(parts[1]) if len(parts) > 1 else []
        if mn == 'ORG':
            self.pc = self.ev(ops[0])
            if self.org is None: self.org = self.pc
            return
        if mn in ('DB', 'DEFB', 'DEFM'): self.emit(self.data_bytes(ops, 1), raw); return
        if mn in ('DW', 'DEFW'): self.emit(self.data_bytes(ops, 2), raw); return
        if mn in ('DS', 'DEFS'):
            cnt = self.ev(ops[0]); fill = self.ev(ops[1]) if len(ops) > 1 else 0
            self.emit([fill] * cnt, raw); return
        if mn == 'ALIGN':
            a = self.ev(ops[0]); pad = (-self.pc) % a
            self.emit([0] * pad, raw); return
        if mn == 'INCBIN':
            fn = os.path.join(srcdir, ops[0].strip('"'))
            self.emit(list(open(fn, 'rb').read()), raw); return
        if mn == 'END': return
        self.emit(self.encode(mn, ops), raw)

    def assemble(self, text, srcdir='.'):
        lines = text.splitlines()
        self.pass_no = 1; self.run_pass(lines, srcdir)
        self.pass_no = 2; self.run_pass(lines, srcdir)
        lo = self.org; hi = max(self.mem) + 1
        return lo, bytes(self.mem.get(a, 0) for a in range(lo, hi))

def vz_file(name, start, data):
    """.VZ snapshot: 'VZF0', 17-byte name, type $F1 (machine code), start address."""
    nm = name.upper().encode()[:16]
    hdr = b'VZF0' + nm + bytes(17 - len(nm)) + bytes([0xF1]) + bytes([start & 0xFF, start >> 8])
    return hdr + data

def main():
    a = sys.argv[1:]
    lst = None
    if '--lst' in a:
        i = a.index('--lst'); lst = a[i + 1]; del a[i:i + 2]
    src, binout = a[0], a[1]
    asm = Asm()
    try:
        org, data = asm.assemble(open(src).read(), os.path.dirname(os.path.abspath(src)))
    except AsmError as e:
        print('ERROR', e); sys.exit(1)
    open(binout, 'wb').write(data)
    if len(a) >= 4:
        open(a[2], 'wb').write(vz_file(a[3], org, data))
    if lst:
        with open(lst, 'w') as fh:
            fh.write('\n'.join(asm.listing) + '\n\nSYMBOLS\n')
            for k in sorted(asm.sym): fh.write(f'{k:24s} {asm.sym[k] & 0xFFFF:04X}\n')
    print(f'{src}: ${org:04X}-${org + len(data) - 1:04X} ({len(data)} bytes)')

if __name__ == '__main__':
    main()
