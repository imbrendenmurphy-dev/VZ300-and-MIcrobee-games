#!/usr/bin/env python3
"""
zasm.py - a small, self-contained two-pass Z80 assembler (Zilog syntax).

Written for the Microbee Premium Plus racing project (ViBED by BPM).
The opcode table is *generated* from the standard x/y/z/p/q decomposition
of the Z80 instruction set, so every documented instruction (plus the
IXH/IXL/IYH/IYL forms) is available without hand-typed tables.

Usage:  python3 zasm.py source.asm -o out.bin [-l out.lst] [-s out.sym]

Syntax supported
  label:  / label  (column 0)     .local labels (scoped to last global label)
  ORG, EQU (or =), DB/DEFB/DM, DW/DEFW, DS/DEFS n[,fill], ALIGN n,
  INCLUDE "f", INCBIN "f", ASSERT expr, END
  Numbers: 123, 0x1F, $1F, 1Fh, %1010, 0b1010, 'c'.  $ = current address.
  Operators: + - * / % << >> & | ^ ~ ( ), HIGH(x), LOW(x)
"""
import sys, os, re, argparse

# ---------------------------------------------------------------- opcode table
R   = ['B','C','D','E','H','L','(HL)','A']
RP  = ['BC','DE','HL','SP']
RP2 = ['BC','DE','HL','AF']
CC  = ['NZ','Z','NC','C','PO','PE','P','M']
ALU = ['ADD A,','ADC A,','SUB ','SBC A,','AND ','XOR ','OR ','CP ']
ROT = ['RLC','RRC','RL','RR','SLA','SRA','SLL','SRL']

