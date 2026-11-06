#!/usr/bin/env python3
"""Small Z80 disassembler (documented opcodes + common undocumented IX/IY halves).
usage: z80dis.py file.bin loadaddr_hex [start_hex end_hex]"""
import sys
R = ['b', 'c', 'd', 'e', 'h', 'l', '(hl)', 'a']
RP = ['bc', 'de', 'hl', 'sp']
RP2 = ['bc', 'de', 'hl', 'af']
CC = ['nz', 'z', 'nc', 'c', 'po', 'pe', 'p', 'm']
ALU = ['add a,', 'adc a,', 'sub ', 'sbc a,', 'and ', 'xor ', 'or ', 'cp ']
ROT = ['rlc', 'rrc', 'rl', 'rr', 'sla', 'sra', 'sll', 'srl']


def dis(mem, base, pc):
    """returns (length, text)"""
    def b(i):
        a = pc - base + i
        return mem[a] if 0 <= a < len(mem) else 0

    def w(i):
        return b(i) | b(i + 1) << 8

    def s8(v):
        return v - 256 if v > 127 else v
    op = b(0)
    pre = None
    off = 0
    if op in (0xDD, 0xFD):
        pre = 'ix' if op == 0xDD else 'iy'
        off = 1
        op = b(1)
        if op in (0xDD, 0xFD, 0xED):
            return 1, 'db $%02x' % b(0)
    if op == 0xCB:
        if pre:
            d = s8(b(2)); o = b(3)
            x, y, z = o >> 6, (o >> 3) & 7, o & 7
            m = '(%s%+d)' % (pre, d)
            if x == 0: t = '%s %s' % (ROT[y], m)
            elif x == 1: t = 'bit %d,%s' % (y, m)
            elif x == 2: t = 'res %d,%s' % (y, m)
            else: t = 'set %d,%s' % (y, m)
            return 4, t
        o = b(1)
        x, y, z = o >> 6, (o >> 3) & 7, o & 7
        if x == 0: t = '%s %s' % (ROT[y], R[z])
        elif x == 1: t = 'bit %d,%s' % (y, R[z])
        elif x == 2: t = 'res %d,%s' % (y, R[z])
        else: t = 'set %d,%s' % (y, R[z])
        return 2, t
    if op == 0xED and not pre:
        o = b(1)
        x, y, z, p, q = o >> 6, (o >> 3) & 7, o & 7, (o >> 4) & 3, (o >> 3) & 1
        if x == 1:
            if z == 0: return 2, 'in %s,(c)' % (R[y] if y != 6 else 'f')
            if z == 1: return 2, 'out (c),%s' % (R[y] if y != 6 else '0')
            if z == 2: return 2, ('sbc hl,%s' if q == 0 else 'adc hl,%s') % RP[p]
            if z == 3:
                return 4, ('ld ($%04x),%s' % (w(2), RP[p])) if q == 0 else ('ld %s,($%04x)' % (RP[p], w(2)))
            if z == 4: return 2, 'neg'
            if z == 5: return 2, 'retn' if y != 1 else 'reti'
            if z == 6: return 2, 'im %s' % ['0', '0', '1', '2'][y & 3]
            if z == 7: return 2, ['ld i,a', 'ld r,a', 'ld a,i', 'ld a,r', 'rrd', 'rld', 'nop', 'nop'][y]
        if x == 2 and z <= 3 and y >= 4:
            return 2, [['ldi', 'cpi', 'ini', 'outi'], ['ldd', 'cpd', 'ind', 'outd'],
                       ['ldir', 'cpir', 'inir', 'otir'], ['lddr', 'cpdr', 'indr', 'otdr']][y - 4][z]
        return 2, 'db $ed,$%02x' % o
    x, y, z, p, q = op >> 6, (op >> 3) & 7, op & 7, (op >> 4) & 3, (op >> 3) & 1
    n = 1 + off

    def reg(i, allow_hl=True):
        nonlocal n
        if pre:
            if i == 6:
                d = s8(b(n)); n += 1
                return '(%s%+d)' % (pre, d)
            if i == 4: return pre + 'h'
            if i == 5: return pre + 'l'
        return R[i]

    def rp(i, tab=RP):
        if pre and tab[i] == 'hl': return pre
        return tab[i]
    if x == 0:
        if z == 0:
            if y == 0: t = 'nop'
            elif y == 1: t = "ex af,af'"
            elif y == 2: t = 'djnz $%04x' % ((pc + 2 + s8(b(n))) & 0xffff); n += 1
            elif y == 3: t = 'jr $%04x' % ((pc + 2 + s8(b(n))) & 0xffff); n += 1
            else: t = 'jr %s,$%04x' % (CC[y - 4], (pc + 2 + s8(b(n))) & 0xffff); n += 1
        elif z == 1:
            if q == 0: t = 'ld %s,$%04x' % (rp(p), w(n)); n += 2
            else: t = 'add %s,%s' % (rp(2), rp(p))
        elif z == 2:
            if q == 0:
                if p == 0: t = 'ld (bc),a'
                elif p == 1: t = 'ld (de),a'
                elif p == 2: t = 'ld ($%04x),%s' % (w(n), rp(2)); n += 2
                else: t = 'ld ($%04x),a' % w(n); n += 2
            else:
                if p == 0: t = 'ld a,(bc)'
                elif p == 1: t = 'ld a,(de)'
                elif p == 2: t = 'ld %s,($%04x)' % (rp(2), w(n)); n += 2
                else: t = 'ld a,($%04x)' % w(n); n += 2
        elif z == 3: t = ('inc %s' if q == 0 else 'dec %s') % rp(p)
        elif z == 4: t = 'inc %s' % reg(y)
        elif z == 5: t = 'dec %s' % reg(y)
        elif z == 6:
            r = reg(y); t = 'ld %s,$%02x' % (r, b(n)); n += 1
        else: t = ['rlca', 'rrca', 'rla', 'rra', 'daa', 'cpl', 'scf', 'ccf'][y]
    elif x == 1:
        if op == 0x76: t = 'halt'
        else:
            if pre and (y == 6 or z == 6):
                # (ix+d) form: other operand is plain reg
                if y == 6: t = 'ld %s,%s' % (reg(6), R[z])
                else: t = 'ld %s,%s' % (R[y], reg(6))
            else:
                t = 'ld %s,%s' % (reg(y), reg(z))
    elif x == 2:
        t = ALU[y] + reg(z)
    else:
        if z == 0: t = 'ret %s' % CC[y]
        elif z == 1:
            if q == 0: t = 'pop %s' % rp(p, RP2)
            else: t = ['ret', 'exx', 'jp (%s)' % rp(2), 'ld sp,%s' % rp(2)][p]
        elif z == 2: t = 'jp %s,$%04x' % (CC[y], w(n)); n += 2
        elif z == 3:
            if y == 0: t = 'jp $%04x' % w(n); n += 2
            elif y == 2: t = 'out ($%02x),a' % b(n); n += 1
            elif y == 3: t = 'in a,($%02x)' % b(n); n += 1
            elif y == 4: t = 'ex (sp),%s' % rp(2)
            elif y == 5: t = 'ex de,hl'
            elif y == 6: t = 'di'
            elif y == 7: t = 'ei'
            else: t = '?'
        elif z == 4: t = 'call %s,$%04x' % (CC[y], w(n)); n += 2
        elif z == 5:
            if q == 0: t = 'push %s' % rp(p, RP2)
            elif p == 0: t = 'call $%04x' % w(n); n += 2
            else: t = '?'
        elif z == 6: t = ALU[y] + '$%02x' % b(n); n += 1
        else: t = 'rst $%02x' % (y * 8)
    return n, t


if __name__ == '__main__':
    mem = open(sys.argv[1], 'rb').read()
    base = int(sys.argv[2], 16)
    st = int(sys.argv[3], 16) if len(sys.argv) > 3 else base
    en = int(sys.argv[4], 16) if len(sys.argv) > 4 else base + len(mem)
    pc = st
    while pc < en:
        n, t = dis(mem, base, pc)
        bs = ' '.join('%02x' % mem[pc - base + i] for i in range(n) if pc - base + i < len(mem))
        print('%04x  %-12s %s' % (pc, bs, t))
        pc += n
