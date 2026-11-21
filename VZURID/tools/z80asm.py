#!/usr/bin/env python3
"""Minimal two-pass Z80 assembler (no external dependencies).

Supports labels, EQU, ORG, DB/DEFB, DW/DEFW, DS/DEFS, END, expressions
(+ - * / % << >> & | ^ ~ parentheses, $ for current address, 0x/$/h/b literals,
character literals), local labels starting with '.', and the documented Z80
instruction set plus the commonly used undocumented IXH/IXL/IYH/IYL halves.
"""
import re
import sys

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


class AsmError(Exception):
    pass


def split_operands(s):
    out, cur, depth, q = [], '', 0, None
    for ch in s:
        if q:
            cur += ch
            if ch == q:
                q = None
            continue
        if ch in '\'"':
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
    if cur.strip():
        out.append(cur.strip())
    return out


def strip_comment(line):
    q = None
    for i, ch in enumerate(line):
        if q:
            if ch == q:
                q = None
        elif ch in '\'"':
            q = ch
        elif ch == ';':
            return line[:i]
    return line


class Asm:
    def __init__(self):
        self.sym = {}
        self.pc = 0
        self.out = {}          # address -> byte
        self.pass_no = 1
        self.lastglobal = ''
        self.errors = []

    # ---------- expression evaluation ----------
    def ev(self, expr, allow_undef=None):
        expr = expr.strip()
        if allow_undef is None:
            allow_undef = (self.pass_no == 1)

        def lit_hex_dollar(m):
            return '0x' + m.group(1)
        e = expr
        # character literals
        e = re.sub(r"'(.)'", lambda m: str(ord(m.group(1))), e)
        # $hex (but not bare $)
        e = re.sub(r'\$([0-9A-Fa-f]+)\b', lit_hex_dollar, e)
        # NNh hex
        e = re.sub(r'\b([0-9][0-9A-Fa-f]*)[hH]\b', lambda m: '0x' + m.group(1), e)
        # %binary
        e = re.sub(r'%([01]+)\b', lambda m: '0b' + m.group(1), e)
        # NNb binary
        e = re.sub(r'\b([01]+)[bB]\b', lambda m: '0b' + m.group(1), e)
        # bare $ = pc
        e = re.sub(r'\$(?![0-9A-Za-z_])', str(self.pc), e)

        def sub(m):
            name = m.group(0)
            if re.fullmatch(r'0[xXbB][0-9A-Fa-f]+', name) or name[0].isdigit():
                return name
            key = self.resolve(name)
            if key in self.sym:
                return str(self.sym[key])
            if allow_undef:
                return '0'
            raise AsmError('undefined symbol: ' + name)
        e = re.sub(r'(?<![A-Za-z0-9_])\.?[A-Za-z_][A-Za-z0-9_]*', sub, e)
        e = e.replace('/', '//')
        try:
            return int(eval(e, {'__builtins__': {}}, {}))
        except Exception as ex:
            raise AsmError('bad expression %r (%s)' % (expr, ex))

    def resolve(self, name):
        if name.startswith('.'):
            return self.lastglobal + name
        return name

    # ---------- emit ----------
    def emit(self, bs):
        for b in bs:
            self.out[self.pc & 0xFFFF] = b & 0xFF
            self.pc += 1

    # ---------- operand classification ----------
    @staticmethod
    def idx(op):
        m = re.fullmatch(r'\(\s*(IX|IY)\s*(?:([+-].*))?\)', op, re.I)
        if m:
            return m.group(1).upper(), (m.group(2) or '+0')
        return None

    def disp(self, d):
        v = self.ev(d)
        if self.pass_no == 2 and not -128 <= v <= 127:
            raise AsmError('index displacement out of range: %d' % v)
        return v & 0xFF

    def is_mem(self, op):
        return op.startswith('(') and op.endswith(')')

    def r8code(self, op):
        """Return (prefix, code, disp_bytes) for an 8-bit operand or None."""
        u = op.upper()
        if u in R8 and u != '(HL)':
            return (None, R8[u], [])
        if u == '(HL)':
            return (None, 6, [])
        ix = self.idx(op)
        if ix:
            pre = 0xDD if ix[0] == 'IX' else 0xFD
            return (pre, 6, [self.disp(ix[1])])
        half = {'IXH': (0xDD, 4), 'IXL': (0xDD, 5), 'IYH': (0xFD, 4), 'IYL': (0xFD, 5)}
        if u in half:
            return (half[u][0], half[u][1], [])
        return None

    # ---------- instruction encoding ----------
    def instr(self, mn, ops):
        mn = mn.upper()
        U = [o.upper() for o in ops]
        n = len(ops)
        if mn in SIMPLE and n == 0:
            return self.emit(SIMPLE[mn])
        if mn == 'IM':
            return self.emit([0xED, {0: 0x46, 1: 0x56, 2: 0x5E}[self.ev(ops[0])]])
        if mn == 'LD':
            return self.ld(ops, U)
        if mn in ALU:
            if n == 1:
                ops = ['A'] + ops
                U = ['A'] + U
            if U[0] == 'HL' and mn in ('ADD', 'ADC', 'SBC'):
                r = R16[U[1]]
                if mn == 'ADD':
                    return self.emit([0x09 | r << 4])
                return self.emit([0xED, (0x4A if mn == 'ADC' else 0x42) | r << 4])
            if U[0] in ('IX', 'IY') and mn == 'ADD':
                pre = 0xDD if U[0] == 'IX' else 0xFD
                tbl = {'BC': 0, 'DE': 1, U[0]: 2, 'SP': 3}
                return self.emit([pre, 0x09 | tbl[U[1]] << 4])
            if U[0] != 'A':
                raise AsmError('bad ALU operand')
            rc = self.r8code(ops[1])
            if rc:
                pre, code, d = rc
                return self.emit(([pre] if pre else []) + [0x80 | ALU[mn] << 3 | code] + d)
            return self.emit([0xC6 | ALU[mn] << 3, self.ev(ops[1]) & 0xFF])
        if mn in ('INC', 'DEC'):
            u = U[0]
            inc = mn == 'INC'
            if u in R16:
                return self.emit([(0x03 if inc else 0x0B) | R16[u] << 4])
            if u in ('IX', 'IY'):
                return self.emit([0xDD if u == 'IX' else 0xFD, 0x23 if inc else 0x2B])
            rc = self.r8code(ops[0])
            pre, code, d = rc
            return self.emit(([pre] if pre else []) + [(0x04 if inc else 0x05) | code << 3] + d)
        if mn in ROT:
            rc = self.r8code(ops[-1])
            pre, code, d = rc
            if pre and d:
                return self.emit([pre, 0xCB, d[0], ROT[mn] << 3 | code])
            return self.emit([0xCB, ROT[mn] << 3 | code])
        if mn in ('BIT', 'RES', 'SET'):
            b = self.ev(ops[0])
            base = {'BIT': 0x40, 'RES': 0x80, 'SET': 0xC0}[mn]
            rc = self.r8code(ops[1])
            pre, code, d = rc
            if pre and d:
                return self.emit([pre, 0xCB, d[0], base | b << 3 | 6])
            return self.emit([0xCB, base | b << 3 | code])
        if mn == 'JP':
            if n == 1:
                if U[0] in ('(HL)', 'HL'):
                    return self.emit([0xE9])
                ix = re.fullmatch(r'\((IX|IY)\)', U[0])
                if ix:
                    return self.emit([0xDD if ix.group(1) == 'IX' else 0xFD, 0xE9])
                v = self.ev(ops[0])
                return self.emit([0xC3, v & 255, v >> 8 & 255])
            v = self.ev(ops[1])
            return self.emit([0xC2 | CC[U[0]] << 3, v & 255, v >> 8 & 255])
        if mn == 'CALL':
            if n == 1:
                v = self.ev(ops[0])
                return self.emit([0xCD, v & 255, v >> 8 & 255])
            v = self.ev(ops[1])
            return self.emit([0xC4 | CC[U[0]] << 3, v & 255, v >> 8 & 255])
        if mn == 'RET':
            if n == 0:
                return self.emit([0xC9])
            return self.emit([0xC0 | CC[U[0]] << 3])
        if mn in ('JR', 'DJNZ'):
            if mn == 'DJNZ':
                op, tgt = 0x10, ops[0]
            elif n == 1:
                op, tgt = 0x18, ops[0]
            else:
                if U[0] not in ('NZ', 'Z', 'NC', 'C'):
                    raise AsmError('bad JR condition')
                op, tgt = 0x20 | CC[U[0]] << 3, ops[1]
            v = self.ev(tgt)
            off = v - (self.pc + 2)
            if self.pass_no == 2 and not -128 <= off <= 127:
                raise AsmError('relative jump out of range (%d) to %s' % (off, tgt))
            return self.emit([op, off & 255])
        if mn == 'RST':
            return self.emit([0xC7 | (self.ev(ops[0]) & 0x38)])
        if mn == 'PUSH' or mn == 'POP':
            u = U[0]
            base = 0xC5 if mn == 'PUSH' else 0xC1
            if u in R16AF:
                return self.emit([base | R16AF[u] << 4])
            if u in ('IX', 'IY'):
                return self.emit([0xDD if u == 'IX' else 0xFD, base | 0x20])
        if mn == 'EX':
            if U == ['DE', 'HL']:
                return self.emit([0xEB])
            if U == ['AF', "AF'"]:
                return self.emit([0x08])
            if U[0] == '(SP)':
                if U[1] == 'HL':
                    return self.emit([0xE3])
                return self.emit([0xDD if U[1] == 'IX' else 0xFD, 0xE3])
        if mn == 'OUT':
            if U[0] == '(C)':
                return self.emit([0xED, 0x41 | R8[U[1]] << 3] if U[1] != '0' else [0xED, 0x71])
            return self.emit([0xD3, self.ev(ops[0][1:-1]) & 255])
        if mn == 'IN':
            if U[1] == '(C)':
                return self.emit([0xED, 0x40 | R8[U[0]] << 3])
            return self.emit([0xDB, self.ev(ops[1][1:-1]) & 255])
        raise AsmError('cannot assemble: %s %s' % (mn, ', '.join(ops)))

    def ld(self, ops, U):
        d, s = ops
        ud, us = U
        # LD SP,HL/IX/IY
        if ud == 'SP' and us == 'HL':
            return self.emit([0xF9])
        if ud == 'SP' and us in ('IX', 'IY'):
            return self.emit([0xDD if us == 'IX' else 0xFD, 0xF9])
        # special registers
        sp = {'I': 0x47, 'R': 0x4F}
        if ud in sp and us == 'A':
            return self.emit([0xED, sp[ud]])
        if us in ('I', 'R') and ud == 'A':
            return self.emit([0xED, 0x57 if us == 'I' else 0x5F])
        # 16-bit loads
        if ud in R16 or ud in ('IX', 'IY'):
            pre = [] if ud in R16 else [0xDD if ud == 'IX' else 0xFD]
            if self.is_mem(s) and not self.idx(s) and us != '(HL)':
                v = self.ev(s[1:-1])
                if ud == 'HL':
                    return self.emit([0x2A, v & 255, v >> 8 & 255])
                if ud in ('IX', 'IY'):
                    return self.emit(pre + [0x2A, v & 255, v >> 8 & 255])
                return self.emit([0xED, 0x4B | R16[ud] << 4, v & 255, v >> 8 & 255])
            v = self.ev(s)
            code = R16[ud] if ud in R16 else 2
            return self.emit(pre + [0x01 | code << 4, v & 255, v >> 8 & 255])
        if us in R16 or us in ('IX', 'IY'):
            if self.is_mem(d) and not self.idx(d):
                v = self.ev(d[1:-1])
                if us == 'HL':
                    return self.emit([0x22, v & 255, v >> 8 & 255])
                if us in ('IX', 'IY'):
                    return self.emit([0xDD if us == 'IX' else 0xFD, 0x22, v & 255, v >> 8 & 255])
                return self.emit([0xED, 0x43 | R16[us] << 4, v & 255, v >> 8 & 255])
        # (BC)/(DE) with A
        if ud in ('(BC)', '(DE)') and us == 'A':
            return self.emit([0x02 if ud == '(BC)' else 0x12])
        if us in ('(BC)', '(DE)') and ud == 'A':
            return self.emit([0x0A if us == '(BC)' else 0x1A])
        # LD (nn),A / LD A,(nn)
        if ud == 'A' and self.is_mem(s) and not self.idx(s) and us != '(HL)':
            v = self.ev(s[1:-1])
            return self.emit([0x3A, v & 255, v >> 8 & 255])
        if us == 'A' and self.is_mem(d) and not self.idx(d) and ud != '(HL)':
            v = self.ev(d[1:-1])
            return self.emit([0x32, v & 255, v >> 8 & 255])
        # 8-bit
        rd, rs = self.r8code(d), self.r8code(s)
        if rd and rs:
            if (rd[0] and rs[0] and rd[0] != rs[0]) or (rd[2] and rs[2]) :
                raise AsmError('bad LD operands')
            pre = rd[0] or rs[0]
            if rd[2] or rs[2]:
                # indexed memory with a plain register
                other = rs if rd[2] else rd
                if other[0]:
                    raise AsmError('bad LD operands')
            dd = rd[2] or rs[2]
            return self.emit(([pre] if pre else []) + [0x40 | rd[1] << 3 | rs[1]] + dd)
        if rd:
            v = self.ev(s) & 255
            pre, code, dd = rd
            return self.emit(([pre] if pre else []) + [0x06 | code << 3] + dd + [v])
        raise AsmError('cannot assemble LD %s,%s' % (d, s))

    # ---------- directives & driver ----------
    def line(self, raw, lineno):
        line = strip_comment(raw).rstrip()
        if not line.strip():
            return
        label = None
        m = re.match(r'^(\.?[A-Za-z_][A-Za-z0-9_]*)\s*:(.*)$', line)
        if m:
            label, line = m.group(1), m.group(2)
        else:
            m = re.match(r'^(\.?[A-Za-z_][A-Za-z0-9_]*)\s+(?i:equ)\s+(.*)$', line)
            if m:
                name = self.resolve(m.group(1))
                self.sym[name] = self.ev(m.group(2))
                return
        if label:
            if not label.startswith('.'):
                self.lastglobal = label
            self.sym[self.resolve(label)] = self.pc
        line = line.strip()
        if not line:
            return
        parts = line.split(None, 1)
        mn = parts[0]
        rest = parts[1] if len(parts) > 1 else ''
        um = mn.upper()
        if um == 'EQU':
            return
        # "name EQU value" with a colon label already consumed is handled above
        m2 = re.match(r'^(?i:equ)\s+(.*)$', rest)
        if m2 and label is None:
            pass
        if um == 'ORG':
            self.pc = self.ev(rest)
            return
        if um == 'END':
            return
        if um in ('DB', 'DEFB', 'BYTE'):
            for o in split_operands(rest):
                if len(o) >= 2 and o[0] in '"\'' and o[-1] == o[0] and len(o) != 3:
                    self.emit([ord(c) for c in o[1:-1]])
                else:
                    self.emit([self.ev(o) & 255])
            return
        if um in ('DW', 'DEFW', 'WORD'):
            for o in split_operands(rest):
                v = self.ev(o)
                self.emit([v & 255, v >> 8 & 255])
            return
        if um in ('DS', 'DEFS', 'BLOCK'):
            ops = split_operands(rest)
            cnt = self.ev(ops[0])
            val = self.ev(ops[1]) & 255 if len(ops) > 1 else 0
            self.emit([val] * cnt)
            return
        self.instr(mn, split_operands(rest))

    def assemble(self, text, name='<src>'):
        lines = text.splitlines()
        start = None
        for p in (1, 2):
            self.pass_no = p
            self.pc = 0
            self.lastglobal = ''
            self.out = {}
            for i, raw in enumerate(lines, 1):
                try:
                    self.line(raw, i)
                except AsmError as e:
                    self.errors.append('%s:%d: %s\n    %s' % (name, i, e, raw.strip()))
                    if p == 1:
                        pass
            if self.errors and p == 1:
                # errors in pass 1 for undefined are suppressed; real ones persist
                break
        return self.errors


