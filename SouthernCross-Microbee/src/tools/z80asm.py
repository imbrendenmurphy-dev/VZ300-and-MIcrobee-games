#!/usr/bin/env python3
"""Small two-pass Z80 assembler (no IX/IY). Usage: z80asm.py src.asm out.bin [listing]"""
import sys, re

R8 = {'b':0,'c':1,'d':2,'e':3,'h':4,'l':5,'(hl)':6,'a':7}
RP = {'bc':0,'de':1,'hl':2,'sp':3}
QQ = {'bc':0,'de':1,'hl':2,'af':3}
CC = {'nz':0,'z':1,'nc':2,'c':3,'po':4,'pe':5,'p':6,'m':7}
ALU = {'add':0,'adc':1,'sub':2,'sbc':3,'and':4,'xor':5,'or':6,'cp':7}
CBOP = {'rlc':0,'rrc':1,'rl':2,'rr':3,'sla':4,'sra':5,'sll':6,'srl':7}
SIMPLE = {'nop':[0],'rlca':[7],'rrca':[0x0f],'rla':[0x17],'rra':[0x1f],'cpl':[0x2f],
          'scf':[0x37],'ccf':[0x3f],'halt':[0x76],'di':[0xf3],'ei':[0xfb],'exx':[0xd9],
          'neg':[0xed,0x44],'ldir':[0xed,0xb0],'lddr':[0xed,0xb8],'ldi':[0xed,0xa0],
          'ldd':[0xed,0xa8],'ret':[0xc9],'reti':[0xed,0x4d],'daa':[0x27]}

class AsmError(Exception): pass

def split_ops(s):
    out, cur, q, depth = [], '', None, 0
    for ch in s:
        if q:
            cur += ch
            if ch == q: q = None
        elif ch in '"\'':
            q = ch; cur += ch
        elif ch == '(':
            depth += 1; cur += ch
        elif ch == ')':
            depth -= 1; cur += ch
        elif ch == ',' and depth == 0:
            out.append(cur.strip()); cur = ''
        else:
            cur += ch
    if cur.strip(): out.append(cur.strip())
    return out