def gen_table():
    t = {}
    def add(m, b):
        t.setdefault(m, b)
    # unprefixed
    for op in range(256):
        x, y, z = op >> 6, (op >> 3) & 7, op & 7
        p, q = y >> 1, y & 1
        if x == 0:
            if z == 0:
                add(['NOP',"EX AF,AF'",'DJNZ e','JR e','JR NZ,e','JR Z,e','JR NC,e','JR C,e'][y],
                    [op] + (['e'] if y >= 2 else []))
            elif z == 1:
                if q == 0: add('LD %s,nn' % RP[p], [op, 'nn'])
                else: add('ADD HL,%s' % RP[p], [op])
            elif z == 2:
                m = [['LD (BC),A','LD (DE),A','LD (nn),HL','LD (nn),A'],
                     ['LD A,(BC)','LD A,(DE)','LD HL,(nn)','LD A,(nn)']][q][p]
                add(m, [op] + (['nn'] if p >= 2 else []))
            elif z == 3: add(('INC %s' if q == 0 else 'DEC %s') % RP[p], [op])
            elif z == 4: add('INC %s' % R[y], [op])
            elif z == 5: add('DEC %s' % R[y], [op])
            elif z == 6: add('LD %s,n' % R[y], [op, 'n'])
            else: add(['RLCA','RRCA','RLA','RRA','DAA','CPL','SCF','CCF'][y], [op])
        elif x == 1:
            if op == 0x76: add('HALT', [op])
            else: add('LD %s,%s' % (R[y], R[z]), [op])
        elif x == 2:
            add(ALU[y] + R[z], [op])
        else:
            if z == 0: add('RET %s' % CC[y], [op])
            elif z == 1:
                if q == 0: add('POP %s' % RP2[p], [op])
                else: add(['RET','EXX','JP (HL)','LD SP,HL'][p], [op])
            elif z == 2: add('JP %s,nn' % CC[y], [op, 'nn'])
            elif z == 3:
                if y == 0: add('JP nn', [op, 'nn'])
                elif y == 2: add('OUT (n),A', [op, 'n'])
                elif y == 3: add('IN A,(n)', [op, 'n'])
                elif y >= 4: add(['EX (SP),HL','EX DE,HL','DI','EI'][y-4], [op])
            elif z == 4: add('CALL %s,nn' % CC[y], [op, 'nn'])
            elif z == 5:
                if q == 0: add('PUSH %s' % RP2[p], [op])
                elif p == 0: add('CALL nn', [op, 'nn'])
            elif z == 6: add(ALU[y] + 'n', [op, 'n'])
            else: add('RST %d' % (y * 8), [op])
    # CB
    for op in range(256):
        x, y, z = op >> 6, (op >> 3) & 7, op & 7
        if x == 0: add('%s %s' % (ROT[y], R[z]), [0xCB, op])
        else: add('%s %d,%s' % (['','BIT','RES','SET'][x], y, R[z]), [0xCB, op])
    # ED
    for op in range(256):
        x, y, z = op >> 6, (op >> 3) & 7, op & 7
        p, q = y >> 1, y & 1
        if x == 1:
            if z == 0: add('IN (C)' if y == 6 else 'IN %s,(C)' % R[y], [0xED, op])
            elif z == 1: add('OUT (C),0' if y == 6 else 'OUT (C),%s' % R[y], [0xED, op])
            elif z == 2: add(('SBC HL,%s' if q == 0 else 'ADC HL,%s') % RP[p], [0xED, op])
            elif z == 3:
                add(('LD (nn),%s' % RP[p]) if q == 0 else ('LD %s,(nn)' % RP[p]), [0xED, op, 'nn'])
            elif z == 4: add('NEG', [0xED, op])
            elif z == 5: add('RETI' if y == 1 else 'RETN', [0xED, op])
            elif z == 6: add('IM %d' % [0,0,1,2,0,0,1,2][y], [0xED, op])
            else:
                m = ['LD I,A','LD R,A','LD A,I','LD A,R','RRD','RLD',None,None][y]
                if m: add(m, [0xED, op])
        elif x == 2 and z <= 3 and y >= 4:
            m = [['LDI','CPI','INI','OUTI'],['LDD','CPD','IND','OUTD'],
                 ['LDIR','CPIR','INIR','OTIR'],['LDDR','CPDR','INDR','OTDR']][y-4][z]
            add(m, [0xED, op])
    # DD / FD : derive from unprefixed table
    base = dict(t)
    for pre, ix in ((0xDD, 'IX'), (0xFD, 'IY')):
        for m, b in base.items():
            if len(b) and b[0] in (0xCB, 0xED): continue
            if m in ('EX DE,HL', 'EXX'): continue
            ops = m.split(' ', 1)
            if len(ops) < 2: continue
            mn, args = ops
            alist = args.split(',')
            has_mem = '(HL)' in alist
            if not ('HL' in alist or 'H' in alist or 'L' in alist or has_mem): continue
            new = []
            for a in alist:
                if a == 'HL': new.append(ix)
                elif a == '(HL)':
                    new.append('(IX+d)'.replace('IX', ix) if mn != 'JP' else '(%s)' % ix)
                elif a in ('H', 'L') and not has_mem: new.append(ix + a)
                else: new.append(a)
            nm = mn + ' ' + ','.join(new)
            nb = [pre, b[0]]
            if has_mem and mn != 'JP':
                nb.append('d')
            nb += b[1:]
            t.setdefault(nm, nb)
        # DDCB d op
        for op in range(256):
            x, y, z = op >> 6, (op >> 3) & 7, op & 7
            if z != 6: continue
            a = '(%s+d)' % ix
            if x == 0: m = '%s %s' % (ROT[y], a)
            else: m = '%s %d,%s' % (['','BIT','RES','SET'][x], y, a)
            t.setdefault(m, [pre, 0xCB, 'd', op])
    return t

TABLE = gen_table()
REGS = set('A B C D E H L I R AF BC DE HL SP IX IY IXH IXL IYH IYL NZ Z NC PO PE P M'.split()) | {"AF'"}
MEMREG = {'(C)', '(HL)', '(BC)', '(DE)', '(SP)', '(IX)', '(IY)'}

class AsmError(Exception):
    pass

# ---------------------------------------------------------------- expressions
num_re = re.compile(r"""
    (?P<hex1>0[xX][0-9A-Fa-f]+) |
    (?P<bin1>0[bB][01]+(?![0-9A-Fa-fhH])) |
    (?P<hex2>\$[0-9A-Fa-f]+) |
    (?P<hex3>[0-9][0-9A-Fa-f]*[hH](?![0-9A-Za-z_])) |
    (?P<bin2>%[01]+) |
    (?P<chr>'(\\.|[^'])') |
    (?P<dec>[0-9]+) |
    (?P<dollar>\$) |
    (?P<ident>[A-Za-z_.][A-Za-z0-9_.]*) |
    (?P<op><<|>>|<=|>=|==|!=|[-+*/%&|^~()<>]) |
    (?P<ws>\s+)
""", re.X)