def preprocess(path, seen=None):
    """Handle INCLUDE and simple MACRO-free text assembly."""
    import os
    seen = seen or set()
    out = []
    base = os.path.dirname(path)
    with open(path) as f:
        for line in f:
            m = re.match(r'^\s*(?i:include)\s+"([^"]+)"', line)
            if m:
                out.append(preprocess(os.path.join(base, m.group(1)), seen))
            else:
                out.append(line.rstrip('\n'))
    return '\n'.join(out)


def main():
    if len(sys.argv) < 3:
        print('usage: z80asm.py in.asm out.bin [--sym out.sym]')
        sys.exit(1)
    src = preprocess(sys.argv[1])
    a = Asm()
    errs = a.assemble(src, sys.argv[1])
    if errs:
        print('\n'.join(errs[:40]))
        print('%d error(s)' % len(errs))
        sys.exit(1)
    lo = min(a.out)
    hi = max(a.out)
    blob = bytes(a.out.get(i, 0) for i in range(lo, hi + 1))
    open(sys.argv[2], 'wb').write(blob)
    if '--sym' in sys.argv:
        sp = sys.argv[sys.argv.index('--sym') + 1]
        with open(sp, 'w') as f:
            for k, v in sorted(a.sym.items(), key=lambda kv: kv[1]):
                f.write('%04X %s\n' % (v & 0xFFFF, k))
    print('assembled %s: $%04X-$%04X (%d bytes)' % (sys.argv[1], lo, hi, len(blob)))


if __name__ == '__main__':
    main()