class Asm:
    def __init__(self):
        self.sym = {}
        self.pass_no = 1

    def ev(self, e):
        e0 = e
        def num(m):
            t = m.group(0)
            if re.fullmatch(r'[0-9][0-9a-f]*h', t): return str(int(t[:-1],16))
            if re.fullmatch(r'[01]+b', t): return str(int(t[:-1],2))
            return t
        e = re.sub(r"'(.)'", lambda m: str(ord(m.group(1))), e)
        e = e.lower()
        e = re.sub(r'\b[0-9][0-9a-fx]*h?\b|\b[01]+b\b', num, e)
        e = e.replace('$', '_pc_')
        e = e.replace('/', '//')
        env = dict(self.sym); env['_pc_'] = self.pc
        env['low'] = lambda v: v & 0xff
        env['high'] = lambda v: (v >> 8) & 0xff
        try:
            return int(eval(e, {'__builtins__': {}}, env))
        except NameError:
            if self.pass_no == 1: return 0
            raise AsmError('undefined symbol in: ' + e0)
        except Exception as ex:
            raise AsmError('bad expression %r: %s' % (e0, ex))

    def b(self, v):
        return v & 0xff

    def w(self, v):
        v &= 0xffff
        return [v & 0xff, v >> 8]

    def rel(self, target):
        d = target - (self.pc + 2)
        if self.pass_no == 2 and not -128 <= d <= 127:
            raise AsmError('relative jump out of range (%d)' % d)
        return d & 0xff

    def is_ind(self, o):
        return o.startswith('(') and o.endswith(')') and o.lower() not in ('(hl)','(bc)','(de)','(sp)','(c)')

    def encode(self, mn, ops):
        lo = [o.lower() for o in ops]
        n = len(ops)
        if mn in SIMPLE and n == 0: return SIMPLE[mn]
        if mn == 'ld':
            d, s = lo
            if d in R8 and s in R8:
                if d == '(hl)' and s == '(hl)': raise AsmError('ld (hl),(hl)')
                return [0x40 | R8[d] << 3 | R8[s]]
            if d == 'a' and s == '(bc)': return [0x0a]
            if d == 'a' and s == '(de)': return [0x1a]
            if d == '(bc)' and s == 'a': return [0x02]
            if d == '(de)' and s == 'a': return [0x12]
            if d == 'sp' and s == 'hl': return [0xf9]
            if d == 'a' and self.is_ind(s): return [0x3a] + self.w(self.ev(ops[1][1:-1]))
            if self.is_ind(d) and s == 'a': return [0x32] + self.w(self.ev(ops[0][1:-1]))
            if d == 'hl' and self.is_ind(s): return [0x2a] + self.w(self.ev(ops[1][1:-1]))
            if self.is_ind(d) and s == 'hl': return [0x22] + self.w(self.ev(ops[0][1:-1]))
            if d in RP and self.is_ind(s): return [0xed, 0x4b | RP[d] << 4] + self.w(self.ev(ops[1][1:-1]))
            if self.is_ind(d) and s in RP: return [0xed, 0x43 | RP[s] << 4] + self.w(self.ev(ops[0][1:-1]))
            if d in RP: return [0x01 | RP[d] << 4] + self.w(self.ev(ops[1]))
            if d in R8: return [0x06 | R8[d] << 3, self.b(self.ev(ops[1]))]
            raise AsmError('bad ld')
        if mn in ('push', 'pop'):
            return [(0xc5 if mn == 'push' else 0xc1) | QQ[lo[0]] << 4]
        if mn == 'ex':
            if lo == ['de','hl']: return [0xeb]
            if lo[0] == 'af': return [0x08]
            if lo == ['(sp)','hl']: return [0xe3]
            raise AsmError('bad ex')
        if mn in ALU:
            if n == 2 and lo[0] == 'hl':
                r = RP[lo[1]]
                if mn == 'add': return [0x09 | r << 4]
                if mn == 'adc': return [0xed, 0x4a | r << 4]
                if mn == 'sbc': return [0xed, 0x42 | r << 4]
                raise AsmError('bad 16-bit alu')
            if n == 2:
                if lo[0] != 'a': raise AsmError('alu dest must be a')
                src = ops[1]; sl = lo[1]
            else:
                src = ops[0]; sl = lo[0]
            if sl in R8: return [0x80 | ALU[mn] << 3 | R8[sl]]
            return [0xc6 | ALU[mn] << 3, self.b(self.ev(src))]
        if mn in ('inc', 'dec'):
            o = lo[0]
            if o in R8: return [(0x04 if mn == 'inc' else 0x05) | R8[o] << 3]
            if o in RP: return [(0x03 if mn == 'inc' else 0x0b) | RP[o] << 4]
            raise AsmError('bad inc/dec')
        if mn in CBOP:
            return [0xcb, CBOP[mn] << 3 | R8[lo[0]]]
        if mn in ('bit', 'res', 'set'):
            bit = self.ev(ops[0]) & 7
            base = {'bit':0x40,'res':0x80,'set':0xc0}[mn]
            return [0xcb, base | bit << 3 | R8[lo[1]]]
        if mn == 'jp':
            if n == 1:
                if lo[0] == '(hl)': return [0xe9]
                return [0xc3] + self.w(self.ev(ops[0]))
            return [0xc2 | CC[lo[0]] << 3] + self.w(self.ev(ops[1]))
        if mn == 'jr':
            if n == 1: return [0x18, self.rel(self.ev(ops[0]))]
            c = {'nz':0x20,'z':0x28,'nc':0x30,'c':0x38}[lo[0]]
            return [c, self.rel(self.ev(ops[1]))]
        if mn == 'djnz': return [0x10, self.rel(self.ev(ops[0]))]
        if mn == 'call':
            if n == 1: return [0xcd] + self.w(self.ev(ops[0]))
            return [0xc4 | CC[lo[0]] << 3] + self.w(self.ev(ops[1]))
        if mn == 'ret' and n == 1: return [0xc0 | CC[lo[0]] << 3]
        if mn == 'rst': return [0xc7 | (self.ev(ops[0]) & 0x38)]
        if mn == 'out':
            if lo[0] == '(c)': return [0xed, 0x41 | R8[lo[1]] << 3]
            return [0xd3, self.b(self.ev(ops[0][1:-1]))]
        if mn == 'in':
            if lo[1] == '(c)': return [0xed, 0x40 | R8[lo[0]] << 3]
            return [0xdb, self.b(self.ev(ops[1][1:-1]))]
        if mn == 'im': return [0xed, [0x46, 0x56, 0x5e][self.ev(ops[0])]]
        raise AsmError('unknown instruction %s %s' % (mn, ops))

    def run(self, lines):
        for p in (1, 2):
            self.pass_no = p
            self.pc = 0x100
            out = bytearray()
            origin = None
            listing = []
            for lineno, raw in enumerate(lines, 1):
                line = raw
                # strip comment (not inside quotes)
                q = None; cut = len(line)
                for i, ch in enumerate(line):
                    if q:
                        if ch == q: q = None
                    elif ch in '"\'':
                        # treat 'x' char literal and strings
                        q = ch
                    elif ch == ';':
                        cut = i; break
                line = line[:cut].rstrip()
                if not line.strip(): continue
                try:
                    m = re.match(r'^([A-Za-z_.][\w.]*):?\s*(.*)$', line) if not line[0].isspace() else None
                    label = None
                    rest = line.strip()
                    if m:
                        label = m.group(1).lower(); rest = m.group(2).strip()
                    parts = rest.split(None, 1)
                    mn = parts[0].lower() if parts else ''
                    arg = parts[1] if len(parts) > 1 else ''
                    if mn == 'equ':
                        self.sym[label] = self.ev(arg); continue
                    if label:
                        if p == 1 and label in self.sym: raise AsmError('duplicate label ' + label)
                        self.sym[label] = self.pc
                    if not mn: continue
                    start = self.pc
                    if mn == 'org':
                        self.pc = self.ev(arg)
                        if origin is None: origin = self.pc
                        continue
                    if origin is None: origin = self.pc
                    if mn in ('db', 'defb', 'defm'):
                        data = []
                        for o in split_ops(arg):
                            if len(o) >= 2 and o[0] == '"' and o[-1] == '"':
                                data += [ord(c) for c in o[1:-1]]
                            else:
                                data.append(self.b(self.ev(o)))
                    elif mn in ('dw', 'defw'):
                        data = []
                        for o in split_ops(arg): data += self.w(self.ev(o))
                    elif mn in ('ds', 'defs'):
                        a = split_ops(arg)
                        cnt = self.ev(a[0]); fill = self.ev(a[1]) if len(a) > 1 else 0
                        data = [fill & 0xff] * cnt
                    elif mn == 'align':
                        al = self.ev(arg)
                        data = [0] * ((-self.pc) % al)
                    else:
                        data = self.encode(mn, split_ops(arg))
                    off = self.pc - origin
                    if off < len(out):
                        raise AsmError('overlapping output')
                    out += bytes(off - len(out))
                    out += bytes(data)
                    if p == 2: listing.append('%04X  %-12s %s' % (start, ' '.join('%02X' % x for x in data[:4]), raw.rstrip()))
                    self.pc += len(data)
                except AsmError as e:
                    raise AsmError('line %d: %s\n  %s' % (lineno, e, raw.rstrip()))
        return out, listing

if __name__ == '__main__':
    src = open(sys.argv[1]).read().splitlines()
    a = Asm()
    try:
        out, lst = a.run(src)
    except AsmError as e:
        print('ERROR', e); sys.exit(1)
    open(sys.argv[2], 'wb').write(out)
    if len(sys.argv) > 3:
        with open(sys.argv[3], 'w') as f:
            f.write('\n'.join(lst) + '\n\nSYMBOLS\n')
            for k in sorted(a.sym): f.write('%-20s %04X\n' % (k, a.sym[k] & 0xffff))
    print('assembled %d bytes, end %04X' % (len(out), a.pc))