class Expr:
    def __init__(self, asm):
        self.asm = asm

    def eval(self, s, strict):
        out = []
        pos = 0
        s = s.strip()
        while pos < len(s):
            m = num_re.match(s, pos)
            if not m:
                raise AsmError('bad expression: %s' % s)
            pos = m.end()
            k = m.lastgroup
            v = m.group(k)
            if k == 'ws': continue
            if k == 'hex1': out.append(str(int(v, 16)))
            elif k == 'hex2': out.append(str(int(v[1:], 16)))
            elif k == 'hex3': out.append(str(int(v[:-1], 16)))
            elif k == 'bin1': out.append(str(int(v[2:], 2)))
            elif k == 'bin2': out.append(str(int(v[1:], 2)))
            elif k == 'chr':
                c = v[1:-1]
                if c.startswith('\\'): c = {'n': '\n', 'r': '\r', '0': '\0'}.get(c[1], c[1])
                out.append(str(ord(c)))
            elif k == 'dec': out.append(v)
            elif k == 'dollar': out.append(str(self.asm.pc))
            elif k == 'ident':
                u = v.upper()
                if u in ('HIGH', 'LOW'):
                    out.append('_' + u)
                    continue
                name = self.asm.resolve_name(v)
                if name in self.asm.syms:
                    out.append(str(self.asm.syms[name]))
                elif strict:
                    raise AsmError('undefined symbol: %s' % v)
                else:
                    out.append('0')
                    self.asm.unresolved = True
            elif k == 'op':
                out.append('//' if v == '/' else v)
        expr = ' '.join(out)
        try:
            return int(eval(expr, {'__builtins__': {}},
                            {'_HIGH': lambda x: (x >> 8) & 255, '_LOW': lambda x: x & 255}))
        except ZeroDivisionError:
            if strict: raise AsmError('division by zero')
            return 0
        except Exception as e:
            raise AsmError('bad expression "%s": %s' % (s, e))

# ---------------------------------------------------------------- assembler
def split_operands(s):
    ops, cur, depth, q = [], '', 0, None
    for ch in s:
        if q:
            cur += ch
            if ch == q: q = None
            continue
        if ch in '"\'' and not (ch == "'" and cur.upper().endswith('AF')):
            q = ch; cur += ch; continue
        if ch == '(': depth += 1
        if ch == ')': depth -= 1
        if ch == ',' and depth == 0:
            ops.append(cur.strip()); cur = ''
        else:
            cur += ch
    if cur.strip(): ops.append(cur.strip())
    return ops

def strip_comment(line):
    q = None
    for i, ch in enumerate(line):
        if q:
            if ch == q: q = None
        elif ch in '"':
            q = ch
        elif ch == "'":
            # char literal like 'a' or AF'
            if line[max(0, i-2):i].upper() == 'AF':
                continue
            q = ch
        elif ch == ';':
            return line[:i]
    return line

class Assembler:
    def __init__(self):
        self.syms = {}
        self.pc = 0
        self.out = {}
        self.lastglobal = ''
        self.listing = []
        self.unresolved = False
        self.ex = Expr(self)

    def resolve_name(self, n):
        if n.startswith('.'):
            return self.lastglobal + n
        return n

    def define(self, name, val, pass_no):
        name = self.resolve_name(name)
        if pass_no == 1 and name in self.syms and self.syms[name] != val:
            raise AsmError('symbol redefined: %s' % name)
        self.syms[name] = val

    def emit(self, bytes_):
        for b in bytes_:
            self.out[self.pc] = b & 0xFF
            self.pc += 1

    def classify(self, op):
        u = op.upper().replace(' ', '')
        if u in REGS or u in MEMREG:
            return [(u, None)]
        m = re.match(r'^\((IX|IY)([+-].*)\)$', op.replace(' ', ''), re.I)
        if m:
            return [('(%s+d)' % m.group(1).upper(), m.group(2))]
        if u in ('(IX)', '(IY)'):
            return [(u, None), (u[:-1] + '+d)', '0')]
        if op.startswith('(') and op.endswith(')'):
            # check the parens enclose the whole thing
            depth = 0
            whole = True
            for i, ch in enumerate(op):
                if ch == '(': depth += 1
                elif ch == ')':
                    depth -= 1
                    if depth == 0 and i != len(op) - 1: whole = False
            if whole:
                return [('(nn)', op[1:-1]), ('(n)', op[1:-1])]
        return [('nn', op), ('n', op), ('e', op)]

    def assemble_instr(self, mn, ops, pass_no, strict):
        mnu = mn.upper()
        if mnu in ('IM', 'RST', 'BIT', 'SET', 'RES') and ops:
            v = self.ex.eval(ops[0], strict)
            ops = [str(v)] + ops[1:]
            first_literal = True
        else:
            first_literal = False
        cands = [[]]
        for i, op in enumerate(ops):
            if i == 0 and first_literal:
                forms = [(op, None)]
            else:
                forms = self.classify(op)
            cands = [c + [f] for c in cands for f in forms]
        for c in cands:
            key = mnu + (' ' + ','.join(f[0] for f in c) if c else '')
            if key in TABLE:
                tmpl = TABLE[key]
                exprs = [f[1] for f in c if f[1] is not None]
                return self.encode(tmpl, exprs, pass_no, strict, key)
        raise AsmError('unknown instruction: %s %s' % (mn, ','.join(ops)))

    def encode(self, tmpl, exprs, pass_no, strict, key):
        res = []
        ei = 0
        start = self.pc
        size = sum(2 if x == 'nn' else 1 for x in tmpl)
        for x in tmpl:
            if isinstance(x, int):
                res.append(x)
                continue
            v = self.ex.eval(exprs[ei], strict); ei += 1
            if x == 'nn':
                if strict and not (-32768 <= v <= 65535): raise AsmError('16-bit value out of range: %d' % v)
                res += [v & 255, (v >> 8) & 255]
            elif x == 'n':
                if strict and not (-128 <= v <= 255): raise AsmError('8-bit value out of range: %d' % v)
                res.append(v & 255)
            elif x == 'd':
                if strict and not (-128 <= v <= 127): raise AsmError('index offset out of range: %d' % v)
                res.append(v & 255)
            elif x == 'e':
                rel = v - (start + size)
                if strict and not (-128 <= rel <= 127): raise AsmError('relative jump out of range (%d)' % rel)
                res.append(rel & 255)
        return res

    def data_bytes(self, ops, strict):
        res = []
        for op in ops:
            if len(op) >= 2 and op[0] == '"' and op[-1] == '"':
                res += [ord(c) for c in op[1:-1]]
            elif len(op) >= 3 and op[0] == "'" and op[-1] == "'" and len(op) > 3:
                res += [ord(c) for c in op[1:-1]]
            else:
                res.append(self.ex.eval(op, strict) & 255)
        return res

    def run_file(self, fname, pass_no, strict):
        try:
            lines = open(fname).read().split('\n')
        except IOError as e:
            raise AsmError('cannot open %s' % fname)
        base = os.path.dirname(fname)
        for ln, raw in enumerate(lines, 1):
            try:
                if self.line(raw, pass_no, strict, base) == 'END':
                    break
            except AsmError as e:
                raise AsmError('%s:%d: %s\n    %s' % (fname, ln, e, raw.strip()))

    def line(self, raw, pass_no, strict, base):
        line = strip_comment(raw).rstrip()
        if not line.strip(): return
        label = None
        m = re.match(r'^([A-Za-z_.][A-Za-z0-9_.]*):?(\s+|$)', line)
        if m and (line[0] not in ' \t'):
            label = m.group(1)
            rest = line[m.end():]
            if label.upper() in TABLE_MNEMONICS and not line[len(label):].startswith(':'):
                # mnemonic in column 0
                label = None
                rest = line
        else:
            m2 = re.match(r'^\s*([A-Za-z_.][A-Za-z0-9_.]*):(.*)$', line)
            if m2:
                label, rest = m2.group(1), m2.group(2)
            else:
                rest = line
        rest = rest.strip()
        parts = rest.split(None, 1)
        mn = parts[0] if parts else ''
        args = parts[1] if len(parts) > 1 else ''
        mnu = mn.upper()
        if mnu in ('EQU', '=') or (mn.startswith('=')):
            if mn.startswith('=') and len(mn) > 1: args = mn[1:] + ' ' + args
            if not label: raise AsmError('EQU without label')
            self.define(label, self.ex.eval(args, strict), pass_no)
            return
        if label:
            if not label.startswith('.'):
                self.lastglobal = label
            self.define(label, self.pc, pass_no)
        if not mn: return
        start = self.pc
        ops = split_operands(args)
        if mnu == 'ORG':
            self.pc = self.ex.eval(args, True)
        elif mnu in ('DB', 'DEFB', 'DM', 'DEFM', 'BYTE'):
            self.emit(self.data_bytes(ops, strict))
        elif mnu in ('DW', 'DEFW', 'WORD'):
            for op in ops:
                v = self.ex.eval(op, strict)
                self.emit([v & 255, (v >> 8) & 255])
        elif mnu in ('DS', 'DEFS'):
            n = self.ex.eval(ops[0], True)
            fill = self.ex.eval(ops[1], strict) if len(ops) > 1 else 0
            self.emit([fill] * n)
        elif mnu == 'ALIGN':
            n = self.ex.eval(args, True)
            while self.pc % n: self.emit([0])
        elif mnu == 'INCLUDE':
            self.run_file(os.path.join(base, args.strip().strip('"')), pass_no, strict)
        elif mnu == 'INCBIN':
            data = open(os.path.join(base, args.strip().strip('"')), 'rb').read()
            self.emit(list(data))
        elif mnu == 'ASSERT':
            if strict and not self.ex.eval(args, True):
                raise AsmError('assertion failed: %s' % args)
        elif mnu == 'END':
            return 'END'
        else:
            self.emit(self.assemble_instr(mn, ops, pass_no, strict))
        if pass_no == 2:
            n = self.pc - start
            if mnu not in ('ORG', 'INCLUDE') and n > 0 and n <= 64:
                bs = ' '.join('%02X' % self.out[a] for a in range(start, start + min(n, 8)))
                self.listing.append('%04X  %-24s %s' % (start, bs, raw.rstrip()))
            else:
                self.listing.append('%4s  %-24s %s' % ('', '', raw.rstrip()))

    def assemble(self, fname):
        for p in (1, 2):
            self.pc = 0
            self.out = {}
            self.lastglobal = ''
            self.listing = []
            self.run_file(fname, p, p == 2)
        return self.out

TABLE_MNEMONICS = set(k.split(' ')[0] for k in TABLE) | {'ORG','EQU','DB','DW','DS','DEFB','DEFW','DEFS','INCLUDE','INCBIN','ALIGN','END','ASSERT','DM'}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('src')
    ap.add_argument('-o', '--out', required=True)
    ap.add_argument('-l', '--lst')
    ap.add_argument('-s', '--sym')
    ap.add_argument('--base', type=lambda x: int(x, 0), default=None,
                    help='first address written to the binary (default: lowest emitted)')
    a = ap.parse_args()
    asm = Assembler()
    try:
        out = asm.assemble(a.src)
    except AsmError as e:
        print('ERROR: %s' % e, file=sys.stderr)
        sys.exit(1)
    if not out:
        print('nothing assembled', file=sys.stderr); sys.exit(1)
    lo = a.base if a.base is not None else min(out)
    hi = max(out)
    data = bytearray(hi - lo + 1)
    for addr, b in out.items():
        if addr >= lo: data[addr - lo] = b
    open(a.out, 'wb').write(data)
    if a.lst: open(a.lst, 'w').write('\n'.join(asm.listing) + '\n')
    if a.sym:
        with open(a.sym, 'w') as f:
            for k, v in sorted(asm.syms.items(), key=lambda kv: kv[1]):
                f.write('%04X %s\n' % (v & 0xFFFF, k))
    print('%s: %d bytes, %04X-%04X' % (a.out, len(data), lo, hi))

if __name__ == '__main__':
    main()
